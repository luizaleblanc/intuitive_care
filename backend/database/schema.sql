-- ============================================================================
-- Schema Oficial - Intuitive Care (MySQL 8.0)
-- Disciplinas: Códigos de Alta Performance / Backend Frameworks
-- ============================================================================

CREATE DATABASE IF NOT EXISTS intuitive_care
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE intuitive_care;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
