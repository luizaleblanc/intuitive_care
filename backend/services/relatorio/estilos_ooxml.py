"""Estilos openpyxl, registro para streaming OOXML e helpers comuns de formatação de abas."""
from copy import copy
from io import BytesIO
import re
from typing import Any, Callable, Dict, Optional, Sequence, Tuple
import xml.etree.ElementTree as ET
import zipfile

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

from backend.services.relatorio.constantes import (
    COR_BORDA,
    COR_ERR_BG,
    COR_ERR_FG,
    COR_FOREST,
    COR_MUTED,
    COR_OK_BG,
    COR_OK_FG,
    COR_SAGE,
    COR_TEXTO,
    COR_ZEBRA,
)

# Remove caracteres de controle ilegais no XML 1.0 (mesma regra do openpyxl)
_XML_ILLEGAL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_DIM_RE = re.compile(rb'<dimension ref="[^"]*"')
_NS_MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
_NS_REL_ATTR = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
_NS_PKG_REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"


def criar_estilos() -> Dict[str, Any]:
    thin = Side(style="thin", color=COR_BORDA)
    med_forest = Side(style="medium", color=COR_FOREST)
    double_forest = Side(style="double", color=COR_FOREST)
    return {
        "banner_fill": PatternFill("solid", fgColor=COR_FOREST),
        "sub_fill": PatternFill("solid", fgColor=COR_SAGE),
        "head_fill": PatternFill("solid", fgColor=COR_FOREST),
        "zebra_fill": PatternFill("solid", fgColor=COR_ZEBRA),
        "total_fill": PatternFill("solid", fgColor=COR_SAGE),
        "ok_fill": PatternFill("solid", fgColor=COR_OK_BG),
        "err_fill": PatternFill("solid", fgColor=COR_ERR_BG),
        "banner_font": Font(name="Calibri", size=14, bold=True, color="FFFFFF"),
        "sub_font": Font(name="Calibri", size=10, italic=True, color=COR_FOREST),
        "sec_font": Font(name="Calibri", size=11, bold=True, color=COR_FOREST),
        "head_font": Font(name="Calibri", size=10, bold=True, color="FFFFFF"),
        "data_font": Font(name="Calibri", size=10, color=COR_TEXTO),
        "data_bold": Font(name="Calibri", size=10, bold=True, color=COR_TEXTO),
        "muted_font": Font(name="Calibri", size=9, color=COR_MUTED),
        "total_font": Font(name="Calibri", size=10, bold=True, color=COR_FOREST),
        "ok_font": Font(name="Calibri", size=10, bold=True, color=COR_OK_FG),
        "err_font": Font(name="Calibri", size=10, bold=True, color=COR_ERR_FG),
        "border": Border(left=thin, right=thin, top=thin, bottom=thin),
        "total_border": Border(left=thin, right=thin, top=med_forest, bottom=double_forest),
        "align_l": Alignment(horizontal="left", vertical="center"),
        "align_c": Alignment(horizontal="center", vertical="center"),
        "align_r": Alignment(horizontal="right", vertical="center"),
        "align_head_l": Alignment(horizontal="left", vertical="center", wrap_text=True),
        "align_head_c": Alignment(horizontal="center", vertical="center", wrap_text=True),
        "align_head_r": Alignment(horizontal="right", vertical="center", wrap_text=True),
    }


class StyleRegistry:
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


def xml_str(valor: Any) -> str:
    s = "" if valor is None else str(valor)
    if not s:
        return ""
    if any(ch in s for ch in ("&", "<", ">")):
        s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    if _XML_ILLEGAL_RE.search(s):
        s = _XML_ILLEGAL_RE.sub("", s)
    return s


def cell_str_xml(ref: str, s_idx: int, valor: Any) -> str:
    txt = xml_str(valor)
    if not txt:
        return f'<c r="{ref}" s="{s_idx}"/>'
    if txt[0] == " " or txt[-1] == " ":
        return f'<c r="{ref}" t="inlineStr" s="{s_idx}"><is><t xml:space="preserve">{txt}</t></is></c>'
    return f'<c r="{ref}" t="inlineStr" s="{s_idx}"><is><t>{txt}</t></is></c>'


def cell_num_xml(ref: str, s_idx: int, valor: Any) -> str:
    if valor is None:
        return f'<c r="{ref}" s="{s_idx}"/>'
    return f'<c r="{ref}" s="{s_idx}"><v>{valor}</v></c>'


def cell_formula_xml(ref: str, s_idx: int, formula: str, cached: Any = None) -> str:
    f_esc = xml_str(formula[1:] if formula.startswith("=") else formula)
    if cached is None:
        return f'<c r="{ref}" s="{s_idx}"><f>{f_esc}</f></c>'
    return f'<c r="{ref}" s="{s_idx}"><f>{f_esc}</f><v>{cached}</v></c>'


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


def aplicar_stream_patches(xlsx_base: bytes, patches: Dict[str, Tuple[str, int, bytes]]) -> bytes:
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


def cabecalho_planilha(ws, titulo: str, subtitulo: str, ncols: int, st: Dict[str, Any]) -> int:
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


def escrever_headers(ws, row_idx: int, headers: Sequence[Tuple[str, str]], st: Dict[str, Any]) -> None:
    ws.row_dimensions[row_idx].height = 28
    for idx, (titulo, alinhamento) in enumerate(headers, start=1):
        c = ws.cell(row=row_idx, column=idx, value=titulo)
        c.font = st["head_font"]
        c.fill = st["head_fill"]
        c.border = st["border"]
        c.alignment = st[f"align_head_{alinhamento}"]


def ajustar_larguras(ws, larguras: Sequence[float]) -> None:
    for idx, w in enumerate(larguras, start=1):
        ws.column_dimensions[get_column_letter(idx)].width = w


def escrever_linha(
    ws,
    row_idx: int,
    vals: Sequence[Tuple[Any, str, Optional[str]]],
    st: Dict[str, Any],
    *,
    zebra: bool = False,
    font_override: Optional[Font] = None,
    total: bool = False,
    ignorar_nf_none: bool = False,
) -> None:
    """Escreve e estiliza uma linha tabular no openpyxl preservando padrão visual das abas."""
    font = font_override or (st["total_font"] if total else st["data_font"])
    border = st["total_border"] if total else st["border"]
    fill = st["total_fill"] if total else (st["zebra_fill"] if zebra else None)
    for ci, (v, al, nf) in enumerate(vals, start=1):
        cell = ws.cell(row=row_idx, column=ci, value=v)
        cell.font = font
        cell.border = border
        cell.alignment = st[f"align_{al}"]
        if fill is not None:
            cell.fill = fill
        if nf and (not ignorar_nf_none or v is not None):
            cell.number_format = nf


def criar_par_estilo(reg: StyleRegistry, st: Dict[str, Any], borda: Optional[Border]) -> Callable[[str, Optional[str]], Tuple[int, int]]:
    """Retorna gerador de par `(indice_normal, indice_zebra)` registrado para streaming OOXML."""
    def _pair(al: str, nf: Optional[str] = None) -> Tuple[int, int]:
        return (
            reg.get(font=st["data_font"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
            reg.get(font=st["data_font"], fill=st["zebra_fill"], border=borda, alignment=st[f"align_{al}"], number_format=nf),
        )

    return _pair
