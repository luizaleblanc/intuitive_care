import pandas as pd

class DataEnricher:
    def __init__(self):
        self.path_despesas = "data/consolidado_despesas.csv"
        self.path_cadop = "data/raw/Relatorio_cadop.csv"
        self.output_path = "data/despesas_enriquecidas.csv"

    def enriquecer(self):
        print("Iniciando processamento...")
        try:
            df_despesas = pd.read_csv(self.path_despesas)
            
            try:
                df_cadop = pd.read_csv(self.path_cadop, sep=';', encoding='utf-8', dtype=str)
            except UnicodeDecodeError:
                df_cadop = pd.read_csv(self.path_cadop, sep=';', encoding='latin1', dtype=str)

            df_cadop.columns = df_cadop.columns.str.strip().str.upper()

            mapeamento = {
                'REGISTRO_OPERADORA': 'REG_ANS',
                'REGISTRO_ANS': 'REG_ANS',
                'CD_OPERADORA': 'REG_ANS',
                'CNPJ': 'CNPJ',
                'RAZAO_SOCIAL': 'RazaoSocial',
                'MODALIDADE': 'Modalidade',
                'UF': 'UF'
            }
            df_cadop = df_cadop.rename(columns=mapeamento)

            colunas_alvo = ['REG_ANS', 'CNPJ', 'RazaoSocial', 'Modalidade', 'UF']
            
            colunas_existentes = [c for c in colunas_alvo if c in df_cadop.columns]
            df_cadop = df_cadop[colunas_existentes]

            df_despesas['REG_ANS'] = df_despesas['REG_ANS'].astype(str)
            df_cadop['REG_ANS'] = df_cadop['REG_ANS'].astype(str)

            print("Cruzando tabelas...")
            df_final = pd.merge(df_despesas, df_cadop, on='REG_ANS', how='left')

            if 'CNPJ' in df_final.columns:
                df_final['CNPJ'] = df_final['CNPJ'].fillna("00000000000000")
            if 'UF' in df_final.columns:
                df_final['UF'] = df_final['UF'].fillna("NI")  

            df_final.to_csv(self.output_path, index=False, encoding='utf-8')
            print(f"Sucesso absoluto! Arquivo corrigido gerado em: {self.output_path}")

        except Exception as e:
            print(f"ERRO: {e}")

if __name__ == "__main__":
    enricher = DataEnricher()
    enricher.enriquecer()