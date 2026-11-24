"""Abas `Lotes ETL` e `Cadastro Operadoras` do relatório XLSX."""
from typing import Any, Dict, List, Tuple

from openpyxl import Workbook

from backend.services.relatorio.constantes import FMT_INT, STREAM_THRESHOLD_PADRAO
from backend.services.relatorio.estilos_ooxml import (
    StyleRegistry,
    ajustar_larguras,
    cabecalho_planilha,
    cell_num_xml,
    cell_str_xml,
    criar_par_estilo,
    escrever_headers,
    escrever_linha,
)
from backend.services.relatorio.formatadores import fmt_cnpj, fmt_data, fmt_periodo


def escrever_aba_lotes(
    wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any], fmt_data_padrao: str
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
    head_row = cabecalho_planilha(ws, "Base ETL · Rastreabilidade e Auditoria de Lotes (lotes_etl)", subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
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
            (fmt_periodo(int(l["ano"]), int(l["trimestre"])), "l", None),
            (int(l.get("registros_extraidos") or 0), "r", FMT_INT),
            (int(l.get("operadoras") or 0), "r", FMT_INT),
            (fmt_data(l.get("carregado_em"), formato=fmt_data_padrao, hora=True), "c", None),
            ("Auditado" if aud else "Pendente", "c", None),
            (l.get("auditado_por") or "—", "l", None),
            (fmt_data(l.get("auditado_em"), formato=fmt_data_padrao, hora=True) or "—", "c", None),
        ]
        escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
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
        escrever_linha(ws, row, totais, st, total=True)
        ws.auto_filter.ref = f"A{head_row}:I{end}"

    ajustar_larguras(ws, [8, 10, 22, 20, 24, 19, 13, 24, 19])


def escrever_aba_cadastro(
    wb: Workbook,
    dados: Dict[str, Any],
    subtitulo: str,
    st: Dict[str, Any],
    fmt_data_padrao: str,
    reg: StyleRegistry,
    patches: Dict[str, Tuple[str, int, bytes]],
    stream_threshold: int = STREAM_THRESHOLD_PADRAO,
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
    head_row = cabecalho_planilha(ws, "Base ETL · Cadastro CADOP de Operadoras (operadoras)", subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
    ws.freeze_panes = f"A{head_row + 1}"
    ajustar_larguras(ws, [13, 19, 34, 24, 24, 11, 6, 18, 22, 20, 16, 26, 28, 18])

    cad = dados["cadastro_operadoras"]
    if not cad:
        return
    start = head_row + 1
    end = start + len(cad) - 1
    ws.auto_filter.ref = f"A{head_row}:N{end}"

    if len(cad) <= stream_threshold:
        row = start
        for i, o in enumerate(cad):
            vals = [
                (o["registro_ans"], "c", "@"),
                (fmt_cnpj(o["cnpj"]), "c", "@"),
                (o["razao_social"] or "", "l", None),
                (o["nome_fantasia"] or "", "l", None),
                (o["modalidade"] or "Não informada", "l", None),
                (o["status"] or "", "c", None),
                (o["uf"] or "", "c", None),
                (o["cidade"] or "", "l", None),
                (int(o.get("beneficiarios") or 0), "r", FMT_INT),
                (int(o.get("beneficiarios_mh") or 0), "r", FMT_INT),
                (fmt_data(o.get("data_descredenciamento"), formato=fmt_data_padrao) or "", "c", None),
                (o.get("representante") or "", "l", None),
                (o.get("email") or "", "l", None),
                (o.get("telefone") or "", "l", None),
            ]
            escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
            row += 1
        return

    borda = st["border"] if len(cad) <= 5000 else None
    pair = criar_par_estilo(reg, st, borda)
    s_txt_l = pair("l", None)
    s_txt_c = pair("c", None)
    s_txt_at = pair("c", "@")
    s_int = pair("r", FMT_INT)

    xml_rows: List[str] = []
    append = xml_rows.append
    for i, o in enumerate(cad):
        r = start + i
        z = i & 1
        append(
            f'<row r="{r}">'
            f'{cell_str_xml(f"A{r}", s_txt_at[z], o["registro_ans"])}'
            f'{cell_str_xml(f"B{r}", s_txt_at[z], fmt_cnpj(o["cnpj"]))}'
            f'{cell_str_xml(f"C{r}", s_txt_l[z], o["razao_social"] or "")}'
            f'{cell_str_xml(f"D{r}", s_txt_l[z], o["nome_fantasia"] or "")}'
            f'{cell_str_xml(f"E{r}", s_txt_l[z], o["modalidade"] or "Não informada")}'
            f'{cell_str_xml(f"F{r}", s_txt_c[z], o["status"] or "")}'
            f'{cell_str_xml(f"G{r}", s_txt_c[z], o["uf"] or "")}'
            f'{cell_str_xml(f"H{r}", s_txt_l[z], o["cidade"] or "")}'
            f'{cell_num_xml(f"I{r}", s_int[z], int(o.get("beneficiarios") or 0))}'
            f'{cell_num_xml(f"J{r}", s_int[z], int(o.get("beneficiarios_mh") or 0))}'
            f'{cell_str_xml(f"K{r}", s_txt_c[z], fmt_data(o.get("data_descredenciamento"), formato=fmt_data_padrao) or "")}'
            f'{cell_str_xml(f"L{r}", s_txt_l[z], o.get("representante") or "")}'
            f'{cell_str_xml(f"M{r}", s_txt_l[z], o.get("email") or "")}'
            f'{cell_str_xml(f"N{r}", s_txt_l[z], o.get("telefone") or "")}'
            f'</row>'
        )
    patches[nome_aba] = ("N", end, "".join(xml_rows).encode("utf-8"))
