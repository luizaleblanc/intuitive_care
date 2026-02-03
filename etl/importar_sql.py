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
            df_ops = pd.read_csv(arquivo_operadoras, sep=';', encoding='latin1')
            
            df_ops.columns = df_ops.columns.str.strip()
            
            df_ops.rename(columns={
                'Razão Social': 'razao_social', 
                'CNPJ': 'cnpj', 
                'Registro ANS': 'registro_ans',
                'Logradouro': 'logradouro',
                'Numero': 'numero',
                'Complemento': 'complemento',
                'Bairro': 'bairro',
                'Cidade': 'cidade',
                'UF': 'uf',
                'CEP': 'cep',
                'DDD': 'ddd',
                'Telefone': 'telefone',
                'Fax': 'fax',
                'Endereço eletrônico': 'email',
                'Representante': 'representante',
                'Cargo Representante': 'cargo_representante',
                'Data Registro ANS': 'data_registro_ans'
            }, inplace=True)
            
            df_ops.to_sql('operadoras', con=engine, if_exists='replace', index=False)
            print("Tabela 'operadoras' importada com sucesso.")
        else:
            print(f"Arquivo {arquivo_operadoras} não encontrado.")

        arquivo_despesas = 'data/despesas_enriquecidas.csv'
        if os.path.exists(arquivo_despesas):
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

            df_despesas.to_sql('despesas', con=engine, if_exists='replace', index=False)
            print("Tabela 'despesas' importada com sucesso.")
        else:
            print(f"Arquivo {arquivo_despesas} não encontrado.")

    except Exception as e:
        print(f"Erro: {e}")

if __name__ == "__main__":
    importar_dados()