"""Constantes de configuração, formatos numéricos e paleta visual das planilhas ETL."""

SECOES_VALIDAS = (
    "resumo",
    "evolucao",
    "modalidades",
    "ufs",
    "operadoras",
    "contas_setor",
    "base_demonstracoes",
    "lotes_cadastro",
)
SECOES_PADRAO = SECOES_VALIDAS
ORDENS_VALIDAS = ("despesas", "receitas", "sinistralidade", "beneficiarios", "resultado", "administrativas")
FORMATOS_VALIDOS = ("XLSX", "CSV", "JSON")

# Formatos numéricos nativos do Excel
FMT_MOEDA = 'R$ #,##0.00;-"R$ "#,##0.00;"-"'
FMT_PCT = "0.00%"
FMT_INT = "#,##0"

# Paleta institucional Intuitive Care
COR_FOREST = "113E32"
COR_MINT = "4AD295"
COR_SAGE = "DCE7E2"
COR_ZEBRA = "F3F7F5"
COR_BORDA = "D3DFD9"
COR_TEXTO = "0F172A"
COR_MUTED = "475569"
COR_OK_BG = "ECFDF5"
COR_OK_FG = "047857"
COR_ERR_BG = "FEF2F2"
COR_ERR_FG = "B91C1C"

# Limite acima do qual injetamos as linhas em OOXML direto (20x+ mais rápido que ElementTree/et_xmlfile)
STREAM_THRESHOLD_PADRAO = 200
