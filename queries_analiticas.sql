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
    o.razao_social,
    di.valor_inicial,
    df.valor_final,
    ROUND(((df.valor_final - di.valor_inicial) / di.valor_inicial) * 100, 2) as crescimento_percentual
FROM DespesasFinal df
JOIN DespesasInicial di ON df.reg_ans = di.reg_ans
JOIN operadoras o ON df.reg_ans = o.reg_ans
WHERE di.valor_inicial > 0 -- Evita divisão por zero
ORDER BY crescimento_percentual DESC
LIMIT 5;

SELECT 
    o.uf,
    SUM(d.valor_despesa) as total_despesas,
    COUNT(DISTINCT o.reg_ans) as qtd_operadoras,
    ROUND(SUM(d.valor_despesa) / COUNT(DISTINCT o.reg_ans), 2) as media_por_operadora
FROM operadoras o
JOIN despesas d ON o.reg_ans = d.reg_ans
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
    o.razao_social,
    COUNT(*) as trimestres_acima_da_media
FROM OperadorasAcima oa
JOIN operadoras o ON oa.reg_ans = o.reg_ans
GROUP BY o.razao_social
HAVING COUNT(*) >= 2
ORDER BY trimestres_acima_da_media DESC;