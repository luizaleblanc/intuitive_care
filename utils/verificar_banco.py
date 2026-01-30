import pandas as pd
from sqlalchemy import create_engine

DB_USER = 'root'
DB_PASS = 'root'
DB_HOST = 'localhost'
DB_PORT = '3307'
DB_NAME = 'intuitive_care'

def verificar():
    conn_string = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    
    print(f"🔌 Conectando em: localhost:{DB_PORT}/{DB_NAME} ...")

    try:
        engine = create_engine(conn_string)
        
        tabelas = pd.read_sql("SHOW TABLES;", engine)
        print("\n📂 Tabelas encontradas:")
        
        if tabelas.empty:
            print("   (Banco vazio)")
        else:
            print(tabelas)
            
            check_tabela = tabelas.isin(['despesas']).any().any()
            
            if check_tabela:
                df = pd.read_sql("SELECT COUNT(*) as total FROM despesas;", engine)
                print(f"\n📊 Total de linhas em 'despesas': {df['total'][0]}")
            else:
                print("\n⚠️ Tabela 'despesas' não encontrada.")

    except Exception as e:
        print(f"\n❌ Erro: {e}")

if __name__ == "__main__":
    verificar()