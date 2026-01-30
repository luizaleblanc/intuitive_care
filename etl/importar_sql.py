import pandas as pd
from sqlalchemy import create_engine, text
import os

DB_USER = 'root'
DB_PASS = 'root'
DB_HOST = 'localhost'
DB_PORT = '3307'
DB_NAME = 'intuitive_care'

def importar_dados():
    print("Iniciando importação para o Docker...")
    
    conn_string = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(conn_string)

    print("Limpando tabela 'despesas' antiga...")
    with engine.connect() as conn:
        try:
            conn.execute(text("DELETE FROM despesas"))
            conn.commit()
        except:
            pass
    arq_desp = 'data/despesas_enriquecidas.csv'
    
    if os.path.exists(arq_desp):
        print(f"Lendo {arq_desp}...")
        df_desp = pd.read_csv(arq_desp)
    
        print("Ajustando nomes das colunas...")
        df_desp = df_desp.rename(columns={
            'REG_ANS': 'reg_ans',
            'Trimestre': 'trimestre',
            'Ano': 'ano',
            'Valor Despesas': 'valor_despesa'  
        })
        
        colunas_finais = ['reg_ans', 'trimestre', 'ano', 'valor_despesa']
        
        if set(colunas_finais).issubset(df_desp.columns):
            df_desp = df_desp[colunas_finais]
        
        print(f"Salvando {len(df_desp)} linhas no MySQL...")
        
        df_desp.to_sql('despesas', con=engine, if_exists='replace', index=False)
        
        print("SUCESSO! Dados importados.")
    else:
        print(f"ERRO: Arquivo {arq_desp} não encontrado!")

if __name__ == "__main__":
    importar_dados()