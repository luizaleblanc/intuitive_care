"""Abas `Resumo Executivo` e `Evolução Período` do relatório XLSX."""
from typing import Any, Dict

from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference

from backend.services.relatorio.constantes import COR_FOREST, COR_MINT, FMT_INT, FMT_MOEDA, FMT_PCT
from backend.services.relatorio.estilos_ooxml import (
    ajustar_larguras,
    cabecalho_planilha,
    escrever_headers,
    escrever_linha,
)


def escrever_aba_resumo(wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
    ws = wb.create_sheet("Resumo Executivo")
    k = dados["kpis"]
    row = cabecalho_planilha(ws, "Relatório Analítico ANS · Resumo Executivo", subtitulo, 6, st)

    ws.cell(row=row, column=1, value="1. INDICADORES CONSOLIDADOS DO RECORTE (BASES ETL)").font = st["sec_font"]
    row += 1
    escrever_headers(
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
    escrever_headers(ws, row, [("Dimensão ETL", "l"), ("Quantidade / Valor", "r"), ("Tabela Origem", "l"), ("Detalhamento", "l")], st)
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
        escrever_headers(
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
            escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
            row += 1

    ajustar_larguras(ws, [46, 24, 38, 48, 18, 18])


def escrever_aba_evolucao(wb: Workbook, dados: Dict[str, Any], subtitulo: str, st: Dict[str, Any]) -> None:
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
    head_row = cabecalho_planilha(ws, "Evolução Financeira e Assistencial", subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
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
        escrever_linha(ws, row, vals, st, zebra=i % 2 == 1, ignorar_nf_none=True)
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
        escrever_linha(ws, row, totais, st, total=True, ignorar_nf_none=True)
        ws.auto_filter.ref = f"A{head_row}:{ws.cell(row=head_row, column=len(headers)).column_letter}{end}"

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
            chart.series[0].graphicalProperties.solidFill = COR_FOREST
            chart.series[1].graphicalProperties.solidFill = COR_MINT
        ws.add_chart(chart, f"A{row + 2}")

    ajustar_larguras(ws, [22, 8, 12, 22, 22, 20, 18, 18, 22, 15, 16, 15, 16, 16, 16, 18])
