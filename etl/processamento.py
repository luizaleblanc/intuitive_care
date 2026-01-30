import pandas as pd
import os
import glob

class DataProcessor:
    def __init__(self):
        self.input_folder = "data/raw"
        self.output_file = "data/consolidado_despesas.csv"
        self.colunas_finais = ['REG_ANS', 'Trimestre', 'Ano', 'Valor Despesas']

    def identificar_arquivos(self):
        todos_arquivos = glob.glob(f"{self.input_folder}/*.csv")
        arquivos_filtrados = [
            f for f in todos_arquivos 
            if "Relatorio_cadop" not in f and "consolidado" not in f
        ]
        return arquivos_filtrados

    def processar(self):
        arquivos = self.identificar_arquivos()
        lista_dataframes = []

        for arquivo in arquivos:
            print(f"Lendo: {arquivo}")
            try:
                df = pd.read_csv(arquivo, sep=';', encoding='latin1', dtype={'CD_CONTA_CONTABIL': str})
                
                if 'CD_CONTA_CONTABIL' not in df.columns:
                    print(f"Ignorando {arquivo}: Não parece ser arquivo de despesas.")
                    continue

                nome_base = os.path.basename(arquivo)
                try:
                    df['Trimestre'] = nome_base[0] 
                    df['Ano'] = nome_base[2:6]
                except:
                    df['Trimestre'] = 0
                    df['Ano'] = 0

                df_despesas = df[df['CD_CONTA_CONTABIL'].str.startswith('4', na=False)].copy()

                df_despesas = df_despesas.rename(columns={'VL_SALDO_FINAL': 'Valor Despesas'})
                
                if 'REG_ANS' not in df_despesas.columns:
                    cols_map = {'REGISTRO_ANS': 'REG_ANS', 'CD_OPERADORA': 'REG_ANS'}
                    df_despesas = df_despesas.rename(columns=cols_map)

                df_despesas['Valor Despesas'] = pd.to_numeric(df_despesas['Valor Despesas'], errors='coerce').fillna(0)
                df_despesas = df_despesas[df_despesas['Valor Despesas'] > 0]

                if 'REG_ANS' in df_despesas.columns:
                    lista_dataframes.append(df_despesas[self.colunas_finais])
                
            except Exception as e:
                print(f"Erro no arquivo {arquivo}: {e}")

        if lista_dataframes:
            consolidado = pd.concat(lista_dataframes, ignore_index=True)
            consolidado.to_csv(self.output_file, index=False, encoding='utf-8')
            print(f"Consolidado gerado: {self.output_file}")

if __name__ == "__main__":
    processor = DataProcessor()
    processor.processar()