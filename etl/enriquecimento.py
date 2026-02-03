import pandas as pd
import os

def enriquecer_dados():
    arquivo_despesas = os.path.join('data', 'consolidado_despesas.csv')
    arquivo_operadoras = os.path.join('data', 'raw', 'Relatorio_cadop.csv')
    saida_enriquecida = os.path.join('data', 'despesas_enriquecidas.csv')
    saida_agregada = os.path.join('data', 'despesas_agregadas.csv')

    if not os.path.exists(arquivo_despesas):
        print(f"ERRO: Arquivo não encontrado: {arquivo_despesas}")
        return
    
    if not os.path.exists(arquivo_operadoras):
        print(f"ERRO: Arquivo não encontrado: {arquivo_operadoras}")
        return

    print("Carregando arquivos...")
    
    try:
        df_despesas = pd.read_csv(arquivo_despesas)
        print(f"Colunas originais em Despesas: {list(df_despesas.columns)}")
        
        mapa_despesas = {
            'REG_ANS': 'reg_ans',
            'RegistroANS': 'reg_ans',
            'Valor Despesas': 'valor_despesa',  
            'Valor_Despesas': 'valor_despesa',
            'Trimestre': 'trimestre',
            'Ano': 'ano'
        }
        df_despesas.rename(columns=mapa_despesas, inplace=True)
        
        try:
            df_ops = pd.read_csv(arquivo_operadoras, sep=';', encoding='utf-8')
        except UnicodeDecodeError:
            df_ops = pd.read_csv(arquivo_operadoras, sep=';', encoding='latin1')
            
        print(f"Colunas originais em Operadoras: {list(df_ops.columns)}")

        df_ops.columns = df_ops.columns.str.strip()
        
        mapa_colunas_ops = {
            'Registro ANS': 'reg_ans',
            'REGISTRO_OPERADORA': 'reg_ans',
            'CD_OPERADORA': 'reg_ans',
            'Razão Social': 'RazaoSocial',
            'Razao_Social': 'RazaoSocial',
            'CNPJ': 'CNPJ',
            'UF': 'UF',
            'Modalidade': 'Modalidade'
        }
        df_ops.rename(columns=mapa_colunas_ops, inplace=True)
        
        if 'reg_ans' not in df_despesas.columns:
            raise ValueError(f"Coluna 'reg_ans' sumiu das Despesas. Atuais: {df_despesas.columns}")
        if 'valor_despesa' not in df_despesas.columns:
            raise ValueError(f"Coluna 'valor_despesa' sumiu das Despesas. Atuais: {df_despesas.columns}")

        df_despesas['reg_ans'] = pd.to_numeric(df_despesas['reg_ans'], errors='coerce')
        df_ops['reg_ans'] = pd.to_numeric(df_ops['reg_ans'], errors='coerce')

        print("Cruzando dados...")
        df_final = pd.merge(df_despesas, df_ops, on='reg_ans', how='left')
        
        df_final['RazaoSocial'] = df_final['RazaoSocial'].fillna('Não Identificado')
        df_final['UF'] = df_final['UF'].fillna('N/A')
        
        df_final.to_csv(saida_enriquecida, index=False)
        print(f"Arquivo enriquecido salvo: {saida_enriquecida}")

        print("Calculando estatísticas...")
        
        if df_final['valor_despesa'].dtype == 'object':
             df_final['valor_despesa'] = df_final['valor_despesa'].astype(str).str.replace(',', '.').astype(float)
        
        df_final['valor_despesa'] = pd.to_numeric(df_final['valor_despesa'], errors='coerce').fillna(0)

        df_agregado = df_final.groupby('reg_ans')['valor_despesa'].agg(
            media_despesa='mean',
            desvio_padrao_despesa='std',
            total_despesa='sum',
            contagem='count'
        ).reset_index()

        df_agregado['desvio_padrao_despesa'] = df_agregado['desvio_padrao_despesa'].fillna(0)

        df_agregado.to_csv(saida_agregada, index=False)
        print(f"SUCESSO: Arquivo de estatísticas gerado em {saida_agregada}")

    except Exception as e:
        print(f"ERRO CRÍTICO: {e}")

if __name__ == "__main__":
    enriquecer_dados()