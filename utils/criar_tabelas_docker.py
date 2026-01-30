import mysql.connector

db_config = {
    'user': 'root',
    'password': 'root',     
    'host': '127.0.0.1',
    'port': 3307,           
    'database': 'intuitive_care'
}

print("Conectando ao banco do Docker...")
conn = mysql.connector.connect(**db_config)
cursor = conn.cursor()

tabelas = [
    """
    CREATE TABLE IF NOT EXISTS operadoras (
        reg_ans VARCHAR(20) PRIMARY KEY,
        cnpj VARCHAR(20),
        razao_social VARCHAR(255),
        modalidade VARCHAR(100),
        uf CHAR(2)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS despesas (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reg_ans VARCHAR(20),
        trimestre INT,
        ano INT,
        valor_despesa DECIMAL(15, 2),
        INDEX idx_reg_ans (reg_ans)
    )
    """
]

for sql in tabelas:
    cursor.execute(sql)

conn.commit()
print("Sucesso! Tabelas criadas no Docker.")
cursor.close()
conn.close()