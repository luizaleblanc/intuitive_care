from typing import Optional

from sqlalchemy import text
from werkzeug.security import generate_password_hash

from backend.database.connection import get_connection


SQLITE_SCHEMA_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha_hash TEXT NOT NULL,
        perfil TEXT NOT NULL DEFAULT 'ANALISTA',
        ativo INTEGER NOT NULL DEFAULT 1,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS sessoes_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        token_jti TEXT NOT NULL UNIQUE,
        expira_em TIMESTAMP NOT NULL,
        revogado INTEGER NOT NULL DEFAULT 0,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS recuperacao_senha (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        codigo_hash TEXT NOT NULL,
        expira_em TIMESTAMP NOT NULL,
        utilizado INTEGER NOT NULL DEFAULT 0,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS operadoras (
        registro_ans TEXT PRIMARY KEY,
        cnpj TEXT NOT NULL UNIQUE,
        razao_social TEXT NOT NULL,
        nome_fantasia TEXT,
        modalidade TEXT,
        logradouro TEXT,
        numero TEXT,
        complemento TEXT,
        bairro TEXT,
        cidade TEXT,
        uf TEXT NOT NULL,
        cep TEXT,
        telefone TEXT,
        email TEXT,
        representante TEXT,
        cargo_representante TEXT,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS despesas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reg_ans TEXT NOT NULL,
        ano INTEGER NOT NULL,
        trimestre INTEGER NOT NULL,
        valor_despesa NUMERIC(15, 2) NOT NULL,
        categoria TEXT NOT NULL DEFAULT 'Despesa Assistencial',
        descricao TEXT,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (reg_ans) REFERENCES operadoras(registro_ans) ON DELETE RESTRICT ON UPDATE CASCADE
    )
    """,
]

MYSQL_SCHEMA_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS usuarios (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(120) NOT NULL,
        email VARCHAR(180) NOT NULL UNIQUE,
        senha_hash VARCHAR(255) NOT NULL,
        perfil VARCHAR(30) NOT NULL DEFAULT 'ANALISTA',
        ativo TINYINT(1) NOT NULL DEFAULT 1,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_usuarios_email (email)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS sessoes_tokens (
        id INT AUTO_INCREMENT PRIMARY KEY,
        usuario_id INT NOT NULL,
        token_jti VARCHAR(64) NOT NULL UNIQUE,
        expira_em DATETIME NOT NULL,
        revogado TINYINT(1) NOT NULL DEFAULT 0,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_sessoes_jti (token_jti),
        INDEX idx_sessoes_usuario (usuario_id),
        CONSTRAINT fk_sessoes_usuario
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
            ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS recuperacao_senha (
        id INT AUTO_INCREMENT PRIMARY KEY,
        usuario_id INT NOT NULL,
        codigo_hash VARCHAR(255) NOT NULL,
        expira_em DATETIME NOT NULL,
        utilizado TINYINT(1) NOT NULL DEFAULT 0,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_recuperacao_usuario (usuario_id),
        CONSTRAINT fk_recuperacao_usuario
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
            ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS operadoras (
        registro_ans VARCHAR(20) PRIMARY KEY,
        cnpj VARCHAR(14) NOT NULL UNIQUE,
        razao_social VARCHAR(255) NOT NULL,
        nome_fantasia VARCHAR(255),
        modalidade VARCHAR(120),
        logradouro VARCHAR(255),
        numero VARCHAR(30),
        complemento VARCHAR(120),
        bairro VARCHAR(120),
        cidade VARCHAR(120),
        uf CHAR(2) NOT NULL,
        cep VARCHAR(10),
        telefone VARCHAR(30),
        email VARCHAR(180),
        representante VARCHAR(150),
        cargo_representante VARCHAR(120),
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_operadoras_cnpj (cnpj),
        INDEX idx_operadoras_razao (razao_social),
        INDEX idx_operadoras_uf (uf)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS despesas (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reg_ans VARCHAR(20) NOT NULL,
        ano INT NOT NULL,
        trimestre TINYINT NOT NULL,
        valor_despesa DECIMAL(15, 2) NOT NULL,
        categoria VARCHAR(100) NOT NULL DEFAULT 'Despesa Assistencial',
        descricao VARCHAR(255),
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_despesas_reg_ans (reg_ans),
        INDEX idx_despesas_periodo (ano, trimestre),
        CONSTRAINT fk_despesas_operadora
            FOREIGN KEY (reg_ans) REFERENCES operadoras(registro_ans)
            ON DELETE RESTRICT ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
]


SEED_OPERADORAS = [
    ("326305", "00011122000183", "AMIL ASSISTENCIA MEDICA INTERNACIONAL S.A.", "AMIL SAUDE", "Medicina de Grupo", "Av. Brigadeiro Faria Lima", "1800", "10o Andar", "Jardim Paulistano", "São Paulo", "SP", "01451001", "(11) 3004-1000", "contato@amil.demo.br", "Carlos Eduardo Mendes", "Diretor Executivo"),
    ("368253", "11222333000181", "HAPVIDA ASSISTENCIA MEDICA S.A.", "HAPVIDA", "Medicina de Grupo", "Av. Heráclito Graça", "406", "Bloco A", "Centro", "Fortaleza", "CE", "60140060", "(85) 3200-4000", "atendimento@hapvida.demo.br", "Mariana Silva Costa", "Diretora Financeira"),
    ("302147", "22333444000181", "BRADESCO SAUDE S.A.", "BRADESCO SAUDE", "Seguradora Especializada em Saúde", "Rua Barão de Itapagipe", "225", "Torre Sul", "Rio Comprido", "Rio de Janeiro", "RJ", "20261005", "(21) 4004-2700", "relacionamento@bradescosaude.demo.br", "Roberto Almeida Prado", "Diretor de Operações"),
    ("359017", "33444555000181", "UNIMED JOAO PESSOA COOPERATIVA DE TRABALHO MEDICO", "UNIMED JP", "Cooperativa Médica", "Av. Marechal Deodoro da Fonseca", "420", "Ed. Sede", "Torre", "João Pessoa", "PB", "58040140", "(83) 2106-0500", "ouvidoria@unimedjp.demo.br", "Fernanda Oliveira Nóbrega", "Diretora Presidente"),
    ("343889", "44555666000181", "UNIMED BELO HORIZONTE COOPERATIVA DE TRABALHO MEDICO", "UNIMED BH", "Cooperativa Médica", "Av. Francisco Sales", "1483", "Sede Administrativa", "Santa Efigênia", "Belo Horizonte", "MG", "30150221", "(31) 3229-6000", "gestao@unimedbh.demo.br", "Henrique Ferreira Gomes", "Diretor Técnico"),
    ("319996", "55666777000181", "SUL AMERICA COMPANHIA DE SEGURO SAUDE", "SULAMERICA SAUDE", "Seguradora Especializada em Saúde", "Rua Beatriz Larragoiti Lucas", "121", "Ala Leste", "Cidade Nova", "Rio de Janeiro", "RJ", "20211903", "(21) 3003-8000", "canal@sulamerica.demo.br", "Patrícia Campos Rocha", "Vice-Presidente"),
    ("352501", "66777888000181", "UNIMED CURITIBA SOCIEDADE COOPERATIVA DE MEDICOS", "UNIMED CURITIBA", "Cooperativa Médica", "Av. Affonso Penna", "297", "Andar 4", "Tarumã", "Curitiba", "PR", "82530280", "(41) 3019-2000", "compliance@unimedcuritiba.demo.br", "Lucas Tavares Ribeiro", "Diretor Administrativo"),
    ("339679", "77888999000181", "NOTRE DAME INTERMEDICA SAUDE S.A.", "GNDI", "Medicina de Grupo", "Av. Paulista", "867", "Conj. 12", "Bela Vista", "São Paulo", "SP", "01311100", "(11) 3155-2000", "ans@gndi.demo.br", "Juliana Martins Vieira", "Diretora Regulatória"),
]

SEED_DESPESAS = [
    ("326305", 2024, 3, 185420310.45, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 3T2024"),
    ("326305", 2024, 4, 198310500.20, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 4T2024"),
    ("326305", 2025, 1, 204150980.00, "Eventos Indenizáveis Líquidos", "Atendimento médico-hospitalar 1T2025"),
    ("368253", 2024, 3, 112450890.10, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 3T2024"),
    ("368253", 2024, 4, 121980430.75, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 4T2024"),
    ("368253", 2025, 1, 129540120.30, "Despesa Assistencial", "Sinistralidade rede própria e credenciada 1T2025"),
    ("302147", 2024, 3, 245890100.00, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 3T2024"),
    ("302147", 2024, 4, 261420300.50, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 4T2024"),
    ("302147", 2025, 1, 272100850.90, "Eventos Indenizáveis Líquidos", "Reembolsos e rede referenciada 1T2025"),
    ("359017", 2024, 3, 28450120.40, "Despesa Assistencial", "Internações e exames complementares PB 3T2024"),
    ("359017", 2024, 4, 31200450.80, "Despesa Assistencial", "Internações e exames complementares PB 4T2024"),
    ("359017", 2025, 1, 33890710.15, "Despesa Assistencial", "Internações e exames complementares PB 1T2025"),
    ("343889", 2024, 3, 94500210.00, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 3T2024"),
    ("343889", 2024, 4, 98750600.25, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 4T2024"),
    ("343889", 2025, 1, 103420900.60, "Despesa Assistencial", "Procedimentos ambulatoriais e hospitalares MG 1T2025"),
    ("319996", 2024, 3, 154320800.00, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 3T2024"),
    ("319996", 2024, 4, 162180400.35, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 4T2024"),
    ("319996", 2025, 1, 169450220.80, "Eventos Indenizáveis Líquidos", "Despesas assistenciais SulAmérica 1T2025"),
    ("352501", 2024, 3, 62310450.00, "Despesa Assistencial", "Custos assistenciais cooperados PR 3T2024"),
    ("352501", 2024, 4, 66840910.45, "Despesa Assistencial", "Custos assistenciais cooperados PR 4T2024"),
    ("352501", 2025, 1, 70120300.10, "Despesa Assistencial", "Custos assistenciais cooperados PR 1T2025"),
    ("339679", 2024, 3, 173200500.00, "Despesa Assistencial", "Rede assistencial integrada SP 3T2024"),
    ("339679", 2024, 4, 181900750.25, "Despesa Assistencial", "Rede assistencial integrada SP 4T2024"),
    ("339679", 2025, 1, 190450320.70, "Despesa Assistencial", "Rede assistencial integrada SP 1T2025"),
]


def initialize_database(database_url: Optional[str] = None, seed: bool = True) -> None:
    """Cria as tabelas caso não existam e popula massa inicial demonstrativa se vazio."""
    with get_connection(database_url) as conn:
        dialect = conn.dialect.name
        statements = SQLITE_SCHEMA_STATEMENTS if dialect == "sqlite" else MYSQL_SCHEMA_STATEMENTS
        for stmt in statements:
            conn.execute(text(stmt))

        if not seed:
            return

        users_count = conn.execute(text("SELECT COUNT(*) FROM usuarios")).scalar_one()
        if users_count == 0:
            conn.execute(
                text(
                    "INSERT INTO usuarios (nome, email, senha_hash, perfil, ativo) "
                    "VALUES (:nome, :email, :senha_hash, :perfil, 1)"
                ),
                {
                    "nome": "Luiza Leblanc (Analista ANS)",
                    "email": "admin@intuitivecare.com.br",
                    "senha_hash": generate_password_hash("Senha@123", method="pbkdf2:sha256"),
                    "perfil": "ADMIN",
                },
            )

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
