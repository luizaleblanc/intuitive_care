"""Geração robusta de planilhas (XLSX com openpyxl), CSV e relatórios estruturados a partir das bases ETL da ANS.

Bases consultadas diretamente no banco:
- demonstracoes_operadora (contraprestações, eventos, eventos_mh, comercialização, administrativas)
- beneficiarios_trimestre (médico-hospitalar e odontológico por trimestre)
- operadoras (CADOP ativas e canceladas, CNPJ, cidade, UF, modalidade, representante)
- contas_setor (plano de contas ANS consolidado do setor)
- lotes_etl (rastreabilidade e status de auditoria dos lotes extraídos)
- despesas (lançamentos assistenciais consolidados)
"""
from collections import defaultdict
from copy import copy
from datetime import date, datetime
from io import BytesIO, StringIO
import re
from typing import Any, Dict, List, Optional, Sequence, Tuple
import xml.etree.ElementTree as ET
import zipfile

from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

from backend.repositories.relatorio_repository import RelatorioRepository
from backend.services.analitico_service import GRUPOS_CONTAS
from backend.services.explorar_service import CONSOLIDACOES, FAIXAS_DESPESA, GRANULARIDADES, PORTES, STATUS
from backend.services.validators import BusinessRuleError, VALID_UFS

SECOES_VALIDAS = (
    "resumo",
    "evolucao",
    "modalidades",
    "ufs",
    "operadoras",
    "contas_setor",
    "base_demonstracoes",
    "lotes_cadastro",
)
SECOES_PADRAO = SECOES_VALIDAS
ORDENS_VALIDAS = ("despesas", "receitas", "sinistralidade", "beneficiarios", "resultado", "administrativas")
FORMATOS_VALIDOS = ("XLSX", "CSV", "JSON")

# Formatos numéricos nativos do Excel
FMT_MOEDA = 'R$ #,##0.00;-"R$ "#,##0.00;"-"'
FMT_PCT = "0.00%"
FMT_INT = "#,##0"

# Paleta institucional Intuitive Care
_COR_FOREST = "113E32"
_COR_MINT = "4AD295"
_COR_SAGE = "DCE7E2"
_COR_ZEBRA = "F3F7F5"
_COR_BORDA = "D3DFD9"
_COR_TEXTO = "0F172A"
_COR_MUTED = "475569"
_COR_OK_BG = "ECFDF5"
_COR_OK_FG = "047857"
_COR_ERR_BG = "FEF2F2"
_COR_ERR_FG = "B91C1C"

# Remove caracteres de controle ilegais no XML 1.0 (mesma regra do openpyxl)
_XML_ILLEGAL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_DIM_RE = re.compile(rb'<dimension ref="[^"]*"')
_NS_MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
_NS_REL_ATTR = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
_NS_PKG_REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"

# Limite acima do qual injetamos as linhas em OOXML direto (20x+ mais rápido que ElementTree/et_xmlfile)
_STREAM_THRESHOLD = 200


def _Estilos() -> Dict[str, Any]:
    thin = Side(style="thin", color=_COR_BORDA)
    med_forest = Side(style="medium", color=_COR_FOREST)
    double_forest = Side(style="double", color=_COR_FOREST)
    return {
        "banner_fill": PatternFill("solid", fgColor=_COR_FOREST),
        "sub_fill": PatternFill("solid", fgColor=_COR_SAGE),
        "head_fill": PatternFill("solid", fgColor=_COR_FOREST),
        "zebra_fill": PatternFill("solid", fgColor=_COR_ZEBRA),
        "total_fill": PatternFill("solid", fgColor=_COR_SAGE),
        "ok_fill": PatternFill("solid", fgColor=_COR_OK_BG),
        "err_fill": PatternFill("solid", fgColor=_COR_ERR_BG),
        "banner_font": Font(name="Calibri", size=14, bold=True, color="FFFFFF"),
        "sub_font": Font(name="Calibri", size=10, italic=True, color=_COR_FOREST),
        "sec_font": Font(name="Calibri", size=11, bold=True, color=_COR_FOREST),
        "head_font": Font(name="Calibri", size=10, bold=True, color="FFFFFF"),
        "data_font": Font(name="Calibri", size=10, color=_COR_TEXTO),
        "data_bold": Font(name="Calibri", size=10, bold=True, color=_COR_TEXTO),
        "muted_font": Font(name="Calibri", size=9, color=_COR_MUTED),
        "total_font": Font(name="Calibri", size=10, bold=True, color=_COR_FOREST),
        "ok_font": Font(name="Calibri", size=10, bold=True, color=_COR_OK_FG),
        "err_font": Font(name="Calibri", size=10, bold=True, color=_COR_ERR_FG),
        "border": Border(left=thin, right=thin, top=thin, bottom=thin),
        "total_border": Border(left=thin, right=thin, top=med_forest, bottom=double_forest),
        "align_l": Alignment(horizontal="left", vertical="center"),
        "align_c": Alignment(horizontal="center", vertical="center"),
        "align_r": Alignment(horizontal="right", vertical="center"),
        "align_head_l": Alignment(horizontal="left", vertical="center", wrap_text=True),
        "align_head_c": Alignment(horizontal="center", vertical="center", wrap_text=True),
        "align_head_r": Alignment(horizontal="right", vertical="center", wrap_text=True),
    }


class _StyleRegistry:
    """Registra combinações de estilos uma única vez no workbook e retorna o índice `s` de `xl/styles.xml`."""

    def __init__(self, wb: Workbook):
        self._wb = wb
        self._ws = wb.create_sheet("__styles_tmp__")
        self._col = 0
        self._cache: Dict[Tuple[Any, ...], int] = {}

    def get(
        self,
        *,
        font: Optional[Font] = None,
        fill: Optional[PatternFill] = None,
        border: Optional[Border] = None,
        alignment: Optional[Alignment] = None,
        number_format: Optional[str] = None,
    ) -> int:
        chave = (id(font), id(fill), id(border), id(alignment), number_format)
        existente = self._cache.get(chave)
        if existente is not None:
            return existente
        self._col += 1
        cell = self._ws.cell(row=1, column=self._col, value=0)
        if font is not None:
            cell.font = font
        if fill is not None:
            cell.fill = fill
        if border is not None:
            cell.border = border
        if alignment is not None:
            cell.alignment = alignment
        if number_format is not None:
            cell.number_format = number_format
        idx = self._wb._cell_styles.add(copy(cell._style))
        self._cache[chave] = idx
        return idx

    def cleanup(self) -> None:
        if self._ws.title in self._wb.sheetnames:
            self._wb.remove(self._ws)


def _xml_str(valor: Any) -> str:
    s = "" if valor is None else str(valor)
    if not s:
        return ""
    if any(ch in s for ch in ("&", "<", ">")):
        s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    if _XML_ILLEGAL_RE.search(s):
        s = _XML_ILLEGAL_RE.sub("", s)
    return s


def _cell_str_xml(ref: str, s_idx: int, valor: Any) -> str:
    txt = _xml_str(valor)
    if not txt:
        return f'<c r="{ref}" s="{s_idx}"/>'
    if txt[0] == " " or txt[-1] == " ":
        return f'<c r="{ref}" t="inlineStr" s="{s_idx}"><is><t xml:space="preserve">{txt}</t></is></c>'
    return f'<c r="{ref}" t="inlineStr" s="{s_idx}"><is><t>{txt}</t></is></c>'


def _cell_num_xml(ref: str, s_idx: int, valor: Any) -> str:
    if valor is None:
        return f'<c r="{ref}" s="{s_idx}"/>'
    return f'<c r="{ref}" s="{s_idx}"><v>{valor}</v></c>'


def _cell_formula_xml(ref: str, s_idx: int, formula: str, cached: Any = None) -> str:
    f_esc = _xml_str(formula[1:] if formula.startswith("=") else formula)
    if cached is None:
        return f'<c r="{ref}" s="{s_idx}"><f>{f_esc}</f></c>'
    return f'<c r="{ref}" s="{s_idx}"><f>{f_esc}</f><v>{cached}</v></c>'


def _fmt_cnpj(valor: Any) -> str:
    s = str(valor or "")
    if len(s) == 14 and s.isdigit():
        return f"{s[:2]}.{s[2:5]}.{s[5:8]}/{s[8:12]}-{s[12:]}"
    d = "".join(c for c in s if c.isdigit())
    if len(d) != 14:
        return s
    return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"


def _fmt_periodo(ano: int, tri: Optional[int]) -> str:
    return f"{ano}" if not tri else f"{tri}º trimestre de {ano}"


def _fmt_data(valor: Any, formato: str = "DD/MM/AAAA", hora: bool = False) -> str:
    if not valor:
        return ""
    dt: Optional[datetime] = None
    if isinstance(valor, datetime):
        dt = valor
    elif isinstance(valor, date):
        dt = datetime(valor.year, valor.month, valor.day)
    else:
        bruto = str(valor).strip().replace("Z", "")
        for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
            try:
                dt = datetime.strptime(bruto[:19] if len(fmt) > 10 else bruto[:10], fmt)
                break
            except ValueError:
                continue
    if dt is None:
        return str(valor)
    base = dt.strftime("%Y-%m-%d") if formato == "AAAA-MM-DD" else dt.strftime("%d/%m/%Y")
    return f"{base} {dt.strftime('%H:%M')}" if hora else base


def _classificar_porte(benef: int) -> str:
    if benef >= 100_000:
        return "Grande porte"
    if benef >= 20_000:
        return "Médio porte"
    return "Pequeno porte"


def _na_faixa(valor: float, faixa: Tuple[float, Optional[float]]) -> bool:
    minimo, maximo = faixa
    return valor >= minimo and (maximo is None or valor < maximo)


def _norm_lista_str(valor: Any) -> List[str]:
    if not valor:
        return []
    if isinstance(valor, str):
        return [v.strip() for v in valor.split(",") if v.strip()]
    if isinstance(valor, (list, tuple, set)):
        return [str(v).strip() for v in valor if str(v).strip()]
    return []


def _norm_lista_int(valor: Any, nome: str) -> List[int]:
    itens = _norm_lista_str(valor)
    try:
        return sorted({int(x) for x in itens})
    except ValueError:
        raise BusinessRuleError(f"Parâmetro '{nome}' deve conter apenas números inteiros.", 400)


def _grupo_conta(codigo: str) -> str:
    for pref, nome in GRUPOS_CONTAS.items():
        if codigo.startswith(pref):
            return f"{pref} · {nome}"
    return "Outras contas"


def _rotulo_anos(anos: Sequence[int]) -> str:
    if not anos:
        return ""
    if len(anos) == 1:
        return str(anos[0])
    if len(anos) == anos[-1] - anos[0] + 1:
        return f"{anos[0]}–{anos[-1]}"
    return ", ".join(str(a) for a in anos)


def _rotulo_trimestres(tris: Sequence[int]) -> str:
    if not tris or len(tris) == 4:
        return "Todos os trimestres"
    return ", ".join(f"{t}º trimestre" for t in tris)


def _mapear_paths_abas(zin: zipfile.ZipFile) -> Dict[str, str]:
    """Mapeia `nome_da_aba -> caminho no zip` (ex.: `xl/worksheets/sheet7.xml`) lendo workbook.xml + rels."""
    wb_root = ET.fromstring(zin.read("xl/workbook.xml"))
    rels_root = ET.fromstring(zin.read("xl/_rels/workbook.xml.rels"))
    rid_to_target: Dict[str, str] = {}
    for rel in rels_root.findall(f"{_NS_PKG_REL}Relationship"):
        rid = rel.attrib.get("Id")
        target = rel.attrib.get("Target", "")
        if rid and target:
            target_norm = target.lstrip("/")
            if not target_norm.startswith("xl/"):
                target_norm = f"xl/{target_norm}"
            rid_to_target[rid] = target_norm

    mapa: Dict[str, str] = {}
    for sheet in wb_root.findall(f".//{_NS_MAIN}sheet"):
        nome = sheet.attrib.get("name")
        rid = sheet.attrib.get(_NS_REL_ATTR)
        if nome and rid in rid_to_target:
            mapa[nome] = rid_to_target[rid]
    return mapa


