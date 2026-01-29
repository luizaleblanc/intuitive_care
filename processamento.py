import pandas as pd
import os
import glob

class DataProcessor:
    def __init__(self):
        self.input_folder = "data/raw"
        self.output_file = "data/consolidado_despesas.csv"
        self.colunas_finais = ['REG_ANS', 'Trimestre', 'Ano', 'Valor Despesas']

    def identificar_arquivos(self):
        return glob.glob(f"{self.input_folder}/*.csv")

    def processar(self):
        arquivos = self.identificar_arquivos()
        lista_dataframes = []

        for arquivo in arquivos:
            print(f"Lendo: {arquivo}")
            try:
                df = pd.read_csv(arquivo, sep=';', encoding='latin1', dtype={'CD_CONTA_CONTABIL': str})
                
                nome_base = os.path.basename(arquivo)
                df['Trimestre'] = nome_base[0] 
                df['Ano'] = nome_base[2:6]    

                df_despesas = df[df['CD_CONTA_CONTABIL'].str.startswith('4', na=False)].copy()

                df_despesas = df_despesas.rename(columns={'VL_SALDO_FINAL': 'Valor Despesas'})
                df_despesas['Valor Despesas'] = pd.to_numeric(df_despesas['Valor Despesas'], errors='coerce').fillna(0)
                
                df_despesas = df_despesas[df_despesas['Valor Despesas'] > 0]

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