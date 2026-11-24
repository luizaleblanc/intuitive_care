"""Definições SQL (DDL) e colunas de migração idempotente para SQLite e MySQL/TiDB."""

SQLITE_SCHEMA_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        senha_hash TEXT NOT NULL,
        perfil TEXT NOT NULL DEFAULT 'COLABORADOR',
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
    """
    CREATE TABLE IF NOT EXISTS demonstracoes_operadora (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reg_ans TEXT NOT NULL,
        ano INTEGER NOT NULL,
        trimestre INTEGER NOT NULL,
        contraprestacoes NUMERIC(18, 2) NOT NULL DEFAULT 0,
        eventos NUMERIC(18, 2) NOT NULL DEFAULT 0,
        eventos_mh NUMERIC(18, 2) NOT NULL DEFAULT 0,
        comercializacao NUMERIC(18, 2) NOT NULL DEFAULT 0,
        administrativas NUMERIC(18, 2) NOT NULL DEFAULT 0,
        UNIQUE (reg_ans, ano, trimestre)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS contas_setor (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ano INTEGER NOT NULL,
        trimestre INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        descricao TEXT NOT NULL,
        nivel INTEGER NOT NULL,
        valor NUMERIC(18, 2) NOT NULL DEFAULT 0,
        UNIQUE (ano, trimestre, codigo)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS beneficiarios_trimestre (
        reg_ans TEXT NOT NULL,
        ano INTEGER NOT NULL,
        trimestre INTEGER NOT NULL,
        medico_hospitalar INTEGER NOT NULL DEFAULT 0,
        odontologico INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (reg_ans, ano, trimestre)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS lotes_etl (
        ano INTEGER NOT NULL,
        trimestre INTEGER NOT NULL,
        registros_extraidos INTEGER NOT NULL DEFAULT 0,
        operadoras INTEGER NOT NULL DEFAULT 0,
        carregado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        auditado INTEGER NOT NULL DEFAULT 0,
        auditado_por TEXT,
        auditado_em TIMESTAMP,
        PRIMARY KEY (ano, trimestre)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS tokens_reset_senha (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expira_em TIMESTAMP NOT NULL,
        usado_em TIMESTAMP,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS pedidos_reset_senha (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email_hash TEXT NOT NULL,
        criado_em TIMESTAMP NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS perfis_acesso (
        perfil TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        descricao TEXT NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS permissoes_perfil (
        perfil TEXT NOT NULL,
        permissao TEXT NOT NULL,
        descricao TEXT NOT NULL,
        PRIMARY KEY (perfil, permissao),
        FOREIGN KEY (perfil) REFERENCES perfis_acesso(perfil) ON DELETE CASCADE
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
        perfil VARCHAR(30) NOT NULL DEFAULT 'COLABORADOR',
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
    """
    CREATE TABLE IF NOT EXISTS demonstracoes_operadora (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reg_ans VARCHAR(20) NOT NULL,
        ano INT NOT NULL,
        trimestre TINYINT NOT NULL,
        contraprestacoes DECIMAL(18, 2) NOT NULL DEFAULT 0,
        eventos DECIMAL(18, 2) NOT NULL DEFAULT 0,
        eventos_mh DECIMAL(18, 2) NOT NULL DEFAULT 0,
        comercializacao DECIMAL(18, 2) NOT NULL DEFAULT 0,
        administrativas DECIMAL(18, 2) NOT NULL DEFAULT 0,
        UNIQUE KEY uq_demonstracao (reg_ans, ano, trimestre),
        INDEX idx_demonstracao_periodo (ano, trimestre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS contas_setor (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ano INT NOT NULL,
        trimestre TINYINT NOT NULL,
        codigo VARCHAR(12) NOT NULL,
        descricao VARCHAR(255) NOT NULL,
        nivel TINYINT NOT NULL,
        valor DECIMAL(18, 2) NOT NULL DEFAULT 0,
        UNIQUE KEY uq_conta_periodo (ano, trimestre, codigo)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS beneficiarios_trimestre (
        reg_ans VARCHAR(20) NOT NULL,
        ano INT NOT NULL,
        trimestre TINYINT NOT NULL,
        medico_hospitalar INT NOT NULL DEFAULT 0,
        odontologico INT NOT NULL DEFAULT 0,
        PRIMARY KEY (reg_ans, ano, trimestre),
        INDEX idx_benef_periodo (ano, trimestre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS lotes_etl (
        ano INT NOT NULL,
        trimestre TINYINT NOT NULL,
        registros_extraidos INT NOT NULL DEFAULT 0,
        operadoras INT NOT NULL DEFAULT 0,
        carregado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        auditado TINYINT(1) NOT NULL DEFAULT 0,
        auditado_por VARCHAR(120),
        auditado_em DATETIME,
        PRIMARY KEY (ano, trimestre)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS tokens_reset_senha (
        id INT AUTO_INCREMENT PRIMARY KEY,
        usuario_id INT NOT NULL,
        token_hash CHAR(64) NOT NULL UNIQUE,
        expira_em DATETIME NOT NULL,
        usado_em DATETIME NULL,
        criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT fk_token_reset_usuario
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
            ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS pedidos_reset_senha (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email_hash CHAR(64) NOT NULL,
        criado_em DATETIME NOT NULL,
        INDEX idx_pedidos_reset (email_hash, criado_em)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS perfis_acesso (
        perfil VARCHAR(30) PRIMARY KEY,
        nome VARCHAR(60) NOT NULL,
        descricao VARCHAR(255) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
    """
    CREATE TABLE IF NOT EXISTS permissoes_perfil (
        perfil VARCHAR(30) NOT NULL,
        permissao VARCHAR(60) NOT NULL,
        descricao VARCHAR(255) NOT NULL,
        PRIMARY KEY (perfil, permissao),
        CONSTRAINT fk_permissao_perfil FOREIGN KEY (perfil) REFERENCES perfis_acesso(perfil) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    """,
]

# Colunas adicionadas após a versão inicial do schema (migração idempotente).
COLUNAS_ADICIONAIS = {
    "usuarios": [
        ("cargo", "VARCHAR(120)", "TEXT"),
        ("telefone", "VARCHAR(30)", "TEXT"),
        ("data_nascimento", "DATE", "DATE"),
        ("foto", "MEDIUMTEXT", "TEXT"),
        ("preferencias", "TEXT", "TEXT"),
        ("ultimo_acesso", "DATETIME", "TIMESTAMP"),
    ],
    "operadoras": [
        ("status", "VARCHAR(20) NOT NULL DEFAULT 'Ativa'", "TEXT NOT NULL DEFAULT 'Ativa'"),
        ("beneficiarios", "INT NOT NULL DEFAULT 0", "INTEGER NOT NULL DEFAULT 0"),
        ("beneficiarios_mh", "INT NOT NULL DEFAULT 0", "INTEGER NOT NULL DEFAULT 0"),
        ("data_descredenciamento", "DATE", "DATE"),
    ],
}
