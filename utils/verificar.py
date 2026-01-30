import pandas as pd
from sqlalchemy import create_engine

# --- ÁREA DE CONFIGURAÇÃO (Preencha com seus dados) ---
# DICA: Olhe no seu docker-compose.yml ou no importar_sql.py
DB_USER = 'root'           # Geralmente 'root'
DB_PASS = 'root'           # A senha definida no docker-compose (MYSQL_ROOT_PASSWORD)
DB_HOST = 'localhost'      # Use 'localhost' pq você está rodando o script do Windows
DB_PORT = '3306'           # A porta exposta (ports) no docker-compose
DB_NAME = 'intuitive_db'   # O nome do banco de dados

# -------------------------------------------------------

def verificar():
    # Monta a string de conexão (Connection String)
    # Formato: mysql+pymysql://usuario:senha@host:porta/banco
    conn_string = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    
    print(f"🔌 Tentando conectar em: {conn_string.replace(DB_PASS, '******')} ...")

    try:
        engine = create_engine(conn_string)
        
        # 1. Tenta listar as tabelas para ver se o banco existe
        tabelas = pd.read_sql("SHOW TABLES;", engine)
        print("\n📂 Tabelas encontradas no banco:")
        if tabelas.empty:
            print("   (Nenhuma tabela encontrada. O banco está vazio!)")
        else:
            print(tabelas)
            
            # 2. Se tiver tabelas, conta as linhas da tabela 'despesas'
            # (Se sua tabela tiver outro nome, mude 'despesas' abaixo)
            if 'despesas' in tabelas.values:
                contagem = pd.read_sql("SELECT COUNT(*) as total FROM despesas;", engine)
                total = contagem['total'][0]
                print(f"\n📊 Total de linhas na tabela 'despesas': {total}")
            else:
                print("\n⚠️ A tabela 'despesas' NÃO foi encontrada.")

    except Exception as e:
        print("\n❌ ERRO AO CONECTAR:")
        print(e)
        print("\nCHECKLIST DE ERRO:")
        print("1. O Docker está rodando? (comando: docker ps)")
        print("2. A senha/usuário estão iguais ao docker-compose.yml?")
        print("3. O nome do banco (DB_NAME) existe?")

if __name__ == "__main__":
    verificar()