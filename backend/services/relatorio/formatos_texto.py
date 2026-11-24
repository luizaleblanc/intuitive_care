"""Serialização de tabelas estruturadas para JSON (PDF) e CSV UTF-8 com BOM."""
from io import StringIO
from typing import Any, Dict, List, Optional, Tuple

from backend.services.relatorio.formatadores import fmt_cnpj, fmt_data, fmt_periodo, grupo_conta


def formatar_tabelas_estruturadas(
    dados: Dict[str, Any], limite_linhas_brutas: Optional[int] = None
) -> Dict[str, Any]:
    """Monta tabelas padronizadas para CSV multi-seção e geração de PDF."""
    cfg = dados["cfg"]
    secoes = cfg["secoes"]
    fmt_data_padrao = cfg["formato_data"]
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
                        fmt_periodo(int(c["ano"]), int(c["trimestre"])),
                        str(c["codigo"]),
                        grupo_conta(str(c["codigo"])),
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
                        fmt_periodo(int(r["ano"]), int(r["trimestre"])),
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
                        fmt_periodo(int(l["ano"]), int(l["trimestre"])),
                        str(int(l.get("registros_extraidos") or 0)),
                        str(int(l.get("operadoras") or 0)),
                        fmt_data(l.get("carregado_em"), formato=fmt_data_padrao, hora=True),
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
                        fmt_cnpj(o["cnpj"]),
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


def gerar_csv_de_tabelas(estruturado: Dict[str, Any]) -> Tuple[bytes, str]:
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
