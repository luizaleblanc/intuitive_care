# Intuitive Care

Esse projeto engloba uma pipeline ETL automatizada para extração de dados da ANS (Agência Nacional de Saúde Suplementar) e um dashboard interativo focado na análise de despesas das operadoras de saúde.

## Resumo das Decisões Técnicas

A arquitetura e as ferramentas do projeto foram escolhidas com base nos seguintes critérios:

* **Coleta Automatizada (Scraping):** Utilização da biblioteca *BeautifulSoup* para extrair os dados da ANS de forma autônoma (eliminando downloads manuais), garantindo que o sistema consuma a fonte de dados mais recente.
* **Processamento em Memória (Pandas):** A etapa de limpeza e transformação (*Data Wrangling*) foi realizada com *Pandas*. Essa abordagem lida de forma mais eficiente com inconsistências e diferentes encodings dos arquivos da ANS, justificando o maior uso de memória em comparação ao SQL puro.
* **Persistência Relacional (MySQL):** Adoção de um banco de dados relacional para priorizar a consistência (ACID) e garantir a integridade referencial entre os dados financeiros e cadastrais (relação direta entre Operadoras e Despesas).
* **Frontend Desacoplado (Vue.js 3):** Desenvolvimento de uma *Single Page Application* (SPA) utilizando Vue 3 e Tailwind CSS. Isso separa a camada de visualização das regras de negócio, oferecendo uma interface reativa e navegação fluida.
* **Otimização de Performance (IndexedDB):** Implementação do IndexedDB diretamente no navegador do cliente para armazenar o histórico de buscas. Isso melhora a usabilidade sem a necessidade de escalar a infraestrutura com serviços em cache adicionais (como Redis).
* **Containerização (Docker):** Isolamento de toda a aplicação (Banco de Dados, API e Frontend) em microsserviços via *Docker*, eliminando problemas de incompatibilidade entre ambientes de desenvolvimento.

---

## Como Inicializar a Aplicação

### Pré-requisitos

Antes de começar, certifique-se de ter instalado em sua máquina:

* **Docker** e **Docker Compose**
* **Python 3** (para rodar os scripts da pipeline ETL)

### Passo a Passo

**1. Preparação do Ambiente**

* Clone o repositório para a sua máquina local.
* Pelo terminal, acesse a pasta raiz do projeto.

**2. Subindo a Infraestrutura Docker**

* Execute o comando abaixo para construir e inicializar os containers em segundo plano:

```bash
docker-compose up --build -d

```

**3. Instalação de Dependências Locais**

* Para que a pipeline de dados funcione corretamente, instale as dependências do Python executando:

```bash
pip install -r requirements.txt

```

**4. Carga e Processamento de Dados (Pipeline ETL)**

* Com o banco de dados rodando e as dependências instaladas, popule o sistema com os relatórios da ANS executando os scripts estritamente na ordem abaixo:

```bash
python etl/scraping.py
python etl/processamento.py
python etl/enriquecimento.py
python etl/importar_sql.py

```

**5. Acesso ao Sistema**

* Com os containers em execução e o banco de dados devidamente populado, abra o seu navegador de preferência.
* Acesse o painel da aplicação através do endereço:
**[http://localhost:8080]**
