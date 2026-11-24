"""Inicialização, migração idempotente de schema, sincronização RBAC e carga de demonstração."""
from sqlalchemy import text
from werkzeug.security import check_password_hash, generate_password_hash

from backend.database.connection import get_connection
from backend.database.ddl_statements import (
    COLUNAS_ADICIONAIS,
    MYSQL_SCHEMA_STATEMENTS,
    SQLITE_SCHEMA_STATEMENTS,
)
from backend.database.seed_data import SEED_DESPESAS, SEED_OPERADORAS, USUARIOS_DEMONSTRACAO
from backend.models.permissoes import PERFIS, PERMISSOES

__all__ = [
    "SQLITE_SCHEMA_STATEMENTS",
    "MYSQL_SCHEMA_STATEMENTS",
    "COLUNAS_ADICIONAIS",
    "USUARIOS_DEMONSTRACAO",
    "SEED_OPERADORAS",
    "SEED_DESPESAS",
    "migrar_schema",
    "sincronizar_permissoes",
    "garantir_usuarios_demonstracao",
    "initialize_database",
]


def _colunas_existentes(conn, tabela: str) -> set:
    if conn.dialect.name == "sqlite":
        return {r[1] for r in conn.execute(text(f"PRAGMA table_info({tabela})")).all()}
    return {
        r[0]
        for r in conn.execute(
            text(
                "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t"
            ),
            {"t": tabela},
        ).all()
    }


def migrar_schema(conn) -> None:
    sqlite = conn.dialect.name == "sqlite"
    for tabela, colunas in COLUNAS_ADICIONAIS.items():
        existentes = _colunas_existentes(conn, tabela)
        for nome, tipo_mysql, tipo_sqlite in colunas:
            if nome not in existentes:
                conn.execute(text(f"ALTER TABLE {tabela} ADD COLUMN {nome} {tipo_sqlite if sqlite else tipo_mysql}"))
    # Perfil legado "ANALISTA" passa a ser "COLABORADOR" (somente leitura).
    conn.execute(text("UPDATE usuarios SET perfil = 'COLABORADOR' WHERE perfil NOT IN ('ADMIN', 'COLABORADOR')"))
    sincronizar_permissoes(conn)
    # No MySQL/TiDB, o perfil do usuário só aceita valores cadastrados em perfis_acesso.
    if not sqlite:
        existe = conn.execute(
            text(
                "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuarios' AND CONSTRAINT_NAME = 'fk_usuario_perfil'"
            )
        ).scalar()
        if not existe:
            conn.execute(
                text(
                    "ALTER TABLE usuarios ADD CONSTRAINT fk_usuario_perfil "
                    "FOREIGN KEY (perfil) REFERENCES perfis_acesso(perfil)"
                )
            )


def sincronizar_permissoes(conn) -> None:
    """Grava no banco as regras de backend/models/permissoes.py (fonte única)."""
    conn.execute(text("DELETE FROM permissoes_perfil"))
    for perfil, (nome, descricao) in PERFIS.items():
        atualizado = conn.execute(
            text("UPDATE perfis_acesso SET nome = :n, descricao = :d WHERE perfil = :p"),
            {"p": perfil, "n": nome, "d": descricao},
        )
        if atualizado.rowcount == 0:
            conn.execute(
                text("INSERT INTO perfis_acesso (perfil, nome, descricao) VALUES (:p, :n, :d)"),
                {"p": perfil, "n": nome, "d": descricao},
            )
    for codigo, (descricao, perfis) in PERMISSOES.items():
        for perfil in perfis:
            conn.execute(
                text("INSERT INTO permissoes_perfil (perfil, permissao, descricao) VALUES (:p, :c, :d)"),
                {"p": perfil, "c": codigo, "d": descricao},
            )


