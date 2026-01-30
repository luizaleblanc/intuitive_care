# Pipeline de Engenharia de Dados e Visualização - Intuitive Care

Esse projeto consiste em uma solução completa de ETL (Extract, Transform, Load) e visualização de dados para análise de demonstrações contábeis de operadoras de planos de saúde, utilizando dados públicos da ANS (Agência Nacional de Saúde Suplementar).

O sistema automatiza a coleta de arquivos, padroniza estruturas de dados, enriquece as informações com dados cadastrais e expõe os resultados através de uma API REST consumida por um dashboard analítico.

## Arquitetura da Solução

O fluxo de dados foi desenhado em quatro etapas sequenciais:

1.  **Ingestão de Dados (Scraping):** Script automatizado para varredura e download dos arquivos `.csv` mais recentes diretamente do repositório da ANS.
2.  **Processamento e Limpeza (Pandas):** Consolidação de arquivos trimestrais, aplicação de filtros de contas contábeis e normalização de tipos de dados.
3.  **Enriquecimento e Persistência (ETL):** Cruzamento dos dados financeiros com a base cadastral de operadoras e carga em banco de dados relacional (MySQL) modelado para performance analítica.
4.  **Visualização (Full Stack):** API desenvolvida em Flask para servir os dados agregados a um front-end client-side utilizando Chart.js.

## Tecnologias Utilizadas

- **Linguagem:** Python 3.12
- **Manipulação de Dados:** Pandas
- **Banco de Dados:** MySQL 8.0 / SQLAlchemy
- **Backend/API:** Flask
- **Frontend:** HTML5 / JavaScript (ES6) / Chart.js
- **Infraestrutura:** Virtualenv

## Decisões Técnicas e Desafios Superados

Durante o desenvolvimento, foram abordados desafios de integridade e consistência de dados:

- **Resiliência a "Schema Drift":** A fonte de dados da ANS apresentou inconsistências na nomenclatura de colunas chaves entre arquivos (variação entre `REGISTRO_ANS` e `REGISTRO_OPERADORA`). Foi implementada uma camada de normalização de cabeçalhos e mapeamento dinâmico para garantir a robustez do pipeline.
- **Estratégia de Join:** Optou-se pela utilização de `LEFT JOIN` na etapa de enriquecimento. Essa decisão visa preservar a integridade contábil dos dados financeiros, garantindo que despesas sejam contabilizadas mesmo que a operadora possua inconsistências cadastrais momentâneas na base oficial.
- **Tratamento de Encoding:** Implementação de fallback automático entre `utf-8` e `latin1` para mitigar erros de leitura comuns em arquivos governamentais legados.
- **Modelagem de Dados:** O banco foi normalizado em duas tabelas (`operadoras` e `despesas`) para evitar redundância de dados cadastrais e otimizar o armazenamento.

## Estrutura do Projeto

/
├── data/ # Armazenamento de arquivos brutos e processados
├── main_api.py # Servidor API (Flask)
├── processamento.py # Script de limpeza e consolidação (ETL - Fase 1)
├── enriquecimento.py # Script de join e normalização (ETL - Fase 2)
├── importar_sql.py # Script de carga no Banco de Dados (Load)
├── index.html # Dashboard de visualização
└── requirements.txt # Dependências do projeto
