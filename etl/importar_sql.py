import pandas as pd
from sqlalchemy import create_engine, text
import os

DB_USER = 'root'
DB_PASS = 'root'
DB_HOST = 'localhost'
DB_PORT = '3307'
DB_NAME = 'intuitive_care'

def importar_dados():
    print("Iniciando importação COMPLETA (Operadoras + Despesas)...")
    
    conn_string = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(conn_string)

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    arq_csv = os.path.join(base_dir, 'data', 'despesas_enriquecidas.csv')
    
    if not os.path.exists(arq_csv):
        print(f"ERRO: Arquivo não encontrado: {arq_csv}")
        return

    print(f"Lendo arquivo: {arq_csv}...")
    df_geral = pd.read_csv(arq_csv)

    print("Tratando dados de OPERADORAS...")
    colunas_ops = {
        'REG_ANS': 'reg_ans',
        'CNPJ': 'cnpj', 
        'RazaoSocial': 'razao_social',
        'Modalidade': 'modalidade',
        'UF': 'uf'
    }
    
    cols_existentes_ops = [c for c in colunas_ops.keys() if c in df_geral.columns]
    df_ops = df_geral[cols_existentes_ops].copy()
    df_ops = df_ops.rename(columns=colunas_ops)
    df_ops = df_ops.drop_duplicates(subset=['reg_ans']) 

    print(f"Salvando {len(df_ops)} operadoras no MySQL...")
    df_ops.to_sql('operadoras', con=engine, if_exists='replace', index=False)

    print("Tratando dados de DESPESAS...")
    colunas_desp = {
        'REG_ANS': 'reg_ans', 
        'Trimestre': 'trimestre', 
        'Ano': 'ano', 
        'Valor Despesas': 'valor_despesa'
    }
    
    cols_existentes_desp = [c for c in colunas_desp.keys() if c in df_geral.columns]
    df_desp = df_geral[cols_existentes_desp].copy()
    df_desp = df_desp.rename(columns=colunas_desp)

    print(f" Salvando {len(df_desp)} despesas no MySQL...")
    df_desp.to_sql('despesas', con=engine, if_exists='replace', index=False)
    
    print("\n SUCESSO ABSOLUTO! O Banco está 100% carregado.")

if __name__ == "__main__":
    importar_dados()