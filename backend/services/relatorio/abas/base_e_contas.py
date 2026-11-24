"""Abas `Plano de Contas ANS` e `Base ETL Demonstrações` (openpyxl direto e streaming OOXML)."""
from typing import Any, Dict, List, Optional, Tuple

from openpyxl import Workbook

from backend.services.relatorio.constantes import FMT_INT, FMT_MOEDA, FMT_PCT, STREAM_THRESHOLD_PADRAO
from backend.services.relatorio.estilos_ooxml import (
    StyleRegistry,
    ajustar_larguras,
    cabecalho_planilha,
    cell_num_xml,
    cell_str_xml,
    criar_par_estilo,
    escrever_headers,
    escrever_linha,
    xml_str,
)
from backend.services.relatorio.formatadores import fmt_cnpj, fmt_periodo, grupo_conta


def escrever_aba_contas_setor(
    wb: Workbook,
    dados: Dict[str, Any],
    subtitulo: str,
    st: Dict[str, Any],
    reg: StyleRegistry,
    patches: Dict[str, Tuple[str, int, bytes]],
    stream_threshold: int = STREAM_THRESHOLD_PADRAO,
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
    head_row = cabecalho_planilha(ws, "Base ETL · Plano de Contas do Setor (contas_setor)", subtitulo, len(headers), st)
    escrever_headers(ws, head_row, headers, st)
    ws.freeze_panes = f"A{head_row + 1}"
    ajustar_larguras(ws, [8, 10, 22, 14, 28, 8, 46, 22])

    contas = dados["contas_setor"]
    if not contas:
        return
    start = head_row + 1
    end = start + len(contas) - 1
    ws.auto_filter.ref = f"A{head_row}:H{end}"

    if len(contas) <= stream_threshold:
        row = start
        for i, c in enumerate(contas):
            nivel = int(c["nivel"] or 0)
            vals = [
                (int(c["ano"]), "c", "0"),
                (int(c["trimestre"]), "c", "0"),
                (fmt_periodo(int(c["ano"]), int(c["trimestre"])), "l", None),
                (str(c["codigo"]), "c", "@"),
                (grupo_conta(str(c["codigo"])), "l", None),
                (nivel, "c", "0"),
                (c["descricao"], "l", None),
                (float(c["valor"] or 0), "r", FMT_MOEDA),
            ]
            escrever_linha(
                ws,
                row,
                vals,
                st,
                zebra=i % 2 == 1,
                font_override=st["data_bold"] if nivel == 0 else st["data_font"],
            )
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
            f'{cell_num_xml(f"A{r}", s_num_c[k], ano)}'
            f'{cell_num_xml(f"B{r}", s_num_c[k], tri)}'
            f'{cell_str_xml(f"C{r}", s_txt_l[k], f"{tri}º trimestre de {ano}")}'
            f'{cell_str_xml(f"D{r}", s_cod[k], cod)}'
            f'{cell_str_xml(f"E{r}", s_txt_l[k], grupo_conta(cod))}'
            f'{cell_num_xml(f"F{r}", s_num_c[k], nivel)}'
            f'{cell_str_xml(f"G{r}", s_txt_l[k], c["descricao"])}'
            f'{cell_num_xml(f"H{r}", s_moeda[k], round(float(c["valor"] or 0), 2))}'
            f'</row>'
        )
    patches[nome_aba] = ("H", end, "".join(xml_rows).encode("utf-8"))


def escrever_aba_base_demonstracoes(
    wb: Workbook,
    dados: Dict[str, Any],
    subtitulo: str,
    st: Dict[str, Any],
    reg: StyleRegistry,
    patches: Dict[str, Tuple[str, int, bytes]],
    stream_threshold: int = STREAM_THRESHOLD_PADRAO,
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
    head_row = cabecalho_planilha(
        ws,
        "Base Fato ETL · Demonstrações × Beneficiários (Pronta para Tabela Dinâmica)",
        subtitulo,
        len(headers),
        st,
    )
    escrever_headers(ws, head_row, headers, st)
    ws.freeze_panes = f"A{head_row + 1}"
    ajustar_larguras(
        ws, [8, 10, 21, 13, 19, 34, 24, 6, 24, 10, 20, 20, 19, 18, 18, 14, 15, 15, 15, 13]
    )

    fatos = dados["_fatos_tuplas"]
    ops_map = dados["_ops_map"]
    if not fatos:
        return
    start = head_row + 1
    end = start + len(fatos) - 1
    ws.auto_filter.ref = f"A{head_row}:T{end}"

    if len(fatos) <= stream_threshold:
        row = start
        for i, (ano, tri, reg_ans, rec, ev, ev_mh, com, adm, bmh, bod, aud) in enumerate(fatos):
            op = ops_map[reg_ans]
            vals = [
                (ano, "c", "0"),
                (tri, "c", "0"),
                (fmt_periodo(ano, tri), "l", None),
                (reg_ans, "c", "@"),
                (fmt_cnpj(op["cnpj"]), "c", "@"),
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
            escrever_linha(ws, row, vals, st, zebra=i % 2 == 1)
            row += 1
        return

    # OOXML streaming ultrarrápido com pré-escape por operadora (suporta 34.634+ linhas em < 1s)
    com_formula = len(fatos) <= 5000
    borda = st["border"] if len(fatos) <= 5000 else None
    pair = criar_par_estilo(reg, st, borda)

    s_num_c = pair("c", "0")
    s_txt_l = pair("l", None)
    s_txt_c = pair("c", None)
    s_txt_at = pair("c", "@")
    s_moeda = pair("r", FMT_MOEDA)
    s_pct = pair("r", FMT_PCT)
    s_int = pair("r", FMT_INT)

    # Pré-escapa os 7 campos textuais uma única vez por operadora (~1.4k em vez de 242k vezes!)
    op_esc: Dict[str, Tuple[str, str, str, str, str, str, str]] = {}
    for r_ans, op in ops_map.items():
        op_esc[r_ans] = (
            xml_str(r_ans),
            xml_str(fmt_cnpj(op["cnpj"])),
            xml_str(op["razao_social"] or ""),
            xml_str(op["nome_fantasia"] or ""),
            xml_str(op["uf"] or ""),
            xml_str(op["modalidade"] or "Não informada"),
            xml_str(op["status"] or ""),
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
