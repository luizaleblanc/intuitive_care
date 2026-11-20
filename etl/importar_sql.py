"""Carga (Load) dos dados reais da ANS no banco da aplicação.

Ordem:
  1. Operadoras ativas (Relatorio_cadop.csv)      -> upsert, status "Ativa"
  2. Operadoras canceladas (Relatorio_cadop_canceladas.csv) -> status "Inativa"
  3. Beneficiários (Beneficiarios_operadora_e_carteira.csv) -> snapshot atual + por trimestre
  4. Demonstrações por operadora, contas do setor, lotes e despesas (saídas do processamento)
  5. Remove a massa fictícia de demonstração (operadoras *.demo.br e despesas de exemplo)

Pode ser executado várias vezes: cada etapa substitui a carga anterior.
Conexão: variáveis DB_* (lidas do .env da raiz pelo backend.config).
"""
import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import pandas as pd  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402

import backend.config  # noqa: E402,F401  (carrega o .env)
from backend.database.init_db import initialize_database  # noqa: E402
from etl.texto import ler_csv_ans, normalizar_dataframe  # noqa: E402

DATA = os.path.join(BASE_DIR, "data")
RAW = os.path.join(DATA, "raw")

COLUNAS_OPERADORA = [
    "registro_ans", "cnpj", "razao_social", "nome_fantasia", "modalidade", "logradouro", "numero",
    "complemento", "bairro", "cidade", "uf", "cep", "telefone", "email", "representante", "cargo_representante",
]
LIMITES = {
    "nome_fantasia": 255, "razao_social": 255, "modalidade": 120, "logradouro": 255, "numero": 30,
    "complemento": 120, "bairro": 120, "cidade": 120, "cep": 10, "telefone": 30, "email": 180,
    "representante": 150, "cargo_representante": 120,
}


def limpar_digitos(valor) -> str:
    if valor is None or (not isinstance(valor, str) and pd.isna(valor)):
        return ""
    return re.sub(r"\D", "", str(valor))


def _url_conexao() -> str:
    if os.getenv("DB_ENGINE", "mysql") == "sqlite":
        return f"sqlite:///{os.getenv('SQLITE_PATH', 'backend/database/intuitive_care_local.db')}"
    return (
        f"mysql+pymysql://{os.getenv('DB_USER', 'root')}:{os.getenv('DB_PASSWORD', 'root')}"
        f"@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '3308')}"
        f"/{os.getenv('DB_NAME', 'intuitive_care')}?charset=utf8mb4"
    )


def _executar_em_lotes(conn, sql, registros, tamanho: int = 2000) -> None:
    for i in range(0, len(registros), tamanho):
        conn.execute(sql, registros[i : i + tamanho])


def _registros(df: pd.DataFrame, colunas):
    """Converte para dicts trocando NaN por None (aceito pelo driver)."""
    saida = []
    for rec in df[colunas].astype(object).to_dict(orient="records"):
        saida.append({k: (None if (not isinstance(v, str) and pd.isna(v)) else v) for k, v in rec.items()})
    return saida


def ler_cadastro(nome_arquivo: str) -> pd.DataFrame:
    df = ler_csv_ans(os.path.join(RAW, nome_arquivo), sep=";", dtype=str)
    df.columns = df.columns.str.strip().str.upper()
    df = normalizar_dataframe(df)
    df = df.rename(columns={"REGISTRO_OPERADORA": "registro_ans", "ENDERECO_ELETRONICO": "email"})
    df.columns = [c.lower() for c in df.columns]
    if "ddd" in df.columns:
        df["telefone"] = (df["ddd"].fillna("").str.strip() + " " + df["telefone"].fillna("").str.strip()).str.strip()
    df["registro_ans"] = df["registro_ans"].map(limpar_digitos)
    df["cnpj"] = df["cnpj"].map(limpar_digitos).str.zfill(14)
    df["cep"] = df.get("cep", pd.Series(dtype=str)).map(limpar_digitos)
    df["uf"] = df["uf"].fillna("NA").astype(str).str.strip().str.upper().str[:2]
    df = df[(df["registro_ans"] != "") & (df["cnpj"] != "0" * 14)]
    for col in COLUNAS_OPERADORA:
        if col not in df.columns:
            df[col] = None
    for col, tam in LIMITES.items():
        df[col] = df[col].where(df[col].isna(), df[col].astype(str).str[:tam])
        df[col] = df[col].replace("", None)
    return df


