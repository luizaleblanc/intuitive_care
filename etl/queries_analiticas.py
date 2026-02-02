from sqlalchemy import create_engine
import pandas as pd

DB_CONFIG = "mysql+pymysql://root:root@localhost:3307/intuitive_care"
engine = create_engine(DB_CONFIG)

def rodar_query(titulo, sql):
    print(f"\n--- {titulo} ---")
    try:
        with engine.connect() as conn:
            df = pd.read_sql(sql, conn)
            if df.empty:
                print("Nenhum resultado encontrado.")
            else:
                print(df.to_string(index=False))
    except Exception as e:
        print(f"Erro na query: {e}")

sql_crescimento = """
WITH periodos AS (
    SELECT MIN(CONCAT(ano, trimestre)) as inicio, MAX(CONCAT(ano, trimestre)) as fim
    FROM despesas
),
valores_inicio AS (
    SELECT d.reg_ans, SUM(d.valor_despesa) as total_inicio
    FROM despesas d, periodos p
    WHERE CONCAT(d.ano, d.trimestre) = p.inicio
    GROUP BY d.reg_ans
),
valores_fim AS (
    SELECT d.reg_ans, SUM(d.valor_despesa) as total_fim
    FROM despesas d, periodos p
    WHERE CONCAT(d.ano, d.trimestre) = p.fim
    GROUP BY d.reg_ans
)
SELECT 
    o.razao_social,
    v_ini.total_inicio,
    v_fim.total_fim,
    ROUND(((v_fim.total_fim - v_ini.total_inicio) / v_ini.total_inicio) * 100, 2) as crescimento_pct
FROM valores_fim v_fim
JOIN valores_inicio v_ini ON v_fim.reg_ans = v_ini.reg_ans
JOIN operadoras o ON v_fim.reg_ans = o.reg_ans
WHERE v_ini.total_inicio > 100000 
ORDER BY crescimento_pct DESC
LIMIT 5;
"""

sql_uf = """
SELECT 
    o.uf, 
    SUM(d.valor_despesa) as total_despesas
FROM despesas d
JOIN operadoras o ON d.reg_ans = o.reg_ans
WHERE o.uf IS NOT NULL
GROUP BY o.uf
ORDER BY total_despesas DESC
LIMIT 5;
"""

sql_acima_media = """
WITH media_trimestral AS (
    SELECT ano, trimestre, AVG(valor_despesa) as media_mercado
    FROM despesas
    GROUP BY ano, trimestre
)
SELECT COUNT(DISTINCT d.reg_ans) as qtd_operadoras_acima_media
FROM despesas d
JOIN media_trimestral m ON d.ano = m.ano AND d.trimestre = m.trimestre
WHERE d.valor_despesa > m.media_mercado;
"""

if __name__ == "__main__":
    rodar_query("TOP 5 Crescimento (%)", sql_crescimento)
    rodar_query("TOP 5 Estados (R$)", sql_uf)
    rodar_query("Qtd Operadoras Acima da Média", sql_acima_media)