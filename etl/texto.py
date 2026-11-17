"""Utilitários de normalização de texto para a pipeline ETL.

Os arquivos da ANS chegam ora em UTF-8, ora em latin1/cp1252. Quando um texto
UTF-8 é lido como latin1 surge o "mojibake" (ex.: "Saúde" -> "SaÃºde").
Estas funções detectam e revertem esse problema.
"""
import pandas as pd

_MARCADORES_MOJIBAKE = ("Ã", "Â", "â€")


def corrigir_texto(valor):
    """Reverte mojibake (UTF-8 lido como latin1/cp1252) e remove espaços extras."""
    if valor is None or (not isinstance(valor, str) and pd.isna(valor)):
        return valor
    if not isinstance(valor, str):
        return valor
    texto = valor
    # Repete até 2x para casos de dupla codificação.
    for _ in range(2):
        if not any(m in texto for m in _MARCADORES_MOJIBAKE):
            break
        corrigido = None
        for enc in ("cp1252", "latin1"):
            try:
                corrigido = texto.encode(enc).decode("utf-8")
                break
            except (UnicodeEncodeError, UnicodeDecodeError):
                continue
        if corrigido is None or corrigido == texto:
            break
        texto = corrigido
    return " ".join(texto.split())


def ler_csv_ans(caminho, **kwargs):
    """Lê CSV tentando UTF-8 (com/sem BOM) e caindo para cp1252/latin1."""
    ultimo_erro = None
    for enc in ("utf-8-sig", "cp1252", "latin1"):
        try:
            return pd.read_csv(caminho, encoding=enc, **kwargs)
        except UnicodeDecodeError as erro:
            ultimo_erro = erro
    raise ultimo_erro


def normalizar_dataframe(df):
    """Aplica corrigir_texto em todas as colunas de texto do DataFrame."""
    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].map(corrigir_texto)
    return df
