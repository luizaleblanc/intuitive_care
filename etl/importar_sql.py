import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import pandas as pd
from sqlalchemy import create_engine, text

from backend.database.init_db import initialize_database


def limpar_digitos(valor) -> str:
    if pd.isna(valor):
        return ""
    return re.sub(r"\D", "", str(valor))


def importar_dados():
    db_engine = os.getenv("DB_ENGINE", "mysql")
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "3307")
    db_user = os.getenv("DB_USER", "root")
    db_pass = os.getenv("DB_PASSWORD", "root")
    db_name = os.getenv("DB_NAME", "intuitive_care")

    if db_engine == "sqlite":
        sqlite_path = os.getenv("SQLITE_PATH", "backend/database/intuitive_care_local.db")
        conn_string = f"sqlite:///{sqlite_path}"
    else:
        conn_string = f"mysql+pymysql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}?charset=utf8mb4"

    initialize_database(database_url=conn_string, seed=False)
    engine = create_engine(conn_string)

    try:
        arquivo_operadoras = "data/raw/Relatorio_cadop.csv"
        if os.path.exists(arquivo_operadoras):
            print(f"Lendo: {arquivo_operadoras}...")
            try:
                df_ops = pd.read_csv(arquivo_operadoras, sep=";", encoding="utf-8")
            except UnicodeDecodeError:
                print("UTF-8 falhou, tentando latin1...")
                df_ops = pd.read_csv(arquivo_operadoras, sep=";", encoding="latin1")

            df_ops.columns = df_ops.columns.str.strip()
            mapa_colunas = {
                "Registro ANS": "registro_ans",
                "REGISTRO_OPERADORA": "registro_ans",
                "Razão Social": "razao_social",
                "Razao_Social": "razao_social",
                "CNPJ": "cnpj",
                "UF": "uf",
                "Nome Fantasia": "nome_fantasia",
                "Nome_Fantasia": "nome_fantasia",
                "Modalidade": "modalidade",
                "Logradouro": "logradouro",
                "Numero": "numero",
                "Complemento": "complemento",
                "Bairro": "bairro",
                "Cidade": "cidade",
                "CEP": "cep",
                "Telefone": "telefone",
                "Endereco_eletronico": "email",
                "Representante": "representante",
                "Cargo_Representante": "cargo_representante",
            }
            df_ops.rename(columns=mapa_colunas, inplace=True)
            df_ops = df_ops.loc[:, ~df_ops.columns.duplicated()]

            df_ops["registro_ans"] = df_ops["registro_ans"].apply(limpar_digitos)
            df_ops["cnpj"] = df_ops["cnpj"].apply(limpar_digitos).str.zfill(14)
            df_ops["uf"] = df_ops["uf"].fillna("NA").astype(str).str.strip().str.upper().str[:2]
            df_ops = df_ops[(df_ops["registro_ans"] != "") & (df_ops["cnpj"] != "0" * 14)]
            df_ops = df_ops.drop_duplicates(subset=["registro_ans"]).drop_duplicates(subset=["cnpj"])

            colunas_validas = [
                "registro_ans", "cnpj", "razao_social", "nome_fantasia", "modalidade",
                "logradouro", "numero", "complemento", "bairro", "cidade", "uf", "cep",
                "telefone", "email", "representante", "cargo_representante",
            ]
            for col in colunas_validas:
                if col not in df_ops.columns:
                    df_ops[col] = None

            print(f"Importando {len(df_ops)} operadoras preservando PK/FK...")
            with engine.begin() as conn:
                for record in df_ops[colunas_validas].where(pd.notnull(df_ops), None).to_dict(orient="records"):
                    exists = conn.execute(
                        text("SELECT 1 FROM operadoras WHERE registro_ans = :reg OR cnpj = :cnpj"),
                        {"reg": record["registro_ans"], "cnpj": record["cnpj"]},
                    ).first()
                    if not exists:
                        conn.execute(
                            text(
                                "INSERT INTO operadoras ("
                                "registro_ans, cnpj, razao_social, nome_fantasia, modalidade, "
                                "logradouro, numero, complemento, bairro, cidade, uf, cep, "
                                "telefone, email, representante, cargo_representante"
                                ") VALUES ("
                                ":registro_ans, :cnpj, :razao_social, :nome_fantasia, :modalidade, "
                                ":logradouro, :numero, :complemento, :bairro, :cidade, :uf, :cep, "
                                ":telefone, :email, :representante, :cargo_representante"
                                ")"
                            ),
                            record,
                        )
        else:
            print(f"AVISO: Arquivo {arquivo_operadoras} não encontrado.")

        arquivo_despesas = "data/despesas_enriquecidas.csv"
        if os.path.exists(arquivo_despesas):
            print(f"Lendo: {arquivo_despesas}...")
            df_despesas = pd.read_csv(arquivo_despesas)
            df_despesas.rename(
                columns={
                    "Valor Despesas": "valor_despesa",
                    "REG_ANS": "reg_ans",
                    "Ano": "ano",
                    "Trimestre": "trimestre",
                },
                inplace=True,
            )
            df_despesas["reg_ans"] = df_despesas["reg_ans"].apply(limpar_digitos)
            df_despesas["ano"] = pd.to_numeric(df_despesas["ano"], errors="coerce").fillna(0).astype(int)
            df_despesas["trimestre"] = pd.to_numeric(df_despesas["trimestre"], errors="coerce").fillna(1).astype(int)
            df_despesas["valor_despesa"] = pd.to_numeric(df_despesas["valor_despesa"], errors="coerce").fillna(0)
            df_despesas = df_despesas[df_despesas["valor_despesa"] > 0]

            with engine.begin() as conn:
                ops_existentes = {
                    row[0] for row in conn.execute(text("SELECT registro_ans FROM operadoras")).fetchall()
                }
                df_validas = df_despesas[df_despesas["reg_ans"].isin(ops_existentes)]
                print(f"Importando {len(df_validas)} despesas vinculadas às operadoras...")
                for row in df_validas[["reg_ans", "ano", "trimestre", "valor_despesa"]].to_dict(orient="records"):
                    conn.execute(
                        text(
                            "INSERT INTO despesas (reg_ans, ano, trimestre, valor_despesa, categoria, descricao) "
                            "VALUES (:reg_ans, :ano, :trimestre, :valor_despesa, 'Despesa Assistencial', 'Importação ETL ANS')"
                        ),
                        row,
                    )
        else:
            print(f"AVISO: Arquivo {arquivo_despesas} não encontrado.")

        print("\nSUCESSO: Carga ETL concluída mantendo integridade relacional!")

    except Exception as e:
        print(f"Erro Crítico na importação ETL: {e}")


if __name__ == "__main__":
    importar_dados()
