import os
import pandas as pd
from sqlalchemy import create_engine

def importar_dados():
    db_host = os.getenv('DB_HOST', 'localhost')
    db_user = os.getenv('DB_USER', 'root')
    db_pass = os.getenv('DB_PASSWORD', 'root')
    db_name = os.getenv('DB_NAME', 'intuitive_care')

    conn_string = f"mysql+pymysql://{db_user}:{db_pass}@{db_host}/{db_name}"
    engine = create_engine(conn_string)

    try:
        arquivo_operadoras = 'data/raw/Relatorio_cadop.csv'
        if os.path.exists(arquivo_operadoras):
            print(f"Lendo: {arquivo_operadoras} com UTF-8...")
            
            try:
                df_ops = pd.read_csv(arquivo_operadoras, sep=';', encoding='utf-8')
            except UnicodeDecodeError:
                print("UTF-8 falhou, tentando latin1...")
                df_ops = pd.read_csv(arquivo_operadoras, sep=';', encoding='latin1')
            
            df_ops.columns = df_ops.columns.str.strip()

            mapa_colunas = {
                'Registro ANS': 'registro_ans',
                'REGISTRO_OPERADORA': 'registro_ans',
                'Razão Social': 'razao_social',
                'Razao_Social': 'razao_social',
                'CNPJ': 'cnpj',
                'UF': 'uf',
                'Nome Fantasia': 'nome_fantasia',
                'Nome_Fantasia': 'nome_fantasia'
            }
            
            df_ops.rename(columns=mapa_colunas, inplace=True)
            
            df_ops = df_ops.loc[:, ~df_ops.columns.duplicated()]

            print("Salvando tabela 'operadoras'...")
            df_ops.to_sql('operadoras', con=engine, if_exists='replace', index=False)
        else:
            print(f"ERRO: Arquivo {arquivo_operadoras} não encontrado.")

        arquivo_despesas = 'data/despesas_enriquecidas.csv'
        if os.path.exists(arquivo_despesas):
            print(f"Lendo: {arquivo_despesas}")
            df_despesas = pd.read_csv(arquivo_despesas)
            
            df_despesas.rename(columns={
                'Valor Despesas': 'valor_despesa',
                'REG_ANS': 'reg_ans',
                'Ano': 'ano',
                'Trimestre': 'trimestre',
                'RazaoSocial': 'razao_social',
                'Modalidade': 'modalidade',
                'CNPJ': 'cnpj',
                'UF': 'uf'
            }, inplace=True)

            print("Salvando tabela 'despesas'...")
            df_despesas.to_sql('despesas', con=engine, if_exists='replace', index=False)
        else:
            print(f"ERRO: Arquivo {arquivo_despesas} não encontrado.")

        print("\nSUCESSO: Dados importados e caracteres corrigidos!")

    except Exception as e:
        print(f"Erro Crítico: {e}")

if __name__ == "__main__":
    importar_dados()