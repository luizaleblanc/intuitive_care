"""Aba `Operadoras Consolidado` (modo openpyxl direto e streaming OOXML)."""
from typing import Any, Dict, List, Tuple

from openpyxl import Workbook

from backend.services.relatorio.constantes import FMT_INT, FMT_MOEDA, FMT_PCT, STREAM_THRESHOLD_PADRAO
from backend.services.relatorio.estilos_ooxml import (
    StyleRegistry,
    ajustar_larguras,
    cabecalho_planilha,
    cell_formula_xml,
    cell_num_xml,
    cell_str_xml,
    criar_par_estilo,
    escrever_headers,
    escrever_linha,
)


def escrever_aba_operadoras(
    wb: Workbook,
    dados: Dict[str, Any],
    subtitulo: str,
    st: Dict[str, Any],
    reg: StyleRegistry,
    patches: Dict[str, Tuple[str, int, bytes]],
    stream_threshold: int = STREAM_THRESHOLD_PADRAO,
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
    head_row = cabecalho_planilha(ws, "Ranking e Consolidado de Operadoras", subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
    ws.freeze_panes = f"E{head_row + 1}"
    ajustar_larguras(
        ws, [13, 19, 34, 24, 24, 6, 18, 10, 14, 11, 20, 20, 19, 18, 18, 20, 14, 15, 16, 16, 18]
    )

    ops = dados["operadoras"]
    if not ops:
        return
    start = head_row + 1
    end = start + len(ops) - 1
    total_row = end + 1
    ws.auto_filter.ref = f"A{head_row}:U{end}"

    if len(ops) <= stream_threshold:
        row = start
        for i, o in enumerate(ops):
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
            escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
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
        escrever_linha(ws, total_row, totais, st, total=True)
        return

    # Caminho OOXML streaming para grande volume de operadoras (preserva fórmulas vivas + estilos)
    borda = st["border"]
    pair = criar_par_estilo(reg, st, borda)
    s_txt_l = pair("l", None)
    s_txt_c = pair("c", None)
    s_txt_at = pair("c", "@")
    s_int = pair("r", FMT_INT)
    s_moeda = pair("r", FMT_MOEDA)
    s_pct = pair("r", FMT_PCT)
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
            f'{cell_str_xml(f"A{r}", s_txt_at[z], o["registro_ans"])}'
            f'{cell_str_xml(f"B{r}", s_txt_at[z], o["cnpj"])}'
            f'{cell_str_xml(f"C{r}", s_txt_l[z], o["razao_social"])}'
            f'{cell_str_xml(f"D{r}", s_txt_l[z], o["nome_fantasia"])}'
            f'{cell_str_xml(f"E{r}", s_txt_l[z], o["modalidade"])}'
            f'{cell_str_xml(f"F{r}", s_txt_c[z], o["uf"])}'
            f'{cell_str_xml(f"G{r}", s_txt_l[z], o["cidade"])}'
            f'{cell_str_xml(f"H{r}", s_txt_c[z], o["status"])}'
            f'{cell_str_xml(f"I{r}", s_txt_l[z], o["porte"])}'
            f'{cell_num_xml(f"J{r}", s_int[z], o["trimestres"])}'
            f'{cell_num_xml(f"K{r}", s_moeda[z], round(o["receitas"], 2))}'
            f'{cell_num_xml(f"L{r}", s_moeda[z], round(o["despesas"], 2))}'
            f'{cell_num_xml(f"M{r}", s_moeda[z], round(o["eventos_mh"], 2))}'
            f'{cell_num_xml(f"N{r}", s_moeda[z], round(o["comercializacao"], 2))}'
            f'{cell_num_xml(f"O{r}", s_moeda[z], round(o["administrativas"], 2))}'
            f'{cell_formula_xml(f"P{r}", s_moeda[z], f"K{r}-L{r}-N{r}-O{r}", round(o["resultado"], 2))}'
            f'{cell_formula_xml(f"Q{r}", sin_style, f"IF(K{r}>0,L{r}/K{r},0)", sin if sin is not None else 0)}'
            f'{cell_formula_xml(f"R{r}", s_pct[z], f"IF(K{r}>0,(L{r}+N{r}+O{r})/K{r},0)", o["indice_combinado"] if o["indice_combinado"] is not None else 0)}'
            f'{cell_num_xml(f"S{r}", s_int[z], o["benef_mh"])}'
            f'{cell_num_xml(f"T{r}", s_int[z], o["benef_odonto"])}'
            f'{cell_formula_xml(f"U{r}", s_moeda[z], f"IF(S{r}>0,M{r}/S{r},0)", round(o["ticket_medio"], 2) if o["ticket_medio"] is not None else 0)}'
            f'</row>'
        )

    # Linha TOTAL com fórmulas vivas
    r = total_row
    append(
        f'<row r="{r}" ht="22" customHeight="1">'
        f'{cell_str_xml(f"A{r}", s_tot_l, "TOTAL")}'
        f'{cell_str_xml(f"B{r}", s_tot_c, "")}'
        f'{cell_str_xml(f"C{r}", s_tot_l, f"{len(ops)} operadora(s)")}'
        f'{cell_str_xml(f"D{r}", s_tot_l, "")}{cell_str_xml(f"E{r}", s_tot_l, "")}'
        f'{cell_str_xml(f"F{r}", s_tot_c, "")}{cell_str_xml(f"G{r}", s_tot_l, "")}'
        f'{cell_str_xml(f"H{r}", s_tot_c, "")}{cell_str_xml(f"I{r}", s_tot_l, "")}'
        f'{cell_formula_xml(f"J{r}", s_tot_int, f"SUM(J{start}:J{end})")}'
        f'{cell_formula_xml(f"K{r}", s_tot_moeda, f"SUM(K{start}:K{end})")}'
        f'{cell_formula_xml(f"L{r}", s_tot_moeda, f"SUM(L{start}:L{end})")}'
        f'{cell_formula_xml(f"M{r}", s_tot_moeda, f"SUM(M{start}:M{end})")}'
        f'{cell_formula_xml(f"N{r}", s_tot_moeda, f"SUM(N{start}:N{end})")}'
        f'{cell_formula_xml(f"O{r}", s_tot_moeda, f"SUM(O{start}:O{end})")}'
        f'{cell_formula_xml(f"P{r}", s_tot_moeda, f"K{r}-L{r}-N{r}-O{r}")}'
        f'{cell_formula_xml(f"Q{r}", s_tot_pct, f"IF(K{r}>0,L{r}/K{r},0)")}'
        f'{cell_formula_xml(f"R{r}", s_tot_pct, f"IF(K{r}>0,(L{r}+N{r}+O{r})/K{r},0)")}'
        f'{cell_formula_xml(f"S{r}", s_tot_int, f"SUM(S{start}:S{end})")}'
        f'{cell_formula_xml(f"T{r}", s_tot_int, f"SUM(T{start}:T{end})")}'
        f'{cell_formula_xml(f"U{r}", s_tot_moeda, f"IF(S{r}>0,M{r}/S{r},0)")}'
        f'</row>'
    )
    patches[nome_aba] = ("U", total_row, "".join(xml_rows).encode("utf-8"))