def carregar_operadoras(conn) -> None:
    ativas = ler_cadastro("Relatorio_cadop.csv").drop_duplicates("registro_ans").drop_duplicates("cnpj")
    print(f"Operadoras ativas no cadastro da ANS: {len(ativas)}")

    existentes = {r[0]: r[1] for r in conn.execute(text("SELECT registro_ans, status FROM operadoras")).all()}
    cnpjs = {r[0]: r[1] for r in conn.execute(text("SELECT cnpj, registro_ans FROM operadoras")).all()}

    sets = ", ".join(f"{c} = :{c}" for c in COLUNAS_OPERADORA if c != "registro_ans")
    novos, atualizados = [], []
    for rec in _registros(ativas, COLUNAS_OPERADORA):
        dono_cnpj = cnpjs.get(rec["cnpj"])
        if dono_cnpj and dono_cnpj != rec["registro_ans"]:
            # CNPJ preso a um registro antigo (ex.: operadora cancelada e recadastrada): libera o CNPJ.
            conn.execute(
                text("UPDATE operadoras SET cnpj = :tmp WHERE registro_ans = :r"),
                {"tmp": ("X" + dono_cnpj)[:14], "r": dono_cnpj},
            )
        if rec["registro_ans"] in existentes:
            # Preserva "Em análise" definido manualmente pelo Administrador.
            rec["status"] = "Em análise" if existentes[rec["registro_ans"]] == "Em análise" else "Ativa"
            atualizados.append(rec)
        else:
            rec["status"] = "Ativa"
            novos.append(rec)

    if atualizados:
        conn.execute(
            text(f"UPDATE operadoras SET {sets}, status = :status, data_descredenciamento = NULL "
                 "WHERE registro_ans = :registro_ans"),
            atualizados,
        )
    if novos:
        cols = COLUNAS_OPERADORA + ["status"]
        conn.execute(
            text(f"INSERT INTO operadoras ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})"),
            novos,
        )
    print(f"  {len(atualizados)} atualizadas · {len(novos)} novas")

    canceladas = ler_cadastro("Relatorio_cadop_canceladas.csv")
    canceladas["data_descredenciamento"] = pd.to_datetime(
        canceladas.get("data_descredenciamento"), errors="coerce"
    ).dt.date
    canceladas = canceladas.sort_values("data_descredenciamento", ascending=False)
    ativos_reg = set(ativas["registro_ans"])
    ativos_cnpj = set(ativas["cnpj"])
    canceladas = canceladas[
        ~canceladas["registro_ans"].isin(ativos_reg) & ~canceladas["cnpj"].isin(ativos_cnpj)
    ].drop_duplicates("registro_ans").drop_duplicates("cnpj")

    ja_existem = {r[0] for r in conn.execute(text("SELECT registro_ans FROM operadoras")).all()}
    cnpjs_usados = {r[0] for r in conn.execute(text("SELECT cnpj FROM operadoras")).all()}
    cols = COLUNAS_OPERADORA + ["status", "data_descredenciamento"]
    regs = _registros(canceladas, COLUNAS_OPERADORA + ["data_descredenciamento"])
    inserir = []
    atualizar = []
    for rec in regs:
        rec["status"] = "Inativa"
        if rec["registro_ans"] in ja_existem:
            atualizar.append({"r": rec["registro_ans"], "d": rec["data_descredenciamento"]})
        elif rec["cnpj"] not in cnpjs_usados:
            inserir.append(rec)
            cnpjs_usados.add(rec["cnpj"])
    if atualizar:
        conn.execute(
            text("UPDATE operadoras SET status = 'Inativa', data_descredenciamento = :d WHERE registro_ans = :r"),
            atualizar,
        )
    if inserir:
        conn.execute(
            text(f"INSERT INTO operadoras ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})"),
            inserir,
        )
    print(f"Operadoras canceladas (Inativa): {len(inserir)} novas · {len(atualizar)} atualizadas")


