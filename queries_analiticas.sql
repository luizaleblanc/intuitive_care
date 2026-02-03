SELECT 
    o.razao_social, 
    o.registro_ans, 
    SUM(d.valor_despesa) AS total_despesas
FROM despesas d
JOIN operadoras o ON d.reg_ans = o.registro_ans
GROUP BY o.razao_social, o.registro_ans
ORDER BY total_despesas DESC
LIMIT 10;

SELECT 
    ano, 
    trimestre, 
    SUM(valor_despesa) AS total_trimestre
FROM despesas
GROUP BY ano, trimestre
ORDER BY ano DESC, trimestre DESC;