"""Transformação das demonstrações contábeis trimestrais da ANS.

Regras:
  * Os saldos da DRE são acumulados no ano: valor do trimestre =
    VL_SALDO_FINAL - VL_SALDO_INICIAL.
  * Valores vêm no formato brasileiro ("1234,56").
  * Contas usadas (Plano de Contas Padrão da ANS):
      311 Contraprestações líquidas        41  Eventos indenizáveis líquidos
      43  Despesas de comercialização      46  Despesas administrativas
      411x1 / 41411 / 41511 / 41611  -> parcela médico-hospitalar dos eventos

Saídas em data/:
  consolidado_despesas.csv     REG_ANS, Trimestre, Ano, Valor Despesas (conta 41)
  demonstracoes_operadora.csv  uma linha por operadora/trimestre com as contas acima
  contas_setor.csv             total do setor por conta (grupos 31/41/43/46, até 5 dígitos)
  lotes.csv                    registros extraídos por trimestre
"""
import glob
import os
import re
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from texto import corrigir_texto, ler_csv_ans  # noqa: E402

PADRAO_ARQUIVO = re.compile(r"^([1-4])T(\d{4})\.csv$", re.IGNORECASE)
GRUPOS_SETOR = ("31", "41", "43", "46")
CONTAS_MEDICO_HOSPITALAR = {f"411{i}1" for i in range(1, 10)} | {"41411", "41511", "41611"}


def para_numero(serie: pd.Series) -> pd.Series:
    texto = serie.astype(str).str.strip().str.replace(".", "", regex=False).str.replace(",", ".", regex=False)
    return pd.to_numeric(texto, errors="coerce").fillna(0.0)


class DataProcessor:
    def __init__(self):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.input_folder = os.path.join(base_dir, "data", "raw")
        self.output_dir = os.path.join(base_dir, "data")
        self.output_file = os.path.join(self.output_dir, "consolidado_despesas.csv")

    def identificar_arquivos(self):
        return sorted(
            f for f in glob.glob(os.path.join(self.input_folder, "*.csv"))
            if PADRAO_ARQUIVO.match(os.path.basename(f))
        )

    def _processar_arquivo(self, arquivo):
        trimestre, ano = (int(x) for x in PADRAO_ARQUIVO.match(os.path.basename(arquivo)).groups())
        df = ler_csv_ans(arquivo, sep=";", dtype=str)
        df.columns = df.columns.str.strip().str.upper()
        df["REG_ANS"] = df["REG_ANS"].str.strip()
        df["CONTA"] = df["CD_CONTA_CONTABIL"].str.strip()
        df["VALOR"] = para_numero(df["VL_SALDO_FINAL"]) - para_numero(df["VL_SALDO_INICIAL"])

        lote = {"ano": ano, "trimestre": trimestre, "registros_extraidos": len(df),
                "operadoras": df["REG_ANS"].nunique()}

        # Por operadora: uma coluna por conta de interesse.
        alvo = df[df["CONTA"].isin({"311", "41", "43", "46"} | CONTAS_MEDICO_HOSPITALAR)].copy()
        alvo["CAMPO"] = alvo["CONTA"].map(
            {"311": "contraprestacoes", "41": "eventos", "43": "comercializacao", "46": "administrativas"}
        ).fillna("eventos_mh")
        demo = alvo.pivot_table(index="REG_ANS", columns="CAMPO", values="VALOR", aggfunc="sum", fill_value=0.0)
        for col in ("contraprestacoes", "eventos", "eventos_mh", "comercializacao", "administrativas"):
            if col not in demo.columns:
                demo[col] = 0.0
        demo = demo.reset_index().rename(columns={"REG_ANS": "reg_ans"})
        demo["ano"], demo["trimestre"] = ano, trimestre

        # Setor: soma por conta (até 5 dígitos) nos grupos analisados.
        setor_df = df[df["CONTA"].str.len().le(5) & df["CONTA"].str[:2].isin(GRUPOS_SETOR)]
        descricoes = (
            setor_df.groupby("CONTA")["DESCRICAO"]
            .agg(lambda s: s.dropna().str.strip().value_counts().index[0] if s.notna().any() else "")
        )
        setor = setor_df.groupby("CONTA")["VALOR"].sum().reset_index()
        setor["descricao"] = setor["CONTA"].map(descricoes).map(corrigir_texto)
        setor = setor.rename(columns={"CONTA": "codigo", "VALOR": "valor"})
        setor["nivel"] = setor["codigo"].str.len() - 2
        setor["ano"], setor["trimestre"] = ano, trimestre

        print(f"  {trimestre}T{ano}: {len(df):,} registros · {lote['operadoras']} operadoras".replace(",", "."))
        return demo, setor, lote

    def processar(self):
        arquivos = self.identificar_arquivos()
        if not arquivos:
            print("Nenhum arquivo trimestral encontrado em data/raw. Rode etl/scraping.py antes.")
            return

        demos, setores, lotes = [], [], []
        for arquivo in arquivos:
            print(f"Lendo: {os.path.basename(arquivo)}")
            demo, setor, lote = self._processar_arquivo(arquivo)
            demos.append(demo)
            setores.append(setor)
            lotes.append(lote)

        demo = pd.concat(demos, ignore_index=True)
        num = ["contraprestacoes", "eventos", "eventos_mh", "comercializacao", "administrativas"]
        demo[num] = demo[num].round(2)
        demo[["reg_ans", "ano", "trimestre"] + num].to_csv(
            os.path.join(self.output_dir, "demonstracoes_operadora.csv"), index=False, encoding="utf-8"
        )

        setor = pd.concat(setores, ignore_index=True)
        setor["valor"] = setor["valor"].round(2)
        setor[["ano", "trimestre", "codigo", "descricao", "nivel", "valor"]].to_csv(
            os.path.join(self.output_dir, "contas_setor.csv"), index=False, encoding="utf-8"
        )

        pd.DataFrame(lotes).to_csv(os.path.join(self.output_dir, "lotes.csv"), index=False, encoding="utf-8")

        # Compatibilidade: arquivo legado com a despesa assistencial (conta 41).
        legado = demo[demo["eventos"] > 0].rename(
            columns={"reg_ans": "REG_ANS", "trimestre": "Trimestre", "ano": "Ano", "eventos": "Valor Despesas"}
        )[["REG_ANS", "Trimestre", "Ano", "Valor Despesas"]]
        legado.to_csv(self.output_file, index=False, encoding="utf-8")

        print(f"Consolidado: {len(demo)} demonstrações · {len(setor)} contas do setor · {len(lotes)} lotes")


if __name__ == "__main__":
    DataProcessor().processar()