def carregar_beneficiarios(conn) -> None:
    arquivo = os.path.join(RAW, "Beneficiarios_operadora_e_carteira.csv")
    if not os.path.exists(arquivo):
        print("AVISO: arquivo de beneficiários não encontrado; pulei esta etapa.")
        return
    df = ler_csv_ans(arquivo, sep=";", dtype=str, usecols=["CD_OPERADORA", "COBERTURA", "MES", "NR_BENEF"])
    df["NR_BENEF"] = pd.to_numeric(df["NR_BENEF"], errors="coerce").fillna(0).astype(int)
    df["COBERTURA"] = df["COBERTURA"].map(lambda c: "mh" if "dico" in str(c) else "odonto")
    tabela = df.pivot_table(index=["CD_OPERADORA", "MES"], columns="COBERTURA", values="NR_BENEF",
                            aggfunc="sum", fill_value=0).reset_index()
    for col in ("mh", "odonto"):
        if col not in tabela.columns:
            tabela[col] = 0

    existentes = {r[0] for r in conn.execute(text("SELECT registro_ans FROM operadoras")).all()}
    tabela = tabela[tabela["CD_OPERADORA"].isin(existentes)]

    # Snapshot atual (último mês publicado) na própria operadora.
    ultimo_mes = tabela["MES"].max()
    atual = tabela[tabela["MES"] == ultimo_mes]
    conn.execute(text("UPDATE operadoras SET beneficiarios = 0, beneficiarios_mh = 0"))
    conn.execute(
        text("UPDATE operadoras SET beneficiarios = :t, beneficiarios_mh = :mh WHERE registro_ans = :r"),
        [{"t": int(r.mh + r.odonto), "mh": int(r.mh), "r": r.CD_OPERADORA} for r in atual.itertuples()],
    )

    # Histórico: mês de fechamento de cada trimestre (03, 06, 09, 12).
    fechamento = tabela[tabela["MES"].str[4:].isin(["03", "06", "09", "12"])].copy()
    fechamento["ano"] = fechamento["MES"].str[:4].astype(int)
    fechamento["trimestre"] = fechamento["MES"].str[4:].astype(int) // 3
    demo_csv = os.path.join(DATA, "demonstracoes_operadora.csv")
    if os.path.exists(demo_csv):
        ano_minimo = int(pd.read_csv(demo_csv, usecols=["ano"])["ano"].min())
        fechamento = fechamento[fechamento["ano"] >= ano_minimo]
    conn.execute(text("DELETE FROM beneficiarios_trimestre"))
    _executar_em_lotes(
        conn,
        text("INSERT INTO beneficiarios_trimestre (reg_ans, ano, trimestre, medico_hospitalar, odontologico) "
             "VALUES (:r, :a, :t, :mh, :od)"),
        [{"r": r.CD_OPERADORA, "a": int(r.ano), "t": int(r.trimestre), "mh": int(r.mh), "od": int(r.odonto)}
         for r in fechamento.itertuples()],
    )
    print(f"Beneficiários: competência {ultimo_mes[4:]}/{ultimo_mes[:4]} · "
          f"{int(atual['mh'].sum()):,} médico-hospitalares ({len(fechamento)} trimestres)".replace(",", "."))


def carregar_contabil(conn) -> None:
    caminhos = {n: os.path.join(DATA, f"{n}.csv") for n in ("demonstracoes_operadora", "contas_setor", "lotes")}
    if not all(os.path.exists(p) for p in caminhos.values()):
        print("AVISO: saídas do processamento não encontradas. Rode etl/processamento.py antes.")
        return

    existentes = {r[0] for r in conn.execute(text("SELECT registro_ans FROM operadoras")).all()}

    demo = pd.read_csv(caminhos["demonstracoes_operadora"], dtype={"reg_ans": str})
    demo = demo[demo["reg_ans"].isin(existentes)]
    conn.execute(text("DELETE FROM demonstracoes_operadora"))
    cols = ["reg_ans", "ano", "trimestre", "contraprestacoes", "eventos", "eventos_mh", "comercializacao",
            "administrativas"]
    _executar_em_lotes(
        conn,
        text(f"INSERT INTO demonstracoes_operadora ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})"),
        _registros(demo, cols),
    )

    setor = pd.read_csv(caminhos["contas_setor"], dtype={"codigo": str})
    conn.execute(text("DELETE FROM contas_setor"))
    cols = ["ano", "trimestre", "codigo", "descricao", "nivel", "valor"]
    setor["descricao"] = setor["descricao"].fillna("").str[:255]
    _executar_em_lotes(
        conn,
        text(f"INSERT INTO contas_setor ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})"),
        _registros(setor, cols),
    )

    # Lotes: preserva o status de auditoria já registrado pelo Administrador.
    lotes = pd.read_csv(caminhos["lotes"])
    for rec in _registros(lotes, ["ano", "trimestre", "registros_extraidos", "operadoras"]):
        res = conn.execute(
            text("UPDATE lotes_etl SET registros_extraidos = :registros_extraidos, operadoras = :operadoras "
                 "WHERE ano = :ano AND trimestre = :trimestre"),
            rec,
        )
        if res.rowcount == 0:
            conn.execute(
                text("INSERT INTO lotes_etl (ano, trimestre, registros_extraidos, operadoras) "
                     "VALUES (:ano, :trimestre, :registros_extraidos, :operadoras)"),
                rec,
            )

    # Tabela de lançamentos (CRUD de despesas): conta 41 por operadora/trimestre.
    conn.execute(text("DELETE FROM despesas WHERE descricao = 'Importação ETL ANS'"))
    lanc = demo[demo["eventos"] > 0].rename(columns={"eventos": "valor_despesa"})
    _executar_em_lotes(
        conn,
        text("INSERT INTO despesas (reg_ans, ano, trimestre, valor_despesa, categoria, descricao) "
             "VALUES (:reg_ans, :ano, :trimestre, :valor_despesa, 'Eventos Indenizáveis Líquidos', "
             "'Importação ETL ANS')"),
        _registros(lanc, ["reg_ans", "ano", "trimestre", "valor_despesa"]),
    )
    print(f"Contábil: {len(demo)} demonstrações · {len(setor)} contas do setor · {len(lotes)} lotes · "
          f"{len(lanc)} lançamentos")


def remover_demonstracao(conn) -> None:
    """Remove a massa fictícia do backup inicial, agora substituída por dados reais."""
    demo_ops = [r[0] for r in conn.execute(
        text("SELECT registro_ans FROM operadoras WHERE email LIKE '%.demo.br'")).all()]
    conn.execute(text("DELETE FROM despesas WHERE descricao <> 'Importação ETL ANS' AND ano = 2024"))
    conn.execute(text(
        "DELETE FROM despesas WHERE descricao LIKE '%1T2025' AND categoria IN "
        "('Despesa Assistencial', 'Eventos Indenizáveis Líquidos') AND descricao <> 'Importação ETL ANS'"))
    for reg in demo_ops:
        conn.execute(text("DELETE FROM despesas WHERE reg_ans = :r"), {"r": reg})
        conn.execute(text("DELETE FROM operadoras WHERE registro_ans = :r"), {"r": reg})
    if demo_ops:
        print(f"Removidas {len(demo_ops)} operadoras fictícias de demonstração.")


def importar_dados():
    url = _url_conexao()
    initialize_database(database_url=url, seed=False)
    engine = create_engine(url)
    with engine.begin() as conn:
        carregar_operadoras(conn)
        remover_demonstracao(conn)
        carregar_beneficiarios(conn)
        carregar_contabil(conn)
    print("\nSUCESSO: carga ETL concluída com dados reais da ANS.")


if __name__ == "__main__":
    importar_dados()
