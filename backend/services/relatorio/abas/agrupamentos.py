"""Abas agrupadas `Por Modalidade` e `Por UF` do relatório XLSX."""
from typing import Any, Dict, List

from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference
from openpyxl.utils import get_column_letter

from backend.services.relatorio.constantes import COR_FOREST, FMT_INT, FMT_MOEDA, FMT_PCT
from backend.services.relatorio.estilos_ooxml import (
    ajustar_larguras,
    cabecalho_planilha,
    escrever_headers,
    escrever_linha,
)


def _escrever_aba_agrupada(
    wb: Workbook,
    titulo_aba: str,
    titulo_doc: str,
    subtitulo: str,
    campo: str,
    label_campo: str,
    itens: List[Dict[str, Any]],
    st: Dict[str, Any],
    com_grafico: bool = False,
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
    head_row = cabecalho_planilha(ws, titulo_doc, subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
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
        escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
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
        escrever_linha(ws, row, totais, st, total=True)
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
                chart.series[0].graphicalProperties.solidFill = COR_FOREST
            ws.add_chart(chart, f"A{row + 2}")

    larg_col1 = 30 if campo == "modalidade" else 10
    ajustar_larguras(ws, [larg_col1, 12, 20, 20, 20, 18, 18, 20, 15, 16, 16, 16, 18])


def escrever_aba_modalidades(wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
    _escrever_aba_agrupada(
        wb, "Por Modalidade", "Consolidado por Modalidade ANS", subtitulo,
        "modalidade", "Modalidade", dados["por_modalidade"], st, com_grafico=True,
    )


def escrever_aba_ufs(wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
    _escrever_aba_agrupada(
        wb, "Por UF", "Distribuição Regional por UF", subtitulo,
        "uf", "UF", dados["por_uf"], st, com_grafico=False,
    )