def garantir_usuarios_demonstracao(conn) -> None:
    # Perfil "Consumidor" foi renomeado para "Colaborador": migra a conta de demonstração antiga.
    antigo = conn.execute(text("SELECT id FROM usuarios WHERE LOWER(email) = 'consumidor@intuitivecare.com.br'")).first()
    novo = conn.execute(text("SELECT id FROM usuarios WHERE LOWER(email) = 'colaborador@intuitivecare.com.br'")).first()
    if antigo and not novo:
        conn.execute(
            text("UPDATE usuarios SET email = 'colaborador@intuitivecare.com.br', senha_hash = :h WHERE id = :id"),
            {"h": generate_password_hash("Colaborador@2025", method="pbkdf2:sha256"), "id": antigo[0]},
        )
    for u in USUARIOS_DEMONSTRACAO:
        row = conn.execute(
            text("SELECT id, senha_hash FROM usuarios WHERE LOWER(email) = :e"), {"e": u["email"]}
        ).first()
        if row is None:
            conn.execute(
                text(
                    "INSERT INTO usuarios (nome, email, senha_hash, perfil, ativo, cargo) "
                    "VALUES (:nome, :email, :h, :perfil, 1, :cargo)"
                ),
                {**u, "h": generate_password_hash(u["senha"], method="pbkdf2:sha256")},
            )
        else:
            conn.execute(
                text("UPDATE usuarios SET perfil = :perfil, cargo = COALESCE(cargo, :cargo) WHERE id = :id"),
                {"perfil": u["perfil"], "cargo": u["cargo"], "id": row[0]},
            )
            # Migra a senha legada da conta de demonstração para a do MVP.
            if u["perfil"] == "ADMIN" and check_password_hash(row[1], "Senha@123"):
                conn.execute(
                    text("UPDATE usuarios SET senha_hash = :h WHERE id = :id"),
                    {"h": generate_password_hash(u["senha"], method="pbkdf2:sha256"), "id": row[0]},
                )


def _popular_seed_inicial(conn) -> None:
    ops_count = conn.execute(text("SELECT COUNT(*) FROM operadoras")).scalar_one()
    if ops_count == 0:
        for op in SEED_OPERADORAS:
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
                {
                    "registro_ans": op[0],
                    "cnpj": op[1],
                    "razao_social": op[2],
                    "nome_fantasia": op[3],
                    "modalidade": op[4],
                    "logradouro": op[5],
                    "numero": op[6],
                    "complemento": op[7],
                    "bairro": op[8],
                    "cidade": op[9],
                    "uf": op[10],
                    "cep": op[11],
                    "telefone": op[12],
                    "email": op[13],
                    "representante": op[14],
                    "cargo_representante": op[15],
                },
            )

    desp_count = conn.execute(text("SELECT COUNT(*) FROM despesas")).scalar_one()
    if desp_count == 0:
        for d in SEED_DESPESAS:
            conn.execute(
                text(
                    "INSERT INTO despesas (reg_ans, ano, trimestre, valor_despesa, categoria, descricao) "
                    "VALUES (:reg_ans, :ano, :trimestre, :valor_despesa, :categoria, :descricao)"
                ),
                {
                    "reg_ans": d[0],
                    "ano": d[1],
                    "trimestre": d[2],
                    "valor_despesa": d[3],
                    "categoria": d[4],
                    "descricao": d[5],
                },
            )


def initialize_database(database_url=None, seed: bool = True, demo: bool = True) -> None:
    """Cria as tabelas caso não existam e popula massa inicial demonstrativa se vazio."""
    with get_connection(database_url) as conn:
        dialect = conn.dialect.name
        statements = SQLITE_SCHEMA_STATEMENTS if dialect == "sqlite" else MYSQL_SCHEMA_STATEMENTS
        for stmt in statements:
            conn.execute(text(stmt))
        migrar_schema(conn)
        if demo:
            garantir_usuarios_demonstracao(conn)
        if seed:
            _popular_seed_inicial(conn)
