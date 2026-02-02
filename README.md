# Desafio Técnico - Intuitive Care

Este repositório contém a solução desenvolvida para o desafio técnico de Engenharia de Dados e Full Stack. O projeto consiste em uma pipeline ETL para dados da ANS (Agência Nacional de Saúde Suplementar) e um dashboard interativo para análise de despesas de operadoras de saúde.

## Visão Geral da Solução

O sistema foi arquitetado em microsserviços containerizados, garantindo isolamento de contexto e facilidade de reprodução do ambiente. A solução aborda desde a extração automática de dados públicos até a visualização analítica para o usuário final.

### Tecnologias Utilizadas

- **Backend:** Python 3.9, Flask (API REST)
- **Frontend:** Vue.js 3 (Composition API), Tailwind CSS
- **Banco de Dados:** MySQL 8.0
- **Engenharia de Dados:** Pandas, BeautifulSoup4, Requests
- **Infraestrutura:** Docker, Docker Compose

---

## Trade-offs e Decisões Técnicas

Conforme solicitado no desafio, abaixo estão detalhadas as decisões arquiteturais tomadas, os problemas enfrentados e as justificativas para cada abordagem.

### 1. Estratégia de Coleta de Dados (Web Scraping vs Download Manual)

- **Decisão:** Implementação de um scraper automatizado (`etl/scraper.py`) utilizando BeautifulSoup.
- **Trade-off:** Escrever um scraper é mais custoso inicialmente do que baixar arquivos manualmente e aumenta a fragilidade caso o layout do site da ANS mude.
- **Justificativa:** A automação garante que a aplicação sempre consuma a fonte mais recente de dados (Single Source of Truth) sem intervenção humana, simulando um ambiente de produção real onde a atualização de dados deve ser contínua.

### 2. Processamento de Dados (Pandas vs SQL Puro)

- **Decisão:** Utilização da biblioteca Pandas para limpeza e transformação (Data Wrangling) em memória antes da carga.
- **Trade-off:** O processamento em memória consome mais RAM do que realizar transformações via Stored Procedures no banco.
- **Justificativa:** Dada a complexidade da heterogeneidade dos arquivos CSV da ANS (diferentes encodings e formatações por trimestre) e a necessidade de tratar valores inconsistentes (ex: normalização de "NI" para campos de UF não informados), o Pandas oferece ferramentas de vetorização e tratamento de strings muito mais robustas e legíveis que o SQL puro.

### 3. Persistência (Relacional vs NoSQL)

- **Decisão:** Banco de dados Relacional (MySQL) com modelagem normalizada.
- **Trade-off:** Bancos relacionais são menos flexíveis a mudanças de esquema (Schema Drift) do que bancos NoSQL (como MongoDB).
- **Justificativa:** Os dados contábeis e cadastrais possuem estrutura rígida e relacionamentos claros (Uma Operadora -> Muitas Despesas). A integridade referencial (Foreign Keys) é crucial para garantir que não existam despesas órfãs de operadoras inexistentes, priorizando a consistência dos dados (ACID) sobre a flexibilidade.

### 4. Arquitetura Frontend (SPA vs Server-Side Rendering)

- **Decisão:** Single Page Application (SPA) com Vue.js 3 e Vite.
- **Trade-off:** Aumenta a complexidade da configuração inicial e requer uma API separada, ao contrário de renderizar templates HTML direto no Flask (Jinja2).
- **Justificativa:** A separação de responsabilidades permite que o Backend foque exclusivamente em regras de negócio e dados. Além disso, o Vue.js proporciona uma experiência de usuário (UX) superior, com navegação fluida sem recarregamento de página e componentes reativos (como a busca em tempo real e gráficos interativos).

### 5. Otimização de UX e Performance (IndexedDB vs Redis)

- **Decisão:** Cache de histórico de busca no lado do cliente usando IndexedDB.
- **Trade-off:** Os dados ficam restritos ao navegador do usuário, não sendo compartilhados entre dispositivos como seria em um cache de servidor (Redis).
- **Justificativa:** Para o escopo deste teste, adicionar um serviço de Redis aumentaria a complexidade da infraestrutura desnecessariamente. O uso do IndexedDB resolve o requisito de "melhorar a usabilidade" com custo zero de servidor e persistência local robusta.

---

## Estrutura do Projeto (Clean Architecture)

O código foi refatorado para evitar acoplamento, separando claramente as camadas de responsabilidade:
