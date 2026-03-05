# Intuitive Care

Esta é a solução desenvolvida para o desafio técnico de Engenharia de Dados e Full Stack. O projeto engloba uma pipeline ETL automatizada para extração de dados da ANS (Agência Nacional de Saúde Suplementar) e um dashboard interativo focado na análise de despesas das operadoras de saúde.

## Resumo das Decisões Técnicas

- **Coleta Automatizada (Scraping):** Ao invés de downloads manuais, optou-se por utilizar o *BeautifulSoup* para extrair os dados da ANS de forma autônoma, garantindo que o sistema sempre utilize a fonte de dados mais atualizada.
- **Processamento em Memória (Pandas):** A limpeza e a transformação de dados (Data Wrangling) foram feitas via *Pandas*. Apesar de consumir mais memória que o SQL puro, o Pandas lida melhor com inconsistências nos dados originais e diferentes encodings presentes nos arquivos da ANS.
- **Persistência Relacional (MySQL):** A escolha por um banco relacional garante a integridade referencial dos dados financeiros e cadastrais (relação clara entre Operadoras e Despesas), priorizando a consistência (ACID).
- **Frontend Desacoplado (Vue.js 3):** A construção de uma *Single Page Application* (SPA) com Vue 3 e Tailwind CSS separa visualização da regra de negócio, garantindo uma interface reativa e navegação mais fluida para o usuário.
- **Otimização de Performance (IndexedDB):** Para o histórico de buscas, optou-se por utilizar o IndexedDB diretamente no navegador do cliente, agregando valor à usabilidade sem a necessidade de escalar infraestrutura adicional com serviços como o Redis.
- **Containerização:** Toda a aplicação (Banco, API e Frontend) está isolada em microsserviços usando *Docker*, o que elimina problemas de incompatibilidade de ambiente de desenvolvimento.

## Como Inicializar a Aplicação

### Pré-requisitos
Certifique-se de ter o **Docker** e o **Docker Compose** instalados em sua máquina.

### Passo a Passo

1. **Clone o repositório e acesse a pasta raiz.**

2. **Suba a infraestrutura via Docker:**
   No terminal, execute o seguinte comando para construir e inicializar as imagens:
   docker-compose up --build -d

Para popular o banco de dados com os relatórios da ANS, execute os scripts da pipeline ETL na seguinte ordem (certifique-se de ter as dependências do Python instaladas localmente via pip install -r requirements.txt):

python etl/scraping.py
python etl/processamento.py
python etl/enriquecimento.py
python etl/importar_sql.py

Com os containers rodando, abra o seu navegador e acesse o painel através do endereço:
http://localhost:8080