class RelatorioService:
    """Orquestra consultas ETL e exportação em XLSX (openpyxl), CSV ou JSON estruturado."""

    @classmethod
    def _parse_params(cls, payload: Dict[str, Any]) -> Dict[str, Any]:
        anos_disp = RelatorioRepository.anos_disponiveis()
        if not anos_disp:
            raise BusinessRuleError("Ainda não há demonstrações carregadas. Execute o ETL.", 404)

        anos = _norm_lista_int(payload.get("anos"), "anos")
        if not anos:
            anos = [anos_disp[-1]]
        elif any(a not in anos_disp for a in anos):
            raise BusinessRuleError("Há ano selecionado sem dados carregados no ETL.", 400)

        trimestres = _norm_lista_int(payload.get("trimestres"), "trimestres")
        if any(t not in (1, 2, 3, 4) for t in trimestres):
            raise BusinessRuleError("Trimestre inválido. Use valores entre 1 e 4.", 400)

        granularidade = (payload.get("granularidade") or "ano").strip().lower()
        if granularidade not in GRANULARIDADES:
            raise BusinessRuleError("Granularidade inválida. Use 'ano' ou 'trimestre'.", 400)

        ufs = [u.upper() for u in _norm_lista_str(payload.get("ufs") or payload.get("uf"))]
        if any(u not in VALID_UFS for u in ufs):
            raise BusinessRuleError("UF inválida no filtro do relatório.", 400)

        modalidades = _norm_lista_str(payload.get("modalidades") or payload.get("modalidade"))
        statuses = _norm_lista_str(payload.get("statuses") or payload.get("status"))
        portes = _norm_lista_str(payload.get("portes") or payload.get("porte"))
        faixas = _norm_lista_str(payload.get("faixas") or payload.get("faixa_despesa"))
        consolidacoes = _norm_lista_str(payload.get("consolidacoes") or payload.get("consolidacao"))

        for valores, validos, nome in (
            (statuses, STATUS[1:], "status"),
            (portes, PORTES, "porte"),
            (faixas, FAIXAS_DESPESA, "faixa_despesa"),
            (consolidacoes, CONSOLIDACOES[1:], "consolidacao"),
        ):
            if any(v not in validos for v in valores):
                raise BusinessRuleError(f"Valor inválido para '{nome}'.", 400)
        consolidacao = consolidacoes[0] if len(consolidacoes) == 1 else ""

        secoes = _norm_lista_str(payload.get("secoes")) or list(SECOES_PADRAO)
        if any(s not in SECOES_VALIDAS for s in secoes):
            raise BusinessRuleError("Seção de relatório inválida.", 400)
        # Mantém ordem canônica das abas
        secoes = [s for s in SECOES_VALIDAS if s in secoes]

        ordenar_por = (payload.get("ordenar_por") or "despesas").strip().lower()
        if ordenar_por not in ORDENS_VALIDAS:
            raise BusinessRuleError("Critério de ordenação inválido.", 400)

        limite_raw = payload.get("limite_operadoras")
        limite: Optional[int] = None
        if limite_raw not in (None, "", 0, "0"):
            try:
                limite = int(limite_raw)
                if limite <= 0:
                    limite = None
            except (TypeError, ValueError):
                raise BusinessRuleError("Parâmetro 'limite_operadoras' inválido.", 400)

        formato = (payload.get("formato") or "XLSX").strip().upper()
        if formato not in FORMATOS_VALIDOS:
            raise BusinessRuleError("Formato inválido. Use XLSX, CSV ou JSON.", 400)

        formato_data = (payload.get("formato_data") or "DD/MM/AAAA").strip()
        if formato_data not in ("DD/MM/AAAA", "AAAA-MM-DD"):
            formato_data = "DD/MM/AAAA"

        return {
            "anos": anos,
            "trimestres": trimestres,
            "granularidade": granularidade,
            "ufs": ufs,
            "modalidades": modalidades,
            "statuses": statuses,
            "portes": portes,
            "faixas": faixas,
            "consolidacao": consolidacao,
            "secoes": secoes,
            "ordenar_por": ordenar_por,
            "limite_operadoras": limite,
            "formato": formato,
            "formato_data": formato_data,
        }

    @classmethod
    def coletar_dados(
        cls, payload: Dict[str, Any], usuario_nome: str = "", *, _tuplas_fato: bool = False
    ) -> Dict[str, Any]:
        cfg = cls._parse_params(payload)
        pacote = RelatorioRepository.carregar_pacote_etl(
            anos=cfg["anos"],
            trimestres=cfg["trimestres"],
            ufs=cfg["ufs"],
            modalidades=cfg["modalidades"],
            statuses=cfg["statuses"],
            incluir_contas="contas_setor" in cfg["secoes"],
        )
        cadastro_completo = pacote["operadoras"]
        lotes = pacote["lotes_etl"]
        benef_mapa = pacote["beneficiarios_mapa"]
        auditado_mapa = {(int(l["ano"]), int(l["trimestre"])): bool(l.get("auditado")) for l in lotes}

        # Mapa O(1) de operadoras elegíveis (já aplicando filtro de porte ANS, se informado)
        ops_map: Dict[str, Dict[str, Any]] = {}
        limites_porte = [PORTES[p] for p in cfg["portes"]] if cfg["portes"] else []
        for op_cad in cadastro_completo:
            benef_cadop = int(op_cad.get("beneficiarios") or 0)
            if limites_porte and not (benef_cadop and any(_na_faixa(float(benef_cadop), lim) for lim in limites_porte)):
                continue
            ops_map[op_cad["registro_ans"]] = op_cad

        cons = cfg["consolidacao"]
        # Tuplas fato: (ano, tri, reg_ans, rec, ev, ev_mh, com, adm, bmh, bod, auditado)
        fatos: List[Tuple[int, int, str, float, float, float, float, float, int, int, bool]] = []
        fatos_append = fatos.append
        for raw in pacote["demonstracoes_brutas"]:
            reg = raw[2]
            if reg not in ops_map:
                continue
            ano = int(raw[0])
            tri = int(raw[1])
            aud = auditado_mapa.get((ano, tri), False)
            if cons == "consolidado" and not aud:
                continue
            if cons == "pendente" and aud:
                continue
            bmh, bod = benef_mapa.get((reg, ano, tri), (0, 0))
            fatos_append((
                ano, tri, reg,
                float(raw[3] or 0), float(raw[4] or 0), float(raw[5] or 0),
                float(raw[6] or 0), float(raw[7] or 0),
                bmh, bod, aud,
            ))

        # Ordenação estável por período decrescente e maior despesa
        fatos.sort(key=lambda t: (t[0], t[1], t[4]), reverse=True)

        # Consolidação por operadora
        por_op: Dict[str, Dict[str, Any]] = {}
        for ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, _aud in fatos:
            op = por_op.get(reg)
            if op is None:
                cad_o = ops_map[reg]
                op = {
                    "registro_ans": reg,
                    "cnpj": _fmt_cnpj(cad_o["cnpj"]),
                    "razao_social": cad_o["razao_social"] or "",
                    "nome_fantasia": cad_o["nome_fantasia"] or cad_o["razao_social"] or "",
                    "modalidade": cad_o["modalidade"] or "Não informada",
                    "uf": cad_o["uf"] or "",
                    "cidade": cad_o["cidade"] or "",
                    "status": cad_o["status"] or "",
                    "porte": _classificar_porte(int(cad_o.get("beneficiarios") or 0)),
                    "trimestres": 0,
                    "receitas": 0.0,
                    "despesas": 0.0,
                    "eventos_mh": 0.0,
                    "comercializacao": 0.0,
                    "administrativas": 0.0,
                    "benef_mh": 0,
                    "benef_odonto": 0,
                    "_ultimo": (0, 0),
                }
                por_op[reg] = op
            op["trimestres"] += 1
            op["receitas"] += rec
            op["despesas"] += ev
            op["eventos_mh"] += ev_mh
            op["comercializacao"] += com
            op["administrativas"] += adm
            chave = (ano, tri)
            if chave >= op["_ultimo"]:
                op["_ultimo"] = chave
                op["benef_mh"] = bmh
                op["benef_odonto"] = bod

        if cfg["faixas"]:
            limites_faixa = [FAIXAS_DESPESA[f] for f in cfg["faixas"]]
            por_op = {
                k: v for k, v in por_op.items()
                if any(_na_faixa(v["despesas"], lim) for lim in limites_faixa)
            }
            fatos = [t for t in fatos if t[2] in por_op]

        for op in por_op.values():
            op.pop("_ultimo", None)
            op["resultado"] = op["receitas"] - op["despesas"] - op["comercializacao"] - op["administrativas"]
            op["sinistralidade"] = (op["despesas"] / op["receitas"]) if op["receitas"] > 0 else None
            op["indice_combinado"] = (
                (op["despesas"] + op["comercializacao"] + op["administrativas"]) / op["receitas"]
                if op["receitas"] > 0
                else None
            )
            op["beneficiarios"] = op["benef_mh"] + op["benef_odonto"]
            op["ticket_medio"] = (op["eventos_mh"] / op["benef_mh"]) if op["benef_mh"] > 0 else None

        # Série temporal (por ano ou por trimestre)
        gran = cfg["granularidade"]
        buckets: Dict[Tuple[int, int], Dict[str, Any]] = defaultdict(
            lambda: {
                "ops": set(),
                "receitas": 0.0,
                "despesas": 0.0,
                "eventos_mh": 0.0,
                "comercializacao": 0.0,
                "administrativas": 0.0,
            }
        )
        benef_tri: Dict[Tuple[int, int], List[int]] = defaultdict(lambda: [0, 0])
        for ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, _aud in fatos:
            chave = (ano, 0) if gran == "ano" else (ano, tri)
            b = buckets[chave]
            b["ops"].add(reg)
            b["receitas"] += rec
            b["despesas"] += ev
            b["eventos_mh"] += ev_mh
            b["comercializacao"] += com
            b["administrativas"] += adm
            bt = benef_tri[(ano, tri)]
            bt[0] += bmh
            bt[1] += bod

        def _benef_bucket(ano: int, tri: int) -> Tuple[int, int]:
            if tri:
                v = benef_tri.get((ano, tri), [0, 0])
                return v[0], v[1]
            tris_ano = [t for (a, t) in benef_tri if a == ano]
            if not tris_ano:
                return 0, 0
            v = benef_tri[(ano, max(tris_ano))]
            return v[0], v[1]

        serie: List[Dict[str, Any]] = []
        for (ano, tri), b in sorted(buckets.items()):
            bmh, bod = _benef_bucket(ano, tri)
            serie.append(
                {
                    "periodo": _fmt_periodo(ano, tri or None),
                    "ano": ano,
                    "trimestre": tri or None,
                    "operadoras": len(b["ops"]),
                    "receitas": round(b["receitas"], 2),
                    "despesas": round(b["despesas"], 2),
                    "eventos_mh": round(b["eventos_mh"], 2),
                    "comercializacao": round(b["comercializacao"], 2),
                    "administrativas": round(b["administrativas"], 2),
                    "resultado": round(b["receitas"] - b["despesas"] - b["comercializacao"] - b["administrativas"], 2),
                    "sinistralidade": (b["despesas"] / b["receitas"]) if b["receitas"] > 0 else None,
                    "indice_combinado": (
                        (b["despesas"] + b["comercializacao"] + b["administrativas"]) / b["receitas"]
                        if b["receitas"] > 0
                        else None
                    ),
                    "benef_mh": bmh,
                    "benef_odonto": bod,
                    "benef_total": bmh + bod,
                    "ticket_medio": (b["eventos_mh"] / bmh) if bmh > 0 else None,
                }
            )

        # Agregação por modalidade e por UF
        def _agrupar(campo: str) -> List[Dict[str, Any]]:
            acc: Dict[str, Dict[str, Any]] = defaultdict(
                lambda: {
                    "operadoras": 0,
                    "receitas": 0.0,
                    "despesas": 0.0,
                    "eventos_mh": 0.0,
                    "comercializacao": 0.0,
                    "administrativas": 0.0,
                    "benef_mh": 0,
                    "benef_odonto": 0,
                }
            )
            for op in por_op.values():
                g = acc[op[campo] or "Não informada"]
                g["operadoras"] += 1
                g["receitas"] += op["receitas"]
                g["despesas"] += op["despesas"]
                g["eventos_mh"] += op["eventos_mh"]
                g["comercializacao"] += op["comercializacao"]
                g["administrativas"] += op["administrativas"]
                g["benef_mh"] += op["benef_mh"]
                g["benef_odonto"] += op["benef_odonto"]
            total_desp_g = sum(v["despesas"] for v in acc.values()) or 1.0
            saida = []
            for chave, v in sorted(acc.items(), key=lambda item: item[1]["despesas"], reverse=True):
                saida.append(
                    {
                        campo: chave,
                        "operadoras": v["operadoras"],
                        "receitas": round(v["receitas"], 2),
                        "despesas": round(v["despesas"], 2),
                        "eventos_mh": round(v["eventos_mh"], 2),
                        "comercializacao": round(v["comercializacao"], 2),
                        "administrativas": round(v["administrativas"], 2),
                        "resultado": round(v["receitas"] - v["despesas"] - v["comercializacao"] - v["administrativas"], 2),
                        "sinistralidade": (v["despesas"] / v["receitas"]) if v["receitas"] > 0 else None,
                        "participacao": v["despesas"] / total_desp_g,
                        "benef_mh": v["benef_mh"],
                        "benef_odonto": v["benef_odonto"],
                        "ticket_medio": (v["eventos_mh"] / v["benef_mh"]) if v["benef_mh"] > 0 else None,
                    }
                )
            return saida

        por_modalidade = _agrupar("modalidade")
        por_uf = _agrupar("uf")

        # Ordenação das operadoras
        chave_ordem = cfg["ordenar_por"]
        operadoras = sorted(
            por_op.values(),
            key=lambda o: (o.get(chave_ordem) is not None, float(o.get(chave_ordem) or 0.0)),
            reverse=True,
        )
        total_operadoras = len(operadoras)
        if cfg["limite_operadoras"] is not None:
            operadoras = operadoras[: cfg["limite_operadoras"]]

        # Totais consolidados (sobre TODO o recorte, independente do limite do ranking)
        tot_rec = sum(o["receitas"] for o in por_op.values())
        tot_desp = sum(o["despesas"] for o in por_op.values())
        tot_mh = sum(o["eventos_mh"] for o in por_op.values())
        tot_com = sum(o["comercializacao"] for o in por_op.values())
        tot_adm = sum(o["administrativas"] for o in por_op.values())
        ultimo_tri = max(benef_tri) if benef_tri else None
        tot_bmh = benef_tri[ultimo_tri][0] if ultimo_tri else 0
        tot_bod = benef_tri[ultimo_tri][1] if ultimo_tri else 0

        contas = pacote["contas_setor"]
        cadastro = cadastro_completo if "lotes_cadastro" in cfg["secoes"] else []
        despesas_resumo = pacote["despesas_resumo"]

        # Base fato materializada em dicts apenas quando necessário (XLSX usa tuplas direto sem overhead)
        base_demo_dicts: List[Dict[str, Any]] = []
        if "base_demonstracoes" in cfg["secoes"] and not _tuplas_fato:
            base_demo_dicts = [
                {
                    "ano": ano,
                    "trimestre": tri,
                    "reg_ans": reg,
                    "cnpj": ops_map[reg]["cnpj"],
                    "razao_social": ops_map[reg]["razao_social"],
                    "nome_fantasia": ops_map[reg]["nome_fantasia"],
                    "modalidade": ops_map[reg]["modalidade"],
                    "uf": ops_map[reg]["uf"],
                    "cidade": ops_map[reg]["cidade"],
                    "status": ops_map[reg]["status"],
                    "contraprestacoes": rec,
                    "eventos": ev,
                    "eventos_mh": ev_mh,
                    "comercializacao": com,
                    "administrativas": adm,
                    "benef_mh": bmh,
                    "benef_odonto": bod,
                    "auditado": aud,
                }
                for (ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, aud) in fatos
            ]

        # Rótulo amigável do recorte
        filtros_txt = []
        if cfg["ufs"]:
            filtros_txt.append(f"UF: {', '.join(cfg['ufs'])}")
        if cfg["modalidades"]:
            filtros_txt.append(f"Modalidade: {', '.join(cfg['modalidades'])}")
        if cfg["statuses"]:
            filtros_txt.append(f"Status: {', '.join(cfg['statuses'])}")
        if cfg["portes"]:
            filtros_txt.append(f"Porte: {', '.join(cfg['portes'])}")
        if cfg["consolidacao"]:
            filtros_txt.append(f"Consolidação: {cfg['consolidacao']}")
        recorte = " · ".join(
            [
                f"Período {_rotulo_anos(cfg['anos'])} ({_rotulo_trimestres(cfg['trimestres'])})",
                *filtros_txt,
                f"{total_operadoras} operadoras · {len(fatos)} registros contábeis ETL",
            ]
        )

        return {
            "cfg": cfg,
            "usuario": usuario_nome,
            "gerado_em": datetime.now(),
            "recorte": recorte,
            "kpis": {
                "operadoras": total_operadoras,
                "registros_demonstracoes": len(fatos),
                "receitas": round(tot_rec, 2),
                "despesas": round(tot_desp, 2),
                "eventos_mh": round(tot_mh, 2),
                "comercializacao": round(tot_com, 2),
                "administrativas": round(tot_adm, 2),
                "resultado": round(tot_rec - tot_desp - tot_com - tot_adm, 2),
                "sinistralidade": (tot_desp / tot_rec) if tot_rec > 0 else None,
                "indice_combinado": ((tot_desp + tot_com + tot_adm) / tot_rec) if tot_rec > 0 else None,
                "benef_mh": tot_bmh,
                "benef_odonto": tot_bod,
                "benef_total": tot_bmh + tot_bod,
                "ticket_medio": (tot_mh / tot_bmh) if tot_bmh > 0 else None,
                "lotes_total": len(lotes),
                "lotes_auditados": sum(1 for l in lotes if bool(l.get("auditado"))),
                "registros_extraidos_ans": sum(int(l.get("registros_extraidos") or 0) for l in lotes),
                "despesas_lancamentos": despesas_resumo["total_registros"],
            },
            "serie": serie,
            "por_modalidade": por_modalidade,
            "por_uf": por_uf,
            "operadoras": operadoras,
            "base_demonstracoes": base_demo_dicts,
            "_fatos_tuplas": fatos if "base_demonstracoes" in cfg["secoes"] else [],
            "_ops_map": ops_map,
            "contas_setor": contas,
            "lotes_etl": lotes,
            "cadastro_operadoras": cadastro,
        }

    # ------------------------------------------------------------------ XLSX (openpyxl + OOXML streaming)
    @classmethod
    def gerar_xlsx(cls, payload: Dict[str, Any], usuario_nome: str = "") -> Tuple[bytes, str]:
        dados = cls.coletar_dados(payload, usuario_nome=usuario_nome, _tuplas_fato=True)
        cfg = dados["cfg"]
        st = _Estilos()
        wb = Workbook()
        wb.remove(wb.active)
        reg = _StyleRegistry(wb)
        # Mapa nome_da_aba -> (ultima_col_letra, ultima_linha, bytes_xml_rows)
        stream_patches: Dict[str, Tuple[str, int, bytes]] = {}

        fmt_data = cfg["formato_data"]
        gerado_txt = _fmt_data(dados["gerado_em"], formato=fmt_data, hora=True)
        subtitulo = f"{dados['recorte']} · Gerado em {gerado_txt}" + (
            f" por {usuario_nome}" if usuario_nome else ""
        )

        secoes = cfg["secoes"]
        if "resumo" in secoes:
            cls._aba_resumo(wb, dados, subtitulo, st)
        if "evolucao" in secoes:
            cls._aba_evolucao(wb, dados, subtitulo, st)
        if "modalidades" in secoes:
            cls._aba_modalidades(wb, dados, subtitulo, st)
        if "ufs" in secoes:
            cls._aba_ufs(wb, dados, subtitulo, st)
        if "operadoras" in secoes:
            cls._aba_operadoras(wb, dados, subtitulo, st, reg, stream_patches)
        if "contas_setor" in secoes:
            cls._aba_contas_setor(wb, dados, subtitulo, st, reg, stream_patches)
        if "base_demonstracoes" in secoes:
            cls._aba_base_demonstracoes(wb, dados, subtitulo, st, reg, stream_patches)
        if "lotes_cadastro" in secoes:
            cls._aba_lotes(wb, dados, subtitulo, st, fmt_data)
            cls._aba_cadastro(wb, dados, subtitulo, st, fmt_data, reg, stream_patches)

        reg.cleanup()
        if not wb.sheetnames:
            cls._aba_resumo(wb, dados, subtitulo, st)

        buf = BytesIO()
        wb.save(buf)
        conteudo = cls._aplicar_stream_patches(buf.getvalue(), stream_patches) if stream_patches else buf.getvalue()

        anos = cfg["anos"]
        sufixo = str(anos[0]) if len(anos) == 1 else f"{anos[0]}_{anos[-1]}"
        return conteudo, f"relatorio_etl_ans_{sufixo}.xlsx"

    @staticmethod
    def _aplicar_stream_patches(xlsx_base: bytes, patches: Dict[str, Tuple[str, int, bytes]]) -> bytes:
        """Injeta blocos de linhas OOXML pré-serializados diretamente nas abas volumosas do `.xlsx`."""
        buf_in = BytesIO(xlsx_base)
        buf_out = BytesIO()
        with zipfile.ZipFile(buf_in, "r") as zin:
            aba_para_path = _mapear_paths_abas(zin)
            path_para_patch: Dict[str, Tuple[str, int, bytes]] = {}
            for nome_aba, patch in patches.items():
                target = aba_para_path.get(nome_aba)
                if target:
                    path_para_patch[target] = patch

            with zipfile.ZipFile(buf_out, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as zout:
                for item in zin.infolist():
                    data = zin.read(item.filename)
                    patch = path_para_patch.get(item.filename)
                    if patch is not None:
                        last_col, max_row, chunk = patch
                        data = data.replace(b"</sheetData>", chunk + b"</sheetData>", 1)
                        dim_bytes = f'<dimension ref="A1:{last_col}{max_row}"'.encode("ascii")
                        data = _DIM_RE.sub(dim_bytes, data, count=1)
                    zout.writestr(item, data)
        return buf_out.getvalue()

    @staticmethod
    def _cabecalho_planilha(ws, titulo: str, subtitulo: str, ncols: int, st: Dict[str, Any]) -> int:
        ws.views.sheetView[0].showGridLines = True
        ws.page_setup.orientation = ws.ORIENTATION_LANDSCAPE
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.sheet_properties.pageSetUpPr.fitToPage = True

        last_col = get_column_letter(max(ncols, 2))
        ws.merge_cells(f"A1:{last_col}1")
        c1 = ws["A1"]
        c1.value = f"INTUITIVE CARE · {titulo.upper()}"
        c1.font = st["banner_font"]
        c1.fill = st["banner_fill"]
        c1.alignment = Alignment(horizontal="left", vertical="center", indent=1)
        ws.row_dimensions[1].height = 30

        ws.merge_cells(f"A2:{last_col}2")
        c2 = ws["A2"]
        c2.value = subtitulo
        c2.font = st["sub_font"]
        c2.fill = st["sub_fill"]
        c2.alignment = Alignment(horizontal="left", vertical="center", indent=1)
        ws.row_dimensions[2].height = 20
        ws.row_dimensions[3].height = 8
        return 4

    @staticmethod
    def _escrever_headers(ws, row_idx: int, headers: Sequence[Tuple[str, str]], st: Dict[str, Any]) -> None:
        ws.row_dimensions[row_idx].height = 28
        for idx, (titulo, alinhamento) in enumerate(headers, start=1):
            c = ws.cell(row=row_idx, column=idx, value=titulo)
            c.font = st["head_font"]
            c.fill = st["head_fill"]
            c.border = st["border"]
            c.alignment = st[f"align_head_{alinhamento}"]

    @staticmethod
    def _ajustar_larguras(ws, larguras: Sequence[float]) -> None:
        for idx, w in enumerate(larguras, start=1):
            ws.column_dimensions[get_column_letter(idx)].width = w

    @classmethod
    def _aba_resumo(cls, wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
        ws = wb.create_sheet("Resumo Executivo")
        k = dados["kpis"]
        row = cls._cabecalho_planilha(ws, "Relatório Analítico ANS · Resumo Executivo", subtitulo, 6, st)

        ws.cell(row=row, column=1, value="1. INDICADORES CONSOLIDADOS DO RECORTE (BASES ETL)").font = st["sec_font"]
        row += 1
        cls._escrever_headers(
            ws, row, [("Indicador", "l"), ("Valor Consolidado", "r"), ("Unidade / Base ETL", "l"), ("Observação", "l")], st
        )
        row += 1

        r_rec = row + 1
        r_desp = row + 2
        r_mh = row + 3
        r_com = row + 4
        r_adm = row + 5
        r_bmh = row + 9
        r_bod = row + 10

        linhas_kpi = [
            ("Operadoras com demonstração no recorte", k["operadoras"], FMT_INT, "operadoras × demonstracoes_operadora", "Operadoras únicas com movimentação contábil no período"),
            ("Receitas / Contraprestações Efetivas (Conta 311)", k["receitas"], FMT_MOEDA, "demonstracoes_operadora.contraprestacoes", "Soma das contraprestações efetivas líquidas"),
            ("Despesas / Eventos Indenizáveis Líquidos (Conta 41)", k["despesas"], FMT_MOEDA, "demonstracoes_operadora.eventos", "Soma total dos eventos assistenciais líquidos"),
            ("Despesas Médico-Hospitalares (Conta 411)", k["eventos_mh"], FMT_MOEDA, "demonstracoes_operadora.eventos_mh", "Parcela médico-hospitalar dos eventos"),
            ("Despesas de Comercialização (Conta 43)", k["comercializacao"], FMT_MOEDA, "demonstracoes_operadora.comercializacao", "Custos de aquisição e intermediação"),
            ("Despesas Administrativas (Conta 46)", k["administrativas"], FMT_MOEDA, "demonstracoes_operadora.administrativas", "Estrutura administrativa das operadoras"),
            ("Resultado Operacional Líquido", f"=B{r_rec}-B{r_desp}-B{r_com}-B{r_adm}", FMT_MOEDA, "Fórmula: Contraprestações - (Eventos + Comerc. + Admin.)", "Margem operacional bruta do recorte"),
            ("Sinistralidade Consolidada", f"=IF(B{r_rec}>0,B{r_desp}/B{r_rec},0)", FMT_PCT, "Fórmula: Eventos / Contraprestações", "Relação assistencial consolidada do setor no recorte"),
            ("Índice Combinado Operacional", f"=IF(B{r_rec}>0,(B{r_desp}+B{r_com}+B{r_adm})/B{r_rec},0)", FMT_PCT, "Fórmula: (Eventos + Comerc. + Admin.) / Contraprestações", "Abaixo de 100% indica superávit operacional"),
            ("Beneficiários Médico-Hospitalares", k["benef_mh"], FMT_INT, "beneficiarios_trimestre.medico_hospitalar", "Posição no trimestre de fechamento do período"),
            ("Beneficiários Odontológicos", k["benef_odonto"], FMT_INT, "beneficiarios_trimestre.odontologico", "Posição no trimestre de fechamento do período"),
            ("Beneficiários Totais (MH + Odonto)", f"=B{r_bmh}+B{r_bod}", FMT_INT, "Fórmula: MH + Odontológico", "Carteira total no fechamento do período"),
            ("Ticket Médio Assistencial (MH)", f"=IF(B{r_bmh}>0,B{r_mh}/B{r_bmh},0)", FMT_MOEDA, "Fórmula: Eventos MH / Beneficiários MH", "Despesa médico-hospitalar acumulada por beneficiário"),
        ]
        for i, (ind, val, num_fmt, origem, obs) in enumerate(linhas_kpi):
            zebra = i % 2 == 1
            ws.row_dimensions[row].height = 20
            c1 = ws.cell(row=row, column=1, value=ind)
            c2 = ws.cell(row=row, column=2, value=val)
            c3 = ws.cell(row=row, column=3, value=origem)
            c4 = ws.cell(row=row, column=4, value=obs)
            c2.number_format = num_fmt
            for col_i, cell in enumerate((c1, c2, c3, c4), start=1):
                cell.font = st["data_bold"] if col_i in (1, 2) else st["data_font"]
                cell.border = st["border"]
                if zebra:
                    cell.fill = st["zebra_fill"]
                cell.alignment = st["align_r"] if col_i == 2 else st["align_l"]
            row += 1

        row += 1
        ws.cell(row=row, column=1, value="2. COBERTURA E RASTREABILIDADE DO ETL (ANS)").font = st["sec_font"]
        row += 1
        cls._escrever_headers(ws, row, [("Dimensão ETL", "l"), ("Quantidade / Valor", "r"), ("Tabela Origem", "l"), ("Detalhamento", "l")], st)
        row += 1
        etl_rows = [
            ("Lotes trimestrais no recorte", k["lotes_total"], FMT_INT, "lotes_etl", f"{k['lotes_auditados']} auditado(s) · {k['lotes_total'] - k['lotes_auditados']} pendente(s)"),
            ("Registros contábeis brutos extraídos da ANS", k["registros_extraidos_ans"], FMT_INT, "lotes_etl.registros_extraidos", "Total de lançamentos lidos nos arquivos trimestrais oficiais"),
            ("Demonstrações operadora × trimestre no recorte", k["registros_demonstracoes"], FMT_INT, "demonstracoes_operadora", "Registros fato disponíveis na aba Base ETL Demonstrações"),
            ("Lançamentos de despesas consolidados no período", k["despesas_lancamentos"], FMT_INT, "despesas", "Série histórica de despesas registrada na tabela despesas"),
        ]
        for i, (dim, val, nf, tab, det) in enumerate(etl_rows):
            ws.row_dimensions[row].height = 20
            for ci, (v, align) in enumerate(((dim, "l"), (val, "r"), (tab, "l"), (det, "l")), start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["data_bold"] if ci == 2 else st["data_font"]
                cell.border = st["border"]
                cell.alignment = st[f"align_{align}"]
                if i % 2 == 1:
                    cell.fill = st["zebra_fill"]
                if ci == 2:
                    cell.number_format = nf
            row += 1

        if dados["por_uf"]:
            row += 1
            ws.cell(row=row, column=1, value="3. TOP 10 UFs POR DESPESA ASSISTENCIAL").font = st["sec_font"]
            row += 1
            cls._escrever_headers(
                ws,
                row,
                [
                    ("UF", "c"),
                    ("Operadoras", "r"),
                    ("Receitas (R$)", "r"),
                    ("Despesas / Eventos (R$)", "r"),
                    ("Sinistralidade (%)", "r"),
                    ("Beneficiários MH", "r"),
                ],
                st,
            )
            row += 1
            for i, u in enumerate(dados["por_uf"][:10]):
                ws.row_dimensions[row].height = 19
                vals = [
                    (u["uf"], "c", None),
                    (u["operadoras"], "r", FMT_INT),
                    (u["receitas"], "r", FMT_MOEDA),
                    (u["despesas"], "r", FMT_MOEDA),
                    (f"=IF(C{row}>0,D{row}/C{row},0)", "r", FMT_PCT),
                    (u["benef_mh"], "r", FMT_INT),
                ]
                for ci, (v, al, nf) in enumerate(vals, start=1):
                    cell = ws.cell(row=row, column=ci, value=v)
                    cell.font = st["data_font"]
                    cell.border = st["border"]
                    cell.alignment = st[f"align_{al}"]
                    if i % 2 == 1:
                        cell.fill = st["zebra_fill"]
                    if nf:
                        cell.number_format = nf
                row += 1

        cls._ajustar_larguras(ws, [46, 24, 38, 48, 18, 18])

    @classmethod
    def _aba_evolucao(cls, wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
        ws = wb.create_sheet("Evolução Período")
        headers = [
            ("Período", "l"),
            ("Ano", "c"),
            ("Operadoras", "r"),
            ("Receitas / Contraprestações (R$)", "r"),
            ("Despesas / Eventos (R$)", "r"),
            ("Eventos MH (R$)", "r"),
            ("Comercialização (R$)", "r"),
            ("Administrativas (R$)", "r"),
            ("Resultado Operacional (R$)", "r"),
            ("Sinistralidade (%)", "r"),
            ("Índice Combinado (%)", "r"),
            ("Var. Despesas (%)", "r"),
            ("Beneficiários MH", "r"),
            ("Beneficiários Odonto", "r"),
            ("Beneficiários Total", "r"),
            ("Ticket Médio MH (R$)", "r"),
        ]
        head_row = cls._cabecalho_planilha(ws, "Evolução Financeira e Assistencial", subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"

        serie = dados["serie"]
        start = head_row + 1
        row = start
        for i, p in enumerate(serie):
            ws.row_dimensions[row].height = 20
            var_formula = f"=IF(E{row - 1}>0,(E{row}-E{row - 1})/E{row - 1},0)" if i > 0 else None
            vals = [
                (p["periodo"], "l", None),
                (p["ano"], "c", "0"),
                (p["operadoras"], "r", FMT_INT),
                (p["receitas"], "r", FMT_MOEDA),
                (p["despesas"], "r", FMT_MOEDA),
                (p["eventos_mh"], "r", FMT_MOEDA),
                (p["comercializacao"], "r", FMT_MOEDA),
                (p["administrativas"], "r", FMT_MOEDA),
                (f"=D{row}-E{row}-G{row}-H{row}", "r", FMT_MOEDA),
                (f"=IF(D{row}>0,E{row}/D{row},0)", "r", FMT_PCT),
                (f"=IF(D{row}>0,(E{row}+G{row}+H{row})/D{row},0)", "r", FMT_PCT),
                (var_formula, "r", FMT_PCT),
                (p["benef_mh"], "r", FMT_INT),
                (p["benef_odonto"], "r", FMT_INT),
                (f"=M{row}+N{row}", "r", FMT_INT),
                (f"=IF(M{row}>0,F{row}/M{row},0)", "r", FMT_MOEDA),
            ]
            for ci, (v, al, nf) in enumerate(vals, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["data_font"]
                cell.border = st["border"]
                cell.alignment = st[f"align_{al}"]
                if i % 2 == 1:
                    cell.fill = st["zebra_fill"]
                if nf and v is not None:
                    cell.number_format = nf
            row += 1

        if serie:
            end = row - 1
            ws.row_dimensions[row].height = 22
            totais = [
                ("TOTAL / CONSOLIDADO", "l", None),
                ("", "c", None),
                (f"=MAX(C{start}:C{end})", "r", FMT_INT),
                (f"=SUM(D{start}:D{end})", "r", FMT_MOEDA),
                (f"=SUM(E{start}:E{end})", "r", FMT_MOEDA),
                (f"=SUM(F{start}:F{end})", "r", FMT_MOEDA),
                (f"=SUM(G{start}:G{end})", "r", FMT_MOEDA),
                (f"=SUM(H{start}:H{end})", "r", FMT_MOEDA),
                (f"=D{row}-E{row}-G{row}-H{row}", "r", FMT_MOEDA),
                (f"=IF(D{row}>0,E{row}/D{row},0)", "r", FMT_PCT),
                (f"=IF(D{row}>0,(E{row}+G{row}+H{row})/D{row},0)", "r", FMT_PCT),
                (f"=IF(E{start}>0,(E{end}-E{start})/E{start},0)" if len(serie) > 1 else None, "r", FMT_PCT),
                (f"=M{end}", "r", FMT_INT),
                (f"=N{end}", "r", FMT_INT),
                (f"=M{row}+N{row}", "r", FMT_INT),
                (f"=IF(M{row}>0,F{row}/M{row},0)", "r", FMT_MOEDA),
            ]
            for ci, (v, al, nf) in enumerate(totais, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["total_font"]
                cell.fill = st["total_fill"]
                cell.border = st["total_border"]
                cell.alignment = st[f"align_{al}"]
                if nf and v is not None:
                    cell.number_format = nf
            ws.auto_filter.ref = f"A{head_row}:{get_column_letter(len(headers))}{end}"

            chart = BarChart()
            chart.type = "col"
            chart.grouping = "clustered"
            chart.title = "Evolução: Receitas vs Despesas Assistenciais (R$)"
            chart.y_axis.number_format = 'R$ #,##0,,"M"'
            chart.width = 24
            chart.height = 11
            data_ref = Reference(ws, min_col=4, max_col=5, min_row=head_row, max_row=end)
            cats_ref = Reference(ws, min_col=1, min_row=start, max_row=end)
            chart.add_data(data_ref, titles_from_data=True)
            chart.set_categories(cats_ref)
            if len(chart.series) >= 2:
                chart.series[0].graphicalProperties.solidFill = _COR_FOREST
                chart.series[1].graphicalProperties.solidFill = _COR_MINT
            ws.add_chart(chart, f"A{row + 2}")

        cls._ajustar_larguras(ws, [22, 8, 12, 22, 22, 20, 18, 18, 22, 15, 16, 15, 16, 16, 16, 18])

    @classmethod
    def _aba_agrupada(
        cls, wb: Workbook, titulo_aba: str, titulo_doc: str, subtitulo: str, campo: str, label_campo: str,
        itens: List[Dict[str, Any]], st: Dict[str, Any], com_grafico: bool = False
    ) -> None:
        ws = wb.create_sheet(titulo_aba)
        headers = [
            (label_campo, "l"),
            ("Operadoras", "r"),
            ("Receitas (R$)", "r"),
            ("Despesas / Eventos (R$)", "r"),
            ("Eventos MH (R$)", "r"),
            ("Comercialização (R$)", "r"),
            ("Administrativas (R$)", "r"),
            ("Resultado Operacional (R$)", "r"),
            ("Sinistralidade (%)", "r"),
            ("Partic. Despesas (%)", "r"),
            ("Beneficiários MH", "r"),
            ("Beneficiários Odonto", "r"),
            ("Ticket Médio MH (R$)", "r"),
        ]
        head_row = cls._cabecalho_planilha(ws, titulo_doc, subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"

        start = head_row + 1
        total_row = start + len(itens)
        row = start
        for i, item in enumerate(itens):
            ws.row_dimensions[row].height = 20
            vals = [
                (item[campo], "l", None),
                (item["operadoras"], "r", FMT_INT),
                (item["receitas"], "r", FMT_MOEDA),
                (item["despesas"], "r", FMT_MOEDA),
                (item["eventos_mh"], "r", FMT_MOEDA),
                (item["comercializacao"], "r", FMT_MOEDA),
                (item["administrativas"], "r", FMT_MOEDA),
                (f"=C{row}-D{row}-F{row}-G{row}", "r", FMT_MOEDA),
                (f"=IF(C{row}>0,D{row}/C{row},0)", "r", FMT_PCT),
                (f"=IF(D${total_row}>0,D{row}/D${total_row},0)", "r", FMT_PCT),
                (item["benef_mh"], "r", FMT_INT),
                (item["benef_odonto"], "r", FMT_INT),
                (f"=IF(K{row}>0,E{row}/K{row},0)", "r", FMT_MOEDA),
            ]
            for ci, (v, al, nf) in enumerate(vals, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["data_font"]
                cell.border = st["border"]
                cell.alignment = st[f"align_{al}"]
                if i % 2 == 1:
                    cell.fill = st["zebra_fill"]
                if nf:
                    cell.number_format = nf
            row += 1

        if itens:
            end = row - 1
            ws.row_dimensions[row].height = 22
            totais = [
                ("TOTAL", "l", None),
                (f"=SUM(B{start}:B{end})", "r", FMT_INT),
                (f"=SUM(C{start}:C{end})", "r", FMT_MOEDA),
                (f"=SUM(D{start}:D{end})", "r", FMT_MOEDA),
                (f"=SUM(E{start}:E{end})", "r", FMT_MOEDA),
                (f"=SUM(F{start}:F{end})", "r", FMT_MOEDA),
                (f"=SUM(G{start}:G{end})", "r", FMT_MOEDA),
                (f"=C{row}-D{row}-F{row}-G{row}", "r", FMT_MOEDA),
                (f"=IF(C{row}>0,D{row}/C{row},0)", "r", FMT_PCT),
                (f"=SUM(J{start}:J{end})", "r", FMT_PCT),
                (f"=SUM(K{start}:K{end})", "r", FMT_INT),
                (f"=SUM(L{start}:L{end})", "r", FMT_INT),
                (f"=IF(K{row}>0,E{row}/K{row},0)", "r", FMT_MOEDA),
            ]
            for ci, (v, al, nf) in enumerate(totais, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["total_font"]
                cell.fill = st["total_fill"]
                cell.border = st["total_border"]
                cell.alignment = st[f"align_{al}"]
                if nf:
                    cell.number_format = nf
            ws.auto_filter.ref = f"A{head_row}:{get_column_letter(len(headers))}{end}"

            if com_grafico:
                chart = BarChart()
                chart.type = "bar"
                chart.title = f"Despesas Assistenciais por {label_campo} (R$)"
                chart.x_axis.number_format = 'R$ #,##0,,"M"'
                chart.width = 22
                chart.height = 11
                chart.legend = None
                data_ref = Reference(ws, min_col=4, min_row=head_row, max_row=min(end, start + 9))
                cats_ref = Reference(ws, min_col=1, min_row=start, max_row=min(end, start + 9))
                chart.add_data(data_ref, titles_from_data=True)
                chart.set_categories(cats_ref)
                if chart.series:
                    chart.series[0].graphicalProperties.solidFill = _COR_FOREST
                ws.add_chart(chart, f"A{row + 2}")

        larg_col1 = 30 if campo == "modalidade" else 10
        cls._ajustar_larguras(ws, [larg_col1, 12, 20, 20, 20, 18, 18, 20, 15, 16, 16, 16, 18])

    @classmethod
    def _aba_modalidades(cls, wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
        cls._aba_agrupada(
            wb, "Por Modalidade", "Consolidado por Modalidade ANS", subtitulo,
            "modalidade", "Modalidade", dados["por_modalidade"], st, com_grafico=True,
        )

    @classmethod
    def _aba_ufs(cls, wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
        cls._aba_agrupada(
            wb, "Por UF", "Distribuição Regional por UF", subtitulo,
            "uf", "UF", dados["por_uf"], st, com_grafico=False,
        )

    @classmethod
    def _aba_operadoras(
        cls,
        wb: Workbook,
        dados: Dict[str, Any],
        subtitulo: str,
        st: Dict[str, Any],
        reg: _StyleRegistry,
        patches: Dict[str, Tuple[str, int, bytes]],
    ) -> None:
        nome_aba = "Operadoras Consolidado"
        ws = wb.create_sheet(nome_aba)
        headers = [
            ("Registro ANS", "c"),
            ("CNPJ", "c"),
            ("Razão Social", "l"),
            ("Nome Fantasia", "l"),
            ("Modalidade", "l"),
            ("UF", "c"),
            ("Cidade", "l"),
            ("Status", "c"),
            ("Porte ANS", "l"),
            ("Trimestres", "r"),
            ("Receitas (R$)", "r"),
            ("Despesas / Eventos (R$)", "r"),
            ("Eventos MH (R$)", "r"),
            ("Comercialização (R$)", "r"),
            ("Administrativas (R$)", "r"),
            ("Resultado Operacional (R$)", "r"),
            ("Sinistralidade (%)", "r"),
            ("Índice Combinado (%)", "r"),
            ("Beneficiários MH", "r"),
            ("Beneficiários Odonto", "r"),
            ("Ticket Médio MH (R$)", "r"),
        ]
        head_row = cls._cabecalho_planilha(ws, "Ranking e Consolidado de Operadoras", subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"E{head_row + 1}"
        cls._ajustar_larguras(
            ws, [13, 19, 34, 24, 24, 6, 18, 10, 14, 11, 20, 20, 19, 18, 18, 20, 14, 15, 16, 16, 18]
        )

        ops = dados["operadoras"]
        if not ops:
            return
        start = head_row + 1
        end = start + len(ops) - 1
        total_row = end + 1
        ws.auto_filter.ref = f"A{head_row}:U{end}"

        if len(ops) <= _STREAM_THRESHOLD:
            row = start
            for i, o in enumerate(ops):
                zebra = i % 2 == 1
                vals = [
                    (o["registro_ans"], "c", "@"),
                    (o["cnpj"], "c", "@"),
                    (o["razao_social"], "l", None),
                    (o["nome_fantasia"], "l", None),
                    (o["modalidade"], "l", None),
                    (o["uf"], "c", None),
                    (o["cidade"], "l", None),
                    (o["status"], "c", None),
                    (o["porte"], "l", None),
                    (o["trimestres"], "r", FMT_INT),
                    (o["receitas"], "r", FMT_MOEDA),
                    (o["despesas"], "r", FMT_MOEDA),
                    (o["eventos_mh"], "r", FMT_MOEDA),
                    (o["comercializacao"], "r", FMT_MOEDA),
                    (o["administrativas"], "r", FMT_MOEDA),
                    (f"=K{row}-L{row}-N{row}-O{row}", "r", FMT_MOEDA),
                    (f"=IF(K{row}>0,L{row}/K{row},0)", "r", FMT_PCT),
                    (f"=IF(K{row}>0,(L{row}+N{row}+O{row})/K{row},0)", "r", FMT_PCT),
                    (o["benef_mh"], "r", FMT_INT),
                    (o["benef_odonto"], "r", FMT_INT),
                    (f"=IF(S{row}>0,M{row}/S{row},0)", "r", FMT_MOEDA),
                ]
                for ci, (v, al, nf) in enumerate(vals, start=1):
                    cell = ws.cell(row=row, column=ci, value=v)
                    cell.font = st["data_font"]
                    cell.border = st["border"]
                    cell.alignment = st[f"align_{al}"]
                    if zebra:
                        cell.fill = st["zebra_fill"]
                    if nf:
                        cell.number_format = nf
                sin = o.get("sinistralidade")
                if sin is not None:
                    c_sin = ws.cell(row=row, column=17)
                    if sin > 0.85:
                        c_sin.fill = st["err_fill"]
                        c_sin.font = st["err_font"]
                    elif sin < 0.70:
                        c_sin.fill = st["ok_fill"]
                        c_sin.font = st["ok_font"]
                row += 1

            ws.row_dimensions[total_row].height = 22
            totais = [
                ("TOTAL", "l", None),
                ("", "c", None),
                (f"{len(ops)} operadora(s)", "l", None),
                ("", "l", None), ("", "l", None), ("", "c", None), ("", "l", None), ("", "c", None), ("", "l", None),
                (f"=SUM(J{start}:J{end})", "r", FMT_INT),
                (f"=SUM(K{start}:K{end})", "r", FMT_MOEDA),
                (f"=SUM(L{start}:L{end})", "r", FMT_MOEDA),
                (f"=SUM(M{start}:M{end})", "r", FMT_MOEDA),
                (f"=SUM(N{start}:N{end})", "r", FMT_MOEDA),
                (f"=SUM(O{start}:O{end})", "r", FMT_MOEDA),
                (f"=K{total_row}-L{total_row}-N{total_row}-O{total_row}", "r", FMT_MOEDA),
                (f"=IF(K{total_row}>0,L{total_row}/K{total_row},0)", "r", FMT_PCT),
                (f"=IF(K{total_row}>0,(L{total_row}+N{total_row}+O{total_row})/K{total_row},0)", "r", FMT_PCT),
                (f"=SUM(S{start}:S{end})", "r", FMT_INT),
                (f"=SUM(T{start}:T{end})", "r", FMT_INT),
                (f"=IF(S{total_row}>0,M{total_row}/S{total_row},0)", "r", FMT_MOEDA),
            ]
            for ci, (v, al, nf) in enumerate(totais, start=1):
                cell = ws.cell(row=total_row, column=ci, value=v)
                cell.font = st["total_font"]
                cell.fill = st["total_fill"]
                cell.border = st["total_border"]
                cell.alignment = st[f"align_{al}"]
                if nf:
                    cell.number_format = nf
            return

        # Caminho OOXML streaming para grande volume de operadoras (preserva fórmulas vivas + estilos)
        borda = st["border"]
        def _pair(al: str, nf: Optional[str] = None) -> Tuple[int, int]:
            return (
                reg.get(font=st["data_font"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_font"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
            )

        s_txt_l = _pair("l")
        s_txt_c = _pair("c")
        s_txt_at = _pair("c", "@")
        s_int = _pair("r", FMT_INT)
        s_moeda = _pair("r", FMT_MOEDA)
        s_pct = _pair("r", FMT_PCT)
        s_sin_err = reg.get(font=st["err_font"], fill=st["err_fill"], border=borda, alignment=st["align_r"], number_format=FMT_PCT)
        s_sin_ok = reg.get(font=st["ok_font"], fill=st["ok_fill"], border=borda, alignment=st["align_r"], number_format=FMT_PCT)

        s_tot_l = reg.get(font=st["total_font"], fill=st["total_fill"], border=st["total_border"], alignment=st["align_l"])
        s_tot_c = reg.get(font=st["total_font"], fill=st["total_fill"], border=st["total_border"], alignment=st["align_c"])
        s_tot_int = reg.get(font=st["total_font"], fill=st["total_fill"], border=st["total_border"], alignment=st["align_r"], number_format=FMT_INT)
        s_tot_moeda = reg.get(font=st["total_font"], fill=st["total_fill"], border=st["total_border"], alignment=st["align_r"], number_format=FMT_MOEDA)
        s_tot_pct = reg.get(font=st["total_font"], fill=st["total_fill"], border=st["total_border"], alignment=st["align_r"], number_format=FMT_PCT)

        xml_rows: List[str] = []
        append = xml_rows.append
        for i, o in enumerate(ops):
            r = start + i
            z = i & 1
            sin = o.get("sinistralidade")
            sin_style = s_sin_err if (sin is not None and sin > 0.85) else (s_sin_ok if (sin is not None and sin < 0.70) else s_pct[z])
            append(
                f'<row r="{r}">'
                f'{_cell_str_xml(f"A{r}", s_txt_at[z], o["registro_ans"])}'
                f'{_cell_str_xml(f"B{r}", s_txt_at[z], o["cnpj"])}'
                f'{_cell_str_xml(f"C{r}", s_txt_l[z], o["razao_social"])}'
                f'{_cell_str_xml(f"D{r}", s_txt_l[z], o["nome_fantasia"])}'
                f'{_cell_str_xml(f"E{r}", s_txt_l[z], o["modalidade"])}'
                f'{_cell_str_xml(f"F{r}", s_txt_c[z], o["uf"])}'
                f'{_cell_str_xml(f"G{r}", s_txt_l[z], o["cidade"])}'
                f'{_cell_str_xml(f"H{r}", s_txt_c[z], o["status"])}'
                f'{_cell_str_xml(f"I{r}", s_txt_l[z], o["porte"])}'
                f'{_cell_num_xml(f"J{r}", s_int[z], o["trimestres"])}'
                f'{_cell_num_xml(f"K{r}", s_moeda[z], round(o["receitas"], 2))}'
                f'{_cell_num_xml(f"L{r}", s_moeda[z], round(o["despesas"], 2))}'
                f'{_cell_num_xml(f"M{r}", s_moeda[z], round(o["eventos_mh"], 2))}'
                f'{_cell_num_xml(f"N{r}", s_moeda[z], round(o["comercializacao"], 2))}'
                f'{_cell_num_xml(f"O{r}", s_moeda[z], round(o["administrativas"], 2))}'
                f'{_cell_formula_xml(f"P{r}", s_moeda[z], f"K{r}-L{r}-N{r}-O{r}", round(o["resultado"], 2))}'
                f'{_cell_formula_xml(f"Q{r}", sin_style, f"IF(K{r}>0,L{r}/K{r},0)", sin if sin is not None else 0)}'
                f'{_cell_formula_xml(f"R{r}", s_pct[z], f"IF(K{r}>0,(L{r}+N{r}+O{r})/K{r},0)", o["indice_combinado"] if o["indice_combinado"] is not None else 0)}'
                f'{_cell_num_xml(f"S{r}", s_int[z], o["benef_mh"])}'
                f'{_cell_num_xml(f"T{r}", s_int[z], o["benef_odonto"])}'
                f'{_cell_formula_xml(f"U{r}", s_moeda[z], f"IF(S{r}>0,M{r}/S{r},0)", round(o["ticket_medio"], 2) if o["ticket_medio"] is not None else 0)}'
                f'</row>'
            )

        # Linha TOTAL com fórmulas vivas
        r = total_row
        append(
            f'<row r="{r}" ht="22" customHeight="1">'
            f'{_cell_str_xml(f"A{r}", s_tot_l, "TOTAL")}'
            f'{_cell_str_xml(f"B{r}", s_tot_c, "")}'
            f'{_cell_str_xml(f"C{r}", s_tot_l, f"{len(ops)} operadora(s)")}'
            f'{_cell_str_xml(f"D{r}", s_tot_l, "")}{_cell_str_xml(f"E{r}", s_tot_l, "")}'
            f'{_cell_str_xml(f"F{r}", s_tot_c, "")}{_cell_str_xml(f"G{r}", s_tot_l, "")}'
            f'{_cell_str_xml(f"H{r}", s_tot_c, "")}{_cell_str_xml(f"I{r}", s_tot_l, "")}'
            f'{_cell_formula_xml(f"J{r}", s_tot_int, f"SUM(J{start}:J{end})")}'
            f'{_cell_formula_xml(f"K{r}", s_tot_moeda, f"SUM(K{start}:K{end})")}'
            f'{_cell_formula_xml(f"L{r}", s_tot_moeda, f"SUM(L{start}:L{end})")}'
            f'{_cell_formula_xml(f"M{r}", s_tot_moeda, f"SUM(M{start}:M{end})")}'
            f'{_cell_formula_xml(f"N{r}", s_tot_moeda, f"SUM(N{start}:N{end})")}'
            f'{_cell_formula_xml(f"O{r}", s_tot_moeda, f"SUM(O{start}:O{end})")}'
            f'{_cell_formula_xml(f"P{r}", s_tot_moeda, f"K{r}-L{r}-N{r}-O{r}")}'
            f'{_cell_formula_xml(f"Q{r}", s_tot_pct, f"IF(K{r}>0,L{r}/K{r},0)")}'
            f'{_cell_formula_xml(f"R{r}", s_tot_pct, f"IF(K{r}>0,(L{r}+N{r}+O{r})/K{r},0)")}'
            f'{_cell_formula_xml(f"S{r}", s_tot_int, f"SUM(S{start}:S{end})")}'
            f'{_cell_formula_xml(f"T{r}", s_tot_int, f"SUM(T{start}:T{end})")}'
            f'{_cell_formula_xml(f"U{r}", s_tot_moeda, f"IF(S{r}>0,M{r}/S{r},0)")}'
            f'</row>'
        )
        patches[nome_aba] = ("U", total_row, "".join(xml_rows).encode("utf-8"))

    @classmethod
    def _aba_contas_setor(
        cls,
        wb: Workbook,
        dados: Dict[str, Any],
        subtitulo: str,
        st: Dict[str, Any],
        reg: _StyleRegistry,
        patches: Dict[str, Tuple[str, int, bytes]],
    ) -> None:
        nome_aba = "Plano de Contas ANS"
        ws = wb.create_sheet(nome_aba)
        headers = [
            ("Ano", "c"),
            ("Trimestre", "c"),
            ("Período", "l"),
            ("Código Conta", "c"),
            ("Grupo Contábil", "l"),
            ("Nível", "c"),
            ("Descrição da Conta", "l"),
            ("Valor do Setor (R$)", "r"),
        ]
        head_row = cls._cabecalho_planilha(ws, "Base ETL · Plano de Contas do Setor (contas_setor)", subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"
        cls._ajustar_larguras(ws, [8, 10, 22, 14, 28, 8, 46, 22])

        contas = dados["contas_setor"]
        if not contas:
            return
        start = head_row + 1
        end = start + len(contas) - 1
        ws.auto_filter.ref = f"A{head_row}:H{end}"

        if len(contas) <= _STREAM_THRESHOLD:
            row = start
            for i, c in enumerate(contas):
                zebra = i % 2 == 1
                nivel = int(c["nivel"] or 0)
                vals = [
                    (int(c["ano"]), "c", "0"),
                    (int(c["trimestre"]), "c", "0"),
                    (_fmt_periodo(int(c["ano"]), int(c["trimestre"])), "l", None),
                    (str(c["codigo"]), "c", "@"),
                    (_grupo_conta(str(c["codigo"])), "l", None),
                    (nivel, "c", "0"),
                    (c["descricao"], "l", None),
                    (float(c["valor"] or 0), "r", FMT_MOEDA),
                ]
                for ci, (v, al, nf) in enumerate(vals, start=1):
                    cell = ws.cell(row=row, column=ci, value=v)
                    cell.font = st["data_bold"] if nivel == 0 else st["data_font"]
                    cell.border = st["border"]
                    cell.alignment = st[f"align_{al}"]
                    if zebra:
                        cell.fill = st["zebra_fill"]
                    if nf:
                        cell.number_format = nf
                row += 1
            return

        borda = st["border"] if len(contas) <= 6000 else None
        def _quad(al: str, nf: Optional[str] = None) -> Tuple[int, int, int, int]:
            # (normal, zebra, bold_normal, bold_zebra)
            return (
                reg.get(font=st["data_font"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_font"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_bold"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_bold"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
            )

        s_num_c = _quad("c", "0")
        s_txt_l = _quad("l")
        s_cod = _quad("c", "@")
        s_moeda = _quad("r", FMT_MOEDA)

        xml_rows: List[str] = []
        append = xml_rows.append
        for i, c in enumerate(contas):
            r = start + i
            nivel = int(c["nivel"] or 0)
            k = (2 if nivel == 0 else 0) + (i & 1)
            ano = int(c["ano"])
            tri = int(c["trimestre"])
            cod = str(c["codigo"])
            append(
                f'<row r="{r}">'
                f'{_cell_num_xml(f"A{r}", s_num_c[k], ano)}'
                f'{_cell_num_xml(f"B{r}", s_num_c[k], tri)}'
                f'{_cell_str_xml(f"C{r}", s_txt_l[k], f"{tri}º trimestre de {ano}")}'
                f'{_cell_str_xml(f"D{r}", s_cod[k], cod)}'
                f'{_cell_str_xml(f"E{r}", s_txt_l[k], _grupo_conta(cod))}'
                f'{_cell_num_xml(f"F{r}", s_num_c[k], nivel)}'
                f'{_cell_str_xml(f"G{r}", s_txt_l[k], c["descricao"])}'
                f'{_cell_num_xml(f"H{r}", s_moeda[k], round(float(c["valor"] or 0), 2))}'
                f'</row>'
            )
        patches[nome_aba] = ("H", end, "".join(xml_rows).encode("utf-8"))

    @classmethod
    def _aba_base_demonstracoes(
        cls,
        wb: Workbook,
        dados: Dict[str, Any],
        subtitulo: str,
        st: Dict[str, Any],
        reg: _StyleRegistry,
        patches: Dict[str, Tuple[str, int, bytes]],
    ) -> None:
        nome_aba = "Base ETL Demonstrações"
        ws = wb.create_sheet(nome_aba)
        headers = [
            ("Ano", "c"),
            ("Trimestre", "c"),
            ("Período", "l"),
            ("Registro ANS", "c"),
            ("CNPJ", "c"),
            ("Razão Social", "l"),
            ("Nome Fantasia", "l"),
            ("UF", "c"),
            ("Modalidade", "l"),
            ("Status", "c"),
            ("Contraprestações (R$)", "r"),
            ("Eventos Indenizáveis (R$)", "r"),
            ("Eventos MH (R$)", "r"),
            ("Comercialização (R$)", "r"),
            ("Administrativas (R$)", "r"),
            ("Sinistralidade (%)", "r"),
            ("Beneficiários MH", "r"),
            ("Beneficiários Odonto", "r"),
            ("Beneficiários Total", "r"),
            ("Lote Auditado", "c"),
        ]
        head_row = cls._cabecalho_planilha(
            ws,
            "Base Fato ETL · Demonstrações × Beneficiários (Pronta para Tabela Dinâmica)",
            subtitulo,
            len(headers),
            st,
        )
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"
        cls._ajustar_larguras(
            ws, [8, 10, 21, 13, 19, 34, 24, 6, 24, 10, 20, 20, 19, 18, 18, 14, 15, 15, 15, 13]
        )

        fatos = dados["_fatos_tuplas"]
        ops_map = dados["_ops_map"]
        if not fatos:
            return
        start = head_row + 1
        end = start + len(fatos) - 1
        ws.auto_filter.ref = f"A{head_row}:T{end}"

        if len(fatos) <= _STREAM_THRESHOLD:
            row = start
            for i, (ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, aud) in enumerate(fatos):
                op = ops_map[reg]
                vals = [
                    (ano, "c", "0"),
                    (tri, "c", "0"),
                    (_fmt_periodo(ano, tri), "l", None),
                    (reg, "c", "@"),
                    (_fmt_cnpj(op["cnpj"]), "c", "@"),
                    (op["razao_social"] or "", "l", None),
                    (op["nome_fantasia"] or "", "l", None),
                    (op["uf"] or "", "c", None),
                    (op["modalidade"] or "Não informada", "l", None),
                    (op["status"] or "", "c", None),
                    (rec, "r", FMT_MOEDA),
                    (ev, "r", FMT_MOEDA),
                    (ev_mh, "r", FMT_MOEDA),
                    (com, "r", FMT_MOEDA),
                    (adm, "r", FMT_MOEDA),
                    (f"=IF(K{row}>0,L{row}/K{row},0)", "r", FMT_PCT),
                    (bmh, "r", FMT_INT),
                    (bod, "r", FMT_INT),
                    (f"=Q{row}+R{row}", "r", FMT_INT),
                    ("Sim" if aud else "Não", "c", None),
                ]
                zebra = i % 2 == 1
                for ci, (v, al, nf) in enumerate(vals, start=1):
                    cell = ws.cell(row=row, column=ci, value=v)
                    cell.font = st["data_font"]
                    cell.border = st["border"]
                    cell.alignment = st[f"align_{al}"]
                    if zebra:
                        cell.fill = st["zebra_fill"]
                    if nf:
                        cell.number_format = nf
                row += 1
            return

        # OOXML streaming ultrarrápido com pré-escape por operadora (suporta 34.634+ linhas em < 1s)
        com_formula = len(fatos) <= 5000
        borda = st["border"] if len(fatos) <= 5000 else None
        def _pair(al: str, nf: Optional[str] = None) -> Tuple[int, int]:
            return (
                reg.get(font=st["data_font"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_font"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
            )

        s_num_c = _pair("c", "0")
        s_txt_l = _pair("l")
        s_txt_c = _pair("c")
        s_txt_at = _pair("c", "@")
        s_moeda = _pair("r", FMT_MOEDA)
        s_pct = _pair("r", FMT_PCT)
        s_int = _pair("r", FMT_INT)

        # Pré-escapa os 7 campos textuais uma única vez por operadora (~1.4k em vez de 242k vezes!)
        op_esc: Dict[str, Tuple[str, str, str, str, str, str, str]] = {}
        for r_ans, op in ops_map.items():
            op_esc[r_ans] = (
                _xml_str(r_ans),
                _xml_str(_fmt_cnpj(op["cnpj"])),
                _xml_str(op["razao_social"] or ""),
                _xml_str(op["nome_fantasia"] or ""),
                _xml_str(op["uf"] or ""),
                _xml_str(op["modalidade"] or "Não informada"),
                _xml_str(op["status"] or ""),
            )

        per_cache: Dict[Tuple[int, int], str] = {}
        xml_rows: List[str] = []
        append = xml_rows.append
        for i, (ano, tri, r_ans, rec, ev, ev_mh, com, adm, bmh, bod, aud) in enumerate(fatos):
            rn = start + i
            z = i & 1
            per = per_cache.get((ano, tri))
            if per is None:
                per = f"{tri}º trimestre de {ano}"
                per_cache[(ano, tri)] = per
            e_reg, e_cnpj, e_raz, e_fant, e_uf, e_mod, e_st = op_esc[r_ans]
            sin_v = (ev / rec) if rec > 0 else 0.0
            btot = bmh + bod
            sn = s_num_c[z]
            sl = s_txt_l[z]
            sc = s_txt_c[z]
            sa = s_txt_at[z]
            sm = s_moeda[z]
            sp = s_pct[z]
            si = s_int[z]

            if com_formula:
                c_p = f'<c r="P{rn}" s="{sp}"><f>IF(K{rn}&gt;0,L{rn}/K{rn},0)</f><v>{sin_v}</v></c>'
                c_s = f'<c r="S{rn}" s="{si}"><f>Q{rn}+R{rn}</f><v>{btot}</v></c>'
            else:
                c_p = f'<c r="P{rn}" s="{sp}"><v>{sin_v}</v></c>'
                c_s = f'<c r="S{rn}" s="{si}"><v>{btot}</v></c>'

            append(
                f'<row r="{rn}">'
                f'<c r="A{rn}" s="{sn}"><v>{ano}</v></c>'
                f'<c r="B{rn}" s="{sn}"><v>{tri}</v></c>'
                f'<c r="C{rn}" t="inlineStr" s="{sl}"><is><t>{per}</t></is></c>'
                f'<c r="D{rn}" t="inlineStr" s="{sa}"><is><t>{e_reg}</t></is></c>'
                f'<c r="E{rn}" t="inlineStr" s="{sa}"><is><t>{e_cnpj}</t></is></c>'
                f'<c r="F{rn}" t="inlineStr" s="{sl}"><is><t>{e_raz}</t></is></c>'
                f'<c r="G{rn}" t="inlineStr" s="{sl}"><is><t>{e_fant}</t></is></c>'
                f'<c r="H{rn}" t="inlineStr" s="{sc}"><is><t>{e_uf}</t></is></c>'
                f'<c r="I{rn}" t="inlineStr" s="{sl}"><is><t>{e_mod}</t></is></c>'
                f'<c r="J{rn}" t="inlineStr" s="{sc}"><is><t>{e_st}</t></is></c>'
                f'<c r="K{rn}" s="{sm}"><v>{rec}</v></c>'
                f'<c r="L{rn}" s="{sm}"><v>{ev}</v></c>'
                f'<c r="M{rn}" s="{sm}"><v>{ev_mh}</v></c>'
                f'<c r="N{rn}" s="{sm}"><v>{com}</v></c>'
                f'<c r="O{rn}" s="{sm}"><v>{adm}</v></c>'
                f'{c_p}'
                f'<c r="Q{rn}" s="{si}"><v>{bmh}</v></c>'
                f'<c r="R{rn}" s="{si}"><v>{bod}</v></c>'
                f'{c_s}'
                f'<c r="T{rn}" t="inlineStr" s="{sc}"><is><t>{"Sim" if aud else "Não"}</t></is></c>'
                f'</row>'
            )
        patches[nome_aba] = ("T", end, "".join(xml_rows).encode("utf-8"))

    @classmethod
    def _aba_lotes(
        cls, wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any], fmt_data: str
    ) -> None:
        ws = wb.create_sheet("Lotes ETL")
        headers = [
            ("Ano", "c"),
            ("Trimestre", "c"),
            ("Período", "l"),
            ("Registros Extraídos", "r"),
            ("Operadoras c/ Demonstração", "r"),
            ("Carregado em", "c"),
            ("Auditado", "c"),
            ("Auditado por", "l"),
            ("Auditado em", "c"),
        ]
        head_row = cls._cabecalho_planilha(ws, "Base ETL · Rastreabilidade e Auditoria de Lotes (lotes_etl)", subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"

        lotes = dados["lotes_etl"]
        start = head_row + 1
        row = start
        for i, l in enumerate(lotes):
            ws.row_dimensions[row].height = 20
            aud = bool(l.get("auditado"))
            vals = [
                (int(l["ano"]), "c", "0"),
                (int(l["trimestre"]), "c", "0"),
                (_fmt_periodo(int(l["ano"]), int(l["trimestre"])), "l", None),
                (int(l.get("registros_extraidos") or 0), "r", FMT_INT),
                (int(l.get("operadoras") or 0), "r", FMT_INT),
                (_fmt_data(l.get("carregado_em"), formato=fmt_data, hora=True), "c", None),
                ("Auditado" if aud else "Pendente", "c", None),
                (l.get("auditado_por") or "—", "l", None),
                (_fmt_data(l.get("auditado_em"), formato=fmt_data, hora=True) or "—", "c", None),
            ]
            for ci, (v, al, nf) in enumerate(vals, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["data_font"]
                cell.border = st["border"]
                cell.alignment = st[f"align_{al}"]
                if i % 2 == 1:
                    cell.fill = st["zebra_fill"]
                if nf:
                    cell.number_format = nf
            c_aud = ws.cell(row=row, column=7)
            c_aud.fill = st["ok_fill"] if aud else st["zebra_fill"]
            c_aud.font = st["ok_font"] if aud else st["muted_font"]
            row += 1

        if lotes:
            end = row - 1
            ws.row_dimensions[row].height = 22
            totais = [
                ("TOTAL", "l", None),
                ("", "c", None),
                (f"{len(lotes)} lote(s)", "l", None),
                (f"=SUM(D{start}:D{end})", "r", FMT_INT),
                (f"=AVERAGE(E{start}:E{end})", "r", FMT_INT),
                ("", "c", None),
                (f"{sum(1 for l in lotes if bool(l.get('auditado')))}/{len(lotes)}", "c", None),
                ("", "l", None),
                ("", "c", None),
            ]
            for ci, (v, al, nf) in enumerate(totais, start=1):
                cell = ws.cell(row=row, column=ci, value=v)
                cell.font = st["total_font"]
                cell.fill = st["total_fill"]
                cell.border = st["total_border"]
                cell.alignment = st[f"align_{al}"]
                if nf:
                    cell.number_format = nf
            ws.auto_filter.ref = f"A{head_row}:I{end}"

        cls._ajustar_larguras(ws, [8, 10, 22, 20, 24, 19, 13, 24, 19])

    @classmethod
    def _aba_cadastro(
        cls,
        wb: Workbook,
        dados: Dict[str, Any],
        subtitulo: str,
        st: Dict[str, Any],
        fmt_data: str,
        reg: _StyleRegistry,
        patches: Dict[str, Tuple[str, int, bytes]],
    ) -> None:
        nome_aba = "Cadastro Operadoras"
        ws = wb.create_sheet(nome_aba)
        headers = [
            ("Registro ANS", "c"),
            ("CNPJ", "c"),
            ("Razão Social", "l"),
            ("Nome Fantasia", "l"),
            ("Modalidade", "l"),
            ("Status", "c"),
            ("UF", "c"),
            ("Cidade", "l"),
            ("Beneficiários Total (CADOP)", "r"),
            ("Beneficiários MH (CADOP)", "r"),
            ("Descredenciamento", "c"),
            ("Representante", "l"),
            ("E-mail", "l"),
            ("Telefone", "l"),
        ]
        head_row = cls._cabecalho_planilha(ws, "Base ETL · Cadastro CADOP de Operadoras (operadoras)", subtitulo, len(headers), st)
        cls._escrever_headers(ws, head_row, headers, st)
        ws.freeze_panes = f"A{head_row + 1}"
        cls._ajustar_larguras(ws, [13, 19, 34, 24, 24, 11, 6, 18, 22, 20, 16, 26, 28, 18])

        cad = dados["cadastro_operadoras"]
        if not cad:
            return
        start = head_row + 1
        end = start + len(cad) - 1
        ws.auto_filter.ref = f"A{head_row}:N{end}"

        if len(cad) <= _STREAM_THRESHOLD:
            row = start
            for i, o in enumerate(cad):
                zebra = i % 2 == 1
                vals = [
                    (o["registro_ans"], "c", "@"),
                    (_fmt_cnpj(o["cnpj"]), "c", "@"),
                    (o["razao_social"] or "", "l", None),
                    (o["nome_fantasia"] or "", "l", None),
                    (o["modalidade"] or "Não informada", "l", None),
                    (o["status"] or "", "c", None),
                    (o["uf"] or "", "c", None),
                    (o["cidade"] or "", "l", None),
                    (int(o.get("beneficiarios") or 0), "r", FMT_INT),
                    (int(o.get("beneficiarios_mh") or 0), "r", FMT_INT),
                    (_fmt_data(o.get("data_descredenciamento"), formato=fmt_data) or "", "c", None),
                    (o.get("representante") or "", "l", None),
                    (o.get("email") or "", "l", None),
                    (o.get("telefone") or "", "l", None),
                ]
                for ci, (v, al, nf) in enumerate(vals, start=1):
                    cell = ws.cell(row=row, column=ci, value=v)
                    cell.font = st["data_font"]
                    cell.border = st["border"]
                    cell.alignment = st[f"align_{al}"]
                    if zebra:
                        cell.fill = st["zebra_fill"]
                    if nf:
                        cell.number_format = nf
                row += 1
            return

        borda = st["border"] if len(cad) <= 5000 else None
        def _pair(al: str, nf: Optional[str] = None) -> Tuple[int, int]:
            return (
                reg.get(font=st["data_font"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
                reg.get(font=st["data_font"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
            )

        s_txt_l = _pair("l")
        s_txt_c = _pair("c")
        s_txt_at = _pair("c", "@")
        s_int = _pair("r", FMT_INT)

        xml_rows: List[str] = []
        append = xml_rows.append
        for i, o in enumerate(cad):
            r = start + i
            z = i & 1
            append(
                f'<row r="{r}">'
                f'{_cell_str_xml(f"A{r}", s_txt_at[z], o["registro_ans"])}'
                f'{_cell_str_xml(f"B{r}", s_txt_at[z], _fmt_cnpj(o["cnpj"]))}'
                f'{_cell_str_xml(f"C{r}", s_txt_l[z], o["razao_social"] or "")}'
                f'{_cell_str_xml(f"D{r}", s_txt_l[z], o["nome_fantasia"] or "")}'
                f'{_cell_str_xml(f"E{r}", s_txt_l[z], o["modalidade"] or "Não informada")}'
                f'{_cell_str_xml(f"F{r}", s_txt_c[z], o["status"] or "")}'
                f'{_cell_str_xml(f"G{r}", s_txt_c[z], o["uf"] or "")}'
                f'{_cell_str_xml(f"H{r}", s_txt_l[z], o["cidade"] or "")}'
                f'{_cell_num_xml(f"I{r}", s_int[z], int(o.get("beneficiarios") or 0))}'
                f'{_cell_num_xml(f"J{r}", s_int[z], int(o.get("beneficiarios_mh") or 0))}'
                f'{_cell_str_xml(f"K{r}", s_txt_c[z], _fmt_data(o.get("data_descredenciamento"), formato=fmt_data) or "")}'
                f'{_cell_str_xml(f"L{r}", s_txt_l[z], o.get("representante") or "")}'
                f'{_cell_str_xml(f"M{r}", s_txt_l[z], o.get("email") or "")}'
                f'{_cell_str_xml(f"N{r}", s_txt_l[z], o.get("telefone") or "")}'
                f'</row>'
            )
        patches[nome_aba] = ("N", end, "".join(xml_rows).encode("utf-8"))

    # ------------------------------------------------------------------ CSV & JSON (PDF)
    @classmethod
    def gerar_tabelas_estruturadas(
        cls, payload: Dict[str, Any], usuario_nome: str = "", limite_linhas_brutas: Optional[int] = None
    ) -> Dict[str, Any]:
        """Monta tabelas padronizadas para CSV multi-seção e geração de PDF."""
        dados = cls.coletar_dados(payload, usuario_nome=usuario_nome)
        cfg = dados["cfg"]
        secoes = cfg["secoes"]
        fmt_data = cfg["formato_data"]
        k = dados["kpis"]
        abas: List[Dict[str, Any]] = []

        def n2(v: Optional[float]) -> str:
            return "" if v is None else f"{v:.2f}"

        def pct(v: Optional[float]) -> str:
            return "" if v is None else f"{v * 100:.2f}%"

        if "resumo" in secoes:
            abas.append(
                {
                    "titulo": "Resumo Executivo",
                    "subtitulo": dados["recorte"],
                    "colunas": ["Indicador", "Valor", "Base ETL"],
                    "linhas": [
                        ["Operadoras no recorte", str(k["operadoras"]), "operadoras × demonstracoes_operadora"],
                        ["Receitas / Contraprestações (R$)", n2(k["receitas"]), "demonstracoes_operadora.contraprestacoes"],
                        ["Despesas / Eventos Líquidos (R$)", n2(k["despesas"]), "demonstracoes_operadora.eventos"],
                        ["Eventos Médico-Hospitalares (R$)", n2(k["eventos_mh"]), "demonstracoes_operadora.eventos_mh"],
                        ["Comercialização (R$)", n2(k["comercializacao"]), "demonstracoes_operadora.comercializacao"],
                        ["Administrativas (R$)", n2(k["administrativas"]), "demonstracoes_operadora.administrativas"],
                        ["Resultado Operacional (R$)", n2(k["resultado"]), "Contraprestações - Despesas Totais"],
                        ["Sinistralidade Consolidada", pct(k["sinistralidade"]), "Eventos / Contraprestações"],
                        ["Índice Combinado", pct(k["indice_combinado"]), "(Eventos + Comerc. + Admin.) / Receitas"],
                        ["Beneficiários MH", str(k["benef_mh"]), "beneficiarios_trimestre.medico_hospitalar"],
                        ["Beneficiários Odontológicos", str(k["benef_odonto"]), "beneficiarios_trimestre.odontologico"],
                        ["Ticket Médio MH (R$)", n2(k["ticket_medio"]), "Eventos MH / Beneficiários MH"],
                        ["Lotes ETL no recorte", f"{k['lotes_total']} ({k['lotes_auditados']} auditados)", "lotes_etl"],
                    ],
                }
            )

        if "evolucao" in secoes:
            abas.append(
                {
                    "titulo": "Evolução no Período",
                    "subtitulo": dados["recorte"],
                    "colunas": [
                        "Período", "Operadoras", "Receitas (R$)", "Despesas (R$)", "Eventos MH (R$)",
                        "Comercialização (R$)", "Administrativas (R$)", "Resultado (R$)", "Sinistralidade", "Benef. MH",
                    ],
                    "linhas": [
                        [
                            p["periodo"], str(p["operadoras"]), n2(p["receitas"]), n2(p["despesas"]),
                            n2(p["eventos_mh"]), n2(p["comercializacao"]), n2(p["administrativas"]),
                            n2(p["resultado"]), pct(p["sinistralidade"]), str(p["benef_mh"]),
                        ]
                        for p in dados["serie"]
                    ],
                }
            )

        if "modalidades" in secoes:
            abas.append(
                {
                    "titulo": "Por Modalidade",
                    "subtitulo": dados["recorte"],
                    "colunas": [
                        "Modalidade", "Operadoras", "Receitas (R$)", "Despesas (R$)",
                        "Resultado (R$)", "Sinistralidade", "Partic.", "Benef. MH",
                    ],
                    "linhas": [
                        [
                            m["modalidade"], str(m["operadoras"]), n2(m["receitas"]), n2(m["despesas"]),
                            n2(m["resultado"]), pct(m["sinistralidade"]), pct(m["participacao"]), str(m["benef_mh"]),
                        ]
                        for m in dados["por_modalidade"]
                    ],
                }
            )

        if "ufs" in secoes:
            abas.append(
                {
                    "titulo": "Por UF",
                    "subtitulo": dados["recorte"],
                    "colunas": [
                        "UF", "Operadoras", "Receitas (R$)", "Despesas (R$)",
                        "Sinistralidade", "Partic.", "Benef. MH", "Ticket Médio MH (R$)",
                    ],
                    "linhas": [
                        [
                            u["uf"], str(u["operadoras"]), n2(u["receitas"]), n2(u["despesas"]),
                            pct(u["sinistralidade"]), pct(u["participacao"]), str(u["benef_mh"]), n2(u["ticket_medio"]),
                        ]
                        for u in dados["por_uf"]
                    ],
                }
            )

        if "operadoras" in secoes:
            ops = dados["operadoras"]
            nota_op = f"{dados['recorte']} · Ordenado por {cfg['ordenar_por']}"
            if limite_linhas_brutas is not None and len(ops) > limite_linhas_brutas:
                nota_op = f"{nota_op} · Exibindo as {limite_linhas_brutas} primeiras no PDF"
                ops = ops[:limite_linhas_brutas]
            abas.append(
                {
                    "titulo": "Ranking de Operadoras",
                    "subtitulo": nota_op,
                    "colunas": [
                        "Reg. ANS", "CNPJ", "Operadora", "UF", "Modalidade",
                        "Receitas (R$)", "Despesas (R$)", "Resultado (R$)", "Sinistralidade", "Benef. MH",
                    ],
                    "linhas": [
                        [
                            o["registro_ans"], o["cnpj"], o["nome_fantasia"], o["uf"], o["modalidade"],
                            n2(o["receitas"]), n2(o["despesas"]), n2(o["resultado"]),
                            pct(o["sinistralidade"]), str(o["benef_mh"]),
                        ]
                        for o in ops
                    ],
                }
            )

        if "contas_setor" in secoes:
            contas = dados["contas_setor"]
            nota_c = dados["recorte"]
            if limite_linhas_brutas is not None:
                filtradas = [c for c in contas if int(c["nivel"] or 0) <= 2]
                if len(filtradas) > limite_linhas_brutas:
                    nota_c = f"{nota_c} · Exibindo {limite_linhas_brutas} contas sintéticas no PDF (baixe XLSX/CSV para o plano completo)"
                contas = filtradas[:limite_linhas_brutas]
            abas.append(
                {
                    "titulo": "Plano de Contas ANS (ETL)",
                    "subtitulo": nota_c,
                    "colunas": ["Período", "Código", "Grupo", "Nível", "Descrição", "Valor (R$)"],
                    "linhas": [
                        [
                            _fmt_periodo(int(c["ano"]), int(c["trimestre"])),
                            str(c["codigo"]),
                            _grupo_conta(str(c["codigo"])),
                            str(c["nivel"]),
                            str(c["descricao"]),
                            n2(float(c["valor"] or 0)),
                        ]
                        for c in contas
                    ],
                }
            )

        if "base_demonstracoes" in secoes:
            base = dados["base_demonstracoes"]
            nota = dados["recorte"]
            if limite_linhas_brutas is not None and len(base) > limite_linhas_brutas:
                nota = f"{nota} · Exibindo os {limite_linhas_brutas} maiores registros no PDF (baixe XLSX/CSV para a base integral)"
                base = base[:limite_linhas_brutas]
            abas.append(
                {
                    "titulo": "Base ETL · Demonstrações",
                    "subtitulo": nota,
                    "colunas": [
                        "Período", "Reg. ANS", "Operadora", "UF", "Contraprestações (R$)",
                        "Eventos (R$)", "Eventos MH (R$)", "Comercializ. (R$)", "Admin. (R$)", "Benef. MH",
                    ],
                    "linhas": [
                        [
                            _fmt_periodo(int(r["ano"]), int(r["trimestre"])),
                            str(r["reg_ans"]),
                            r["nome_fantasia"] or r["razao_social"] or "",
                            r["uf"] or "",
                            n2(float(r["contraprestacoes"] or 0)),
                            n2(float(r["eventos"] or 0)),
                            n2(float(r["eventos_mh"] or 0)),
                            n2(float(r["comercializacao"] or 0)),
                            n2(float(r["administrativas"] or 0)),
                            str(int(r["benef_mh"] or 0)),
                        ]
                        for r in base
                    ],
                }
            )

        if "lotes_cadastro" in secoes:
            abas.append(
                {
                    "titulo": "Base ETL · Lotes Extraídos",
                    "subtitulo": dados["recorte"],
                    "colunas": ["Período", "Registros Extraídos", "Operadoras", "Carregado em", "Auditado", "Auditado por"],
                    "linhas": [
                        [
                            _fmt_periodo(int(l["ano"]), int(l["trimestre"])),
                            str(int(l.get("registros_extraidos") or 0)),
                            str(int(l.get("operadoras") or 0)),
                            _fmt_data(l.get("carregado_em"), formato=fmt_data, hora=True),
                            "Auditado" if bool(l.get("auditado")) else "Pendente",
                            str(l.get("auditado_por") or "—"),
                        ]
                        for l in dados["lotes_etl"]
                    ],
                }
            )
            cad = dados["cadastro_operadoras"]
            nota_cad = f"{len(cad)} operadora(s) no cadastro CADOP"
            if limite_linhas_brutas is not None and len(cad) > limite_linhas_brutas:
                nota_cad = f"{nota_cad} · Exibindo as {limite_linhas_brutas} maiores no PDF (baixe XLSX/CSV para o cadastro completo)"
                cad = cad[:limite_linhas_brutas]
            abas.append(
                {
                    "titulo": "Base ETL · Cadastro CADOP",
                    "subtitulo": nota_cad,
                    "colunas": ["Reg. ANS", "CNPJ", "Razão Social", "Modalidade", "Status", "UF", "Beneficiários"],
                    "linhas": [
                        [
                            str(o["registro_ans"]),
                            _fmt_cnpj(o["cnpj"]),
                            str(o["razao_social"] or ""),
                            str(o["modalidade"] or "Não informada"),
                            str(o["status"] or ""),
                            str(o["uf"] or ""),
                            str(int(o.get("beneficiarios") or 0)),
                        ]
                        for o in cad
                    ],
                }
            )

        anos = cfg["anos"]
        sufixo = str(anos[0]) if len(anos) == 1 else f"{anos[0]}_{anos[-1]}"
        return {
            "titulo_geral": "Relatório Analítico ANS · Intuitive Care",
            "subtitulo_geral": dados["recorte"],
            "nome_base": f"relatorio_etl_ans_{sufixo}",
            "abas": abas,
        }

    @classmethod
    def gerar_csv(cls, payload: Dict[str, Any], usuario_nome: str = "") -> Tuple[bytes, str]:
        estruturado = cls.gerar_tabelas_estruturadas(payload, usuario_nome=usuario_nome)

        def esc(v: str) -> str:
            if any(ch in v for ch in (";", '"', "\n", "\r")):
                return '"' + v.replace('"', '""') + '"'
            return v

        out = StringIO()
        out.write("\ufeff")
        out.write(esc(estruturado["titulo_geral"]) + "\n")
        out.write(esc(estruturado["subtitulo_geral"]) + "\n")
        for aba in estruturado["abas"]:
            out.write("\n")
            out.write(esc(aba["titulo"]) + "\n")
            if aba.get("subtitulo"):
                out.write(esc(aba["subtitulo"]) + "\n")
            out.write(";".join(esc(c) for c in aba["colunas"]) + "\n")
            for linha in aba["linhas"]:
                out.write(";".join(esc(str(v)) for v in linha) + "\n")
        return out.getvalue().encode("utf-8"), f"{estruturado['nome_base']}.csv"
