import pandas as pd
from sqlalchemy import create_engine

USER = "root"            
PASSWORD = "password123"    
HOST = "localhost"
DATABASE = "intuitive_care"

try:
    engine = create_engine(f"mysql+mysqlconnector://{USER}:{PASSWORD}@{HOST}/{DATABASE}")
    print("Conexão com o banco estabelecida!")
except Exception as e:
    print(f"Erro de conexão: {e}")
    exit()

def importar_dados():
    print("A ler ficheiro enriquecido...")
    try:
        df = pd.read_csv("data/despesas_enriquecidas.csv")
        
        print("A inserir operadoras...")
        df_ops = df[['REG_ANS', 'CNPJ', 'RazaoSocial', 'Modalidade', 'UF']].drop_duplicates(subset=['REG_ANS'])
        
        df_ops.columns = ['reg_ans', 'cnpj', 'razao_social', 'modalidade', 'uf']
        
        df_ops.to_sql('operadoras', con=engine, if_exists='append', index=False, chunksize=1000)
        
        print("A inserir despesas (pode demorar alguns segundos)...")
        df_desp = df[['REG_ANS', 'Trimestre', 'Ano', 'Valor Despesas']]
        df_desp.columns = ['reg_ans', 'trimestre', 'ano', 'valor_despesa']
        
        df_desp.to_sql('despesas', con=engine, if_exists='append', index=False, chunksize=1000)
        
        print("SUCESSO! Todos os dados foram migrados para o MySQL.")
        
    except Exception as e:
        print(f"Erro na importação: {e}")

if __name__ == "__main__":
    importar_dados()