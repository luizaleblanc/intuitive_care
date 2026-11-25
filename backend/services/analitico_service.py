from datetime import date, datetime
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

from backend.database.cache import invalidar_cache, obter_ou_carregar
from backend.repositories.analitico_repository import AnaliticoRepository
from backend.services.validators import BusinessRuleError

Periodo = Tuple[int, int]

GRUPOS_CONTAS = {
    "41": "Eventos indenizáveis",
    "43": "Despesas de comercialização",
    "46": "Despesas administrativas",
    "31": "Receitas de contraprestações",
}

FORMAS_PAGAMENTO = {
    "41111": "Por procedimento",
    "41121": "Capitation",
    "41131": "Orçamento global",
    "41141": "Pacote",
    "41151": "Rateio de recursos próprios",
    "41161": "Rede indireta",
    "41171": "Reembolso",
    "41181": "Sistema Único de Saúde (SUS)",
    "41191": "Outras formas",
}


def _p(periodo: Periodo) -> Dict[str, int]:
    return {"ano": periodo[0], "trimestre": periodo[1]}


def _anterior(periodo: Periodo) -> Periodo:
    ano, tri = periodo
    return (ano, tri - 1) if tri > 1 else (ano - 1, 4)


def _iso(valor: Any) -> Optional[str]:
    if isinstance(valor, (date, datetime)):
        return valor.isoformat()
    return str(valor) if valor else None


def _norm_ints(unico: Optional[int], multiplos: Optional[Sequence[int]]) -> List[int]:
    if multiplos:
        return list(dict.fromkeys(int(x) for x in multiplos))
    return [int(unico)] if unico is not None else []


def _norm_strs(unico: Union[str, Sequence[str], None], multiplos: Optional[Sequence[str]] = None) -> List[str]:
    if multiplos:
        return [s.strip() for s in multiplos if str(s).strip()]
    if isinstance(unico, str):
        return [s.strip() for s in unico.split(",") if s.strip()]
    if unico:
        return [str(s).strip() for s in unico if str(s).strip()]
    return []


def _resolver_periodos(
    anos: Sequence[int], trimestres: Sequence[int]
) -> Tuple[List[Periodo], List[Periodo], List[Periodo]]:
    periodos = obter_ou_carregar("analitico:periodos", AnaliticoRepository.periodos)
    if not periodos:
        raise BusinessRuleError("Nenhuma demonstração contábil carregada. Execute o ETL.", 404)
    if not anos and not trimestres:
        selecionados = [periodos[0]]
    else:
        anos_set = set(anos)
        tris_set = set(trimestres)
        selecionados = [
            p for p in periodos
            if (not anos_set or p[0] in anos_set) and (not tris_set or p[1] in tris_set)
        ]
        if not selecionados:
            raise BusinessRuleError("Não há dados da ANS para o período selecionado.", 404)
        if not anos_set:
            ano_recente = selecionados[0][0]
            selecionados = [p for p in selecionados if p[0] == ano_recente]

    if len(selecionados) == 1:
        anteriores = [_anterior(selecionados[0])]
    else:
        anos_sel = [a for a, _ in selecionados]
        span = max(anos_sel) - min(anos_sel) + 1
        disponiveis = set(periodos)
        anteriores = [(a - span, t) for a, t in selecionados if (a - span, t) in disponiveis]
    return selecionados, anteriores, periodos


def _resumir_lotes(lotes: List[Dict[str, Any]], selecionados: List[Periodo]) -> Dict[str, Any]:
    if len(selecionados) == 1:
        lote = lotes[0] if lotes else {}
        return {
            "registros_extraidos": int(lote.get("registros_extraidos") or 0),
            "operadoras": int(lote.get("operadoras") or 0),
            "carregado_em": _iso(lote.get("carregado_em")),
            "auditado": bool(lote.get("auditado")),
            "auditado_por": lote.get("auditado_por"),
            "auditado_em": _iso(lote.get("auditado_em")),
        }
    return {
        "registros_extraidos": sum(int(l.get("registros_extraidos") or 0) for l in lotes),
        "operadoras": max((int(l.get("operadoras") or 0) for l in lotes), default=0),
        "carregado_em": None,
        "auditado": bool(lotes) and len(lotes) == len(selecionados) and all(bool(l.get("auditado")) for l in lotes),
        "auditado_por": None,
        "auditado_em": None,
    }


def _stub_admin() -> Dict[str, Any]:
    return {
        "total_despesas": 0.0,
        "total_despesas_anterior": None,
        "registros_extraidos": 0,
        "registros_extraidos_anterior": None,
        "operadoras_ativas": 0,
        "operadoras_com_demonstracao": 0,
        "serie": [],
        "modalidades": [],
    }


def _stub_colaborador() -> Dict[str, Any]:
    return {
        "despesas_mh": 0.0,
        "despesas_mh_anterior": None,
        "sinistralidade": None,
        "sinistralidade_anterior": None,
        "beneficiarios": 0,
        "beneficiarios_anterior": None,
        "ticket_medio": None,
        "ticket_medio_anterior": None,
        "ranking": [],
        "serie": [],
    }


class AnaliticoService:
    """Indicadores do Painel e do plano de contas calculados a partir dos dados reais da ANS."""

    @staticmethod
    def painel(
        ano: Optional[int] = None,
        trimestre: Optional[int] = None,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
        anos: Optional[Sequence[int]] = None,
        trimestres: Optional[Sequence[int]] = None,
        escopo: str = "",
    ) -> Dict[str, Any]:
        anos_sel = _norm_ints(ano, anos)
        tris_sel = _norm_ints(trimestre, trimestres)
        ufs = [u.upper() for u in _norm_strs(uf)]
        modalidades = _norm_strs(modalidade)
        escopo_norm = escopo if escopo in ("admin", "colaborador") else ""

        selecionados, anteriores, periodos = _resolver_periodos(anos_sel, tris_sel)
        periodo = selecionados[0]
        anterior_ref = anteriores[0] if anteriores else _anterior(periodo)
        repo = AnaliticoRepository

        if escopo_norm != "colaborador":
            atual, ant = repo.totais_comparados(selecionados, anteriores)
            sel_set = set(selecionados)
            todos_lotes = repo.lotes(selecionados + (anteriores or []))
            reg_atual = sum(int(l.get("registros_extraidos") or 0) for l in todos_lotes if (int(l["ano"]), int(l["trimestre"])) in sel_set)
            reg_ant = sum(int(l.get("registros_extraidos") or 0) for l in todos_lotes if (int(l["ano"]), int(l["trimestre"])) not in sel_set)
            modalidades_dist = repo.por_modalidade(selecionados)
            total_mod = sum(m["valor"] for m in modalidades_dist) or 1
            admin = {
                "total_despesas": atual["eventos"],
                "total_despesas_anterior": ant["eventos"] or None,
                "registros_extraidos": reg_atual,
                "registros_extraidos_anterior": reg_ant or None,
                "operadoras_ativas": repo.operadoras_ativas(),
                "operadoras_com_demonstracao": int(atual["operadoras"]),
                "serie": repo.serie("eventos", ate=periodo, selecionados=selecionados),
                "modalidades": [
                    {**m, "pct": round(m["valor"] / total_mod * 100, 1)} for m in modalidades_dist
                ],
            }
        else:
            admin = _stub_admin()

        if escopo_norm != "admin":
            c_atual, c_ant = repo.totais_comparados(selecionados, anteriores, ufs, modalidades)
            sin, sin_ant = repo.sinistralidades_comparadas(selecionados, anteriores, ufs, modalidades)
            base_benef, base_benef_ant = repo.beneficiarios_despesa_comparados(selecionados, anteriores, ufs, modalidades)
            benef_atual, benef_ant = repo.beneficiarios_comparados(
                periodo, anterior_ref if anteriores else None, ufs, modalidades
            )
            colaborador = {
                "despesas_mh": c_atual["eventos_mh"],
                "despesas_mh_anterior": c_ant["eventos_mh"] or None,
                "sinistralidade": sin,
                "sinistralidade_anterior": sin_ant,
                "beneficiarios": benef_atual,
                "beneficiarios_anterior": (benef_ant or None) if anteriores else None,
                "ticket_medio": (c_atual["eventos_mh"] / base_benef) if base_benef else None,
                "ticket_medio_anterior": (c_ant["eventos_mh"] / base_benef_ant) if base_benef_ant else None,
                "ranking": repo.ranking(selecionados, ufs, modalidades),
                "serie": repo.serie("eventos_mh", ate=periodo, uf=ufs, modalidade=modalidades, selecionados=selecionados),
            }
        else:
            colaborador = _stub_colaborador()

        return {
            "periodo": _p(periodo),
            "periodo_anterior": _p(anterior_ref),
            "periodos": [_p(p) for p in periodos],
            "periodos_selecionados": [_p(p) for p in selecionados],
            "admin": admin,
            "colaborador": colaborador,
        }

    @staticmethod
    def contas(
        ano: Optional[int] = None,
        trimestre: Optional[int] = None,
        grupo: Union[str, Sequence[str]] = "",
        anos: Optional[Sequence[int]] = None,
        trimestres: Optional[Sequence[int]] = None,
        grupos: Optional[Sequence[str]] = None,
    ) -> Dict[str, Any]:
        anos_sel = _norm_ints(ano, anos)
        tris_sel = _norm_ints(trimestre, trimestres)
        grupos_sel = _norm_strs(grupo, grupos)
        for g in grupos_sel:
            if g not in GRUPOS_CONTAS:
                raise BusinessRuleError("Grupo de contas inválido.", 400)
        prefixos = grupos_sel if grupos_sel else list(GRUPOS_CONTAS)

        selecionados, anteriores, periodos = _resolver_periodos(anos_sel, tris_sel)
        periodo = selecionados[0]
        anterior_ref = anteriores[0] if anteriores else _anterior(periodo)

        repo = AnaliticoRepository
        atuais, anteriores_map, kpi_atual, kpi_ant = repo.contas_comparadas(
            selecionados, anteriores, prefixos, incluir_kpis=True
        )

        linhas = []
        for codigo, conta in atuais.items():
            ant = anteriores_map.get(codigo)
            linhas.append(
                {
                    "codigo": codigo,
                    "descricao": conta["descricao"],
                    "grupo": GRUPOS_CONTAS[codigo[:2]],
                    "nivel": int(conta["nivel"]),
                    "valor_atual": conta["valor"],
                    "valor_anterior": ant["valor"] if ant else None,
                }
            )

        kpis = {
            c: {
                "valor_atual": kpi_atual.get(c, 0.0),
                "valor_anterior": kpi_ant.get(c) if c in kpi_ant else None,
            }
            for c in ("41", "46", "43")
        }

        comp = repo.composicao_mh(selecionados)
        total_comp = sum(v for v in comp.values() if v > 0) or 1
        composicao = sorted(
            (
                {"codigo": c, "forma": FORMAS_PAGAMENTO[c], "valor": v, "pct": round(v / total_comp * 100, 1)}
                for c, v in comp.items()
                if v > 0
            ),
            key=lambda x: -x["valor"],
        )

        destaques = []
        variaveis = [
            l for l in linhas
            if l["nivel"] <= 2 and l["valor_anterior"] and abs(l["valor_anterior"]) > 1e8
        ]
        variaveis.sort(key=lambda l: -abs((l["valor_atual"] - l["valor_anterior"]) / abs(l["valor_anterior"])))
        for l in variaveis:
            # Evita repetir conta-pai e subconta com o mesmo movimento (ex.: 312 e 3121).
            if any(l["codigo"].startswith(d["codigo"]) or d["codigo"].startswith(l["codigo"]) for d in destaques):
                continue
            var = (l["valor_atual"] - l["valor_anterior"]) / abs(l["valor_anterior"]) * 100
            destaques.append({"codigo": l["codigo"], "descricao": l["descricao"], "variacao": round(var, 1)})
            if len(destaques) == 3:
                break

        lotes_atual = repo.lotes(selecionados)
        return {
            "periodo": _p(periodo),
            "periodo_anterior": _p(anterior_ref),
            "periodos": [_p(p) for p in periodos],
            "periodos_selecionados": [_p(p) for p in selecionados],
            "grupos": [{"codigo": k, "nome": v} for k, v in GRUPOS_CONTAS.items()],
            "kpis": kpis,
            "contas": linhas,
            "composicao": composicao,
            "destaques": destaques,
            "lote": _resumir_lotes(lotes_atual, selecionados),
        }

    @staticmethod
    def auditar_lote(ano: int, trimestre: int, usuario: str) -> Dict[str, Any]:
        if not AnaliticoRepository.auditar_lote((ano, trimestre), usuario):
            raise BusinessRuleError("Lote não encontrado para o período informado.", 404)
        invalidar_cache("explorar:", "analitico:")
        return {"mensagem": f"Lote do {trimestre}º trimestre de {ano} marcado como auditado."}
