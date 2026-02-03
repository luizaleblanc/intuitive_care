SELECT 
    o.Razao_Social, 
    o.REGISTRO_OPERADORA, 
    SUM(d.valor_despesa) AS total_despesas
FROM despesas d
JOIN operadoras o ON d.reg_ans = o.REGISTRO_OPERADORA
GROUP BY o.Razao_Social, o.REGISTRO_OPERADORA
ORDER BY total_despesas DESC
LIMIT 10;

SELECT 
    ano, 
    trimestre, 
    SUM(valor_despesa) AS total_trimestre
FROM despesas
GROUP BY ano, trimestre
ORDER BY ano DESC, trimestre DESC;

WITH Periodos AS (
    SELECT 
        MIN(CONCAT(ano, trimestre)) as periodo_inicial,
        MAX(CONCAT(ano, trimestre)) as periodo_final
    FROM despesas
),
DespesasInicial AS (
    SELECT d.reg_ans, d.valor_despesa as valor_inicial
    FROM despesas d
    JOIN Periodos p ON CONCAT(d.ano, d.trimestre) = p.periodo_inicial
),
DespesasFinal AS (
    SELECT d.reg_ans, d.valor_despesa as valor_final
    FROM despesas d
    JOIN Periodos p ON CONCAT(d.ano, d.trimestre) = p.periodo_final
)
SELECT 
    o.Razao_Social,
    di.valor_inicial,
    df.valor_final,
    ROUND(((df.valor_final - di.valor_inicial) / di.valor_inicial) * 100, 2) as crescimento_percentual
FROM DespesasFinal df
JOIN DespesasInicial di ON df.reg_ans = di.reg_ans
JOIN operadoras o ON df.reg_ans = o.REGISTRO_OPERADORA
WHERE di.valor_inicial > 0 
ORDER BY crescimento_percentual DESC
LIMIT 5;

SELECT 
    o.uf,
    SUM(d.valor_despesa) as total_despesas,
    COUNT(DISTINCT o.REGISTRO_OPERADORA) as qtd_operadoras,
    ROUND(SUM(d.valor_despesa) / COUNT(DISTINCT o.REGISTRO_OPERADORA), 2) as media_por_operadora
FROM operadoras o
JOIN despesas d ON o.REGISTRO_OPERADORA = d.reg_ans
GROUP BY o.uf
ORDER BY total_despesas DESC
LIMIT 5;

WITH MediaPorTrimestre AS (
    SELECT ano, trimestre, AVG(valor_despesa) as media_geral
    FROM despesas
    GROUP BY ano, trimestre
),
OperadorasAcima AS (
    SELECT 
        d.reg_ans,
        d.ano,
        d.trimestre
    FROM despesas d
    JOIN MediaPorTrimestre m ON d.ano = m.ano AND d.trimestre = m.trimestre
    WHERE d.valor_despesa > m.media_geral
)
SELECT 
    o.Razao_Social,
    COUNT(*) as trimestres_acima_da_media
FROM OperadorasAcima oa
JOIN operadoras o ON oa.reg_ans = o.REGISTRO_OPERADORA
GROUP BY o.Razao_Social
HAVING COUNT(*) >= 2
ORDER BY trimestres_acima_da_media DESC;