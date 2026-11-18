"""Copia os dados públicos do MySQL local para o banco de homologação (TiDB Cloud).

Uso:
    python utils/migrar_para_nuvem.py --host HOST --usuario USUARIO --admin-email SEU_EMAIL

As senhas são pedidas no terminal e não ficam gravadas. Usuários, sessões e tokens
locais NÃO são copiados: o destino recebe apenas um administrador novo.
"""
import argparse
import getpass
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, inspect, text  # noqa: E402
from sqlalchemy.engine import URL  # noqa: E402
from werkzeug.security import generate_password_hash  # noqa: E402

from backend.config import Config  # noqa: E402
from backend.database.connection import get_connection, reset_engine  # noqa: E402
from backend.database.init_db import initialize_database  # noqa: E402
from backend.services.validators import validate_email, validate_password  # noqa: E402

# Ordem de inserção respeita as chaves estrangeiras.
TABELAS = (
    "operadoras",
    "despesas",
    "demonstracoes_operadora",
    "contas_setor",
    "beneficiarios_trimestre",
    "lotes_etl",
)
LOTE = 500


def migrar(origem_url, destino_url, admin_email, admin_senha):
    initialize_database(destino_url, seed=False, demo=False)
    origem = create_engine(origem_url)
    totais = {}
    try:
        with origem.connect() as fonte, get_connection(destino_url) as destino:
            colunas_destino = {t: {c["name"] for c in inspect(destino).get_columns(t)} for t in TABELAS}
            for tabela in reversed(TABELAS):
                destino.execute(text(f"DELETE FROM {tabela}"))
            for tabela in TABELAS:
                resultado = fonte.execute(text(f"SELECT * FROM {tabela}")).mappings()
                colunas = [c for c in resultado.keys() if c in colunas_destino[tabela]]
                insert = text(
                    f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES ({', '.join(':' + c for c in colunas)})"
                )
                total = 0
                while True:
                    lote = resultado.fetchmany(LOTE)
                    if not lote:
                        break
                    destino.execute(insert, [{c: linha[c] for c in colunas} for linha in lote])
                    total += len(lote)
                totais[tabela] = total
                print(f"{tabela}: {total} registros", flush=True)

            senha_hash = generate_password_hash(admin_senha, method="pbkdf2:sha256")
            atualizado = destino.execute(
                text("UPDATE usuarios SET senha_hash = :h, perfil = 'ADMIN', ativo = 1 WHERE LOWER(email) = :e"),
                {"h": senha_hash, "e": admin_email},
            )
            if atualizado.rowcount == 0:
                destino.execute(
                    text(
                        "INSERT INTO usuarios (nome, email, senha_hash, perfil, ativo) "
                        "VALUES ('Administrador', :e, :h, 'ADMIN', 1)"
                    ),
                    {"h": senha_hash, "e": admin_email},
                )
    finally:
        origem.dispose()
        reset_engine()
    return totais


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--usuario", required=True)
    parser.add_argument("--admin-email", required=True)
    parser.add_argument("--porta", type=int, default=4000)
    parser.add_argument("--banco", default="intuitive_care")
    args = parser.parse_args()

    if not args.host.endswith(".tidbcloud.com"):
        parser.error("O destino precisa ser um host do TiDB Cloud.")
    if not args.banco.replace("_", "").isalnum():
        parser.error("Nome de banco inválido.")

    admin_email = validate_email(args.admin_email)
    senha_banco = getpass.getpass("Senha do TiDB (não aparece ao digitar): ")
    admin_senha = validate_password(getpass.getpass("Nova senha do administrador da homologação: "))

    base = URL.create(
        "mysql+pymysql", args.usuario, senha_banco, args.host, args.porta, query={"charset": "utf8mb4"}
    )
    from backend.database.connection import argumentos_conexao

    servidor = create_engine(base, connect_args=argumentos_conexao(base))
    with servidor.begin() as conn:
        conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{args.banco}` CHARACTER SET utf8mb4"))
    servidor.dispose()

    totais = migrar(Config.get_database_url(), base.set(database=args.banco), admin_email, admin_senha)
    print(f"Concluído: {sum(totais.values())} registros copiados e administrador configurado.")


if __name__ == "__main__":
    main()
