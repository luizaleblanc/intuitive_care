# Intuitive Care — Plataforma Mobile de Análise e Gestão ANS

Sistema computacional completo composto por **Aplicativo Mobile em Flutter (Arquitetura MVVM + Provider)**, **API REST em Python + Flask (Arquitetura em Camadas)**, **Pipeline ETL em Python (Reaproveitada)** e **Banco de Dados Relacional MySQL 8.0**.

Projeto desenvolvido e migrado para atender rigorosamente às diretrizes da **2ª Avaliação** das disciplinas de **Códigos de Alta Performance (Mobile)** e **Backend Frameworks** — Curso de Graduação em Ciências da Computação (UNINASSAU João Pessoa).

---

## Sumário das Mudanças Realizadas na Migração

A tabela abaixo compara o estado **antigo (legado)** do projeto com o que está **100% implementado e ativo na versão atual**:

| Funcionalidade / Camada | Como era no Projeto Antigo (Antes) | Como está no Projeto Atual (Agora) |
| :--- | :--- | :--- |
| **Autenticação & Controle de Sessão** | ❌ **Inexistente no projeto original** (não havia login, senhas nem usuários; rotas eram abertas). | ✅ **100% Implementado e Ativo:**<br>• Cadastro (`POST /api/auth/register`) com senha criptografada em hash seguro.<br>• Login (`POST /api/auth/login`) com validação no backend e emissão de JWT.<br>• Identificação do usuário logado via JSON (`GET /api/auth/me`).<br>• Atualização de perfil (`PUT /api/auth/me`).<br>• Logoff com revogação no banco (`POST /api/auth/logout` invalida a sessão em `sessoes_tokens`).<br>• Recuperação de senha por e-mail via API (`POST /api/auth/forgot-password` e `POST /api/auth/reset-password`). |
| **Frontend** | ❌ Aplicação Web legada em Vue.js 3 + Tailwind CSS (`web-app/` e `frontend/index.html`). | ✅ **100% Migrado para Flutter Mobile** (`frontend/`) estruturado estritamente em **MVVM** (`models`, `views`, `viewmodels`, `services`, `repositories`, `widgets`) com gerência de estado via **Provider**, consumindo exclusivamente a API Flask via JSON. |
| **Arquitetura do Backend** | ❌ Script monolítico em arquivo único `api/main_api.py` com apenas 4 endpoints `GET`. | ✅ **100% Reestruturado em Camadas** (`backend/`): separação clara em **Rotas (`routes/`)**, **Regras de Negócio e Validações (`services/`)**, **Persistência (`repositories/`)**, **Modelos (`models/`)** e **Banco (`database/`)**. |
| **Operações HTTP & CRUD** | ❌ Somente leitura (`GET`). | ✅ **CRUD Completo (`GET`, `POST`, `PUT`, `DELETE`)** em todas as tabelas principais (`operadoras`, `despesas` e gestão de perfil de `usuarios`). |
| **Regras de Negócio** | ❌ Quase inexistentes (lógicas soltas na interface). | ✅ **Centralizadas e validadas no Backend**: cálculo algorítmico do dígito verificador do CNPJ (módulo 11), validação das 27 UFs, unicidade cadastral, bloqueio de integridade referencial ao excluir operadora com despesas (`HTTP 409`), classificação automática de porte financeiro e cálculo de KPIs analíticos. |
| **Banco de Dados & ETL** | ❌ Carga ETL sobrescrevia tabelas apagando chaves (`if_exists='replace'`); sem backup SQL. | ✅ **Schema relacional oficial com integridade e FKs** (`backend/database/schema.sql`), backup demonstrativo completo (`backend/database/backup_intuitive_care.sql`) e **pipeline ETL em Python reaproveitada**. |

---

## Estrutura de Diretórios

```text
intuitive_care/
├── backend/
│   ├── app.py                          # Application Factory Flask, CORS e tratamento global de erros
│   ├── config.py                       # Configurações de BD (MySQL/SQLite), JWT e provedores de e-mail
│   ├── requirements.txt                # Dependências isoladas do backend
│   ├── Dockerfile                      # Container da API Flask
│   ├── .env.example                    # Modelo de variáveis de ambiente
│   ├── database/
│   │   ├── connection.py               # Gerenciamento de conexões SQLAlchemy/PyMySQL
│   │   ├── schema.sql                  # DDL oficial MySQL 8.0 com FKs e índices
│   │   ├── backup_intuitive_care.sql   # Exportação SQL completa (estrutura + relacionamentos + dados)
│   │   └── init_db.py                  # Inicialização programática do banco e seed inicial
│   ├── models/                         # Modelos de domínio (Usuario, Operadora, Despesa)
│   ├── repositories/                   # Camada de persistência SQL parametrizada
│   ├── services/                       # Regras de negócio, validadores, auth JWT e serviço de e-mail
│   ├── routes/                         # Blueprints REST e middleware @token_required
│   └── tests/                          # Suíte automatizada de testes de integração da API
├── etl/                                # Pipeline ETL em Python reaproveitada
│   ├── scraping.py                     # Extração automatizada dos ZIPs/CSVs da ANS
│   ├── processamento.py                # Limpeza e consolidação das contas contábeis (classe 4)
│   ├── enriquecimento.py               # Cruzamento com Relatorio_cadop.csv e agregação estatística
│   ├── importar_sql.py                 # Carga no MySQL preservando PK/FK do schema oficial
│   └── queries_analiticas.py           # Consultas analíticas SQL sobre a base ANS
├── frontend/                           # Aplicativo Mobile Flutter (MVVM + Provider)
│   ├── pubspec.yaml                    # Dependências Flutter (provider, http, shared_preferences, intl)
│   ├── lib/
│   │   ├── main.dart                   # Injeção de dependências via MultiProvider e AuthGate
│   │   ├── config/api_config.dart      # URL base da API Flask (emulador Android / desktop / web)
│   │   ├── models/                     # UserModel, OperadoraModel, DespesaModel, EstatisticaModel
│   │   ├── services/                   # Comunicação HTTP/JSON com a API Flask (ApiClient + services)
│   │   ├── repositories/               # Intermediação entre ViewModels e Services
│   │   ├── viewmodels/                 # AuthViewModel, DashboardViewModel, OperadoraViewModel, DespesaViewModel
│   │   ├── views/                      # Telas de Login, Cadastro, Recuperação, Painel, CRUD e Perfil
│   │   └── widgets/                    # Componentes visuais reutilizáveis
│   └── test/                           # Testes unitários e de widgets Flutter
├── docs/
│   ├── PLANO_DE_ATAQUE.md              # Plano de ataque da migração e checklist acadêmico
│   └── RELATORIO_TECNICO.md            # Relatório Técnico completo (Seção 4.3)
├── utils/
│   ├── criar_tabelas_docker.py         # Inicializa schema e massa demonstrativa no MySQL Docker
│   ├── gerar_entregavel_backend.py     # Gera .zip do backend + backup SQL para entrega acadêmica
│   ├── verificar.py
│   └── verificar_banco.py
├── docker-compose.yml                  # Orquestração MySQL 8.0 + API Flask
├── intuitive_care_collection.json      # Coleção Postman atualizada (Auth + CRUD + Estatísticas)
├── queries_analiticas.sql
└── requirements.txt
```

---

## Principais Endpoints da API REST (Flask)

Todas as requisições e respostas utilizam **JSON**. Rotas protegidas exigem cabeçalho `Authorization: Bearer <token>`.

| Grupo | Método | Rota | Descrição |
| :--- | :--- | :--- | :--- |
| **Saúde** | `GET` | `/api/health` | Verifica status da API e conectividade com o SGBD |
| **Auth** | `POST` | `/api/auth/register` | Cadastro de usuário com e-mail, nome e senha |
| **Auth** | `POST` | `/api/auth/login` | Autenticação por e-mail/senha e emissão de JWT |
| **Auth** | `GET` | `/api/auth/me` | Retorna dados do usuário autenticado |
| **Auth** | `PUT` | `/api/auth/me` | Atualiza nome do usuário autenticado |
| **Auth** | `POST` | `/api/auth/logout` | Encerra sessão revogando o token no banco de dados |
| **Auth** | `POST` | `/api/auth/forgot-password` | Gera código de recuperação e dispara e-mail via API |
| **Auth** | `POST` | `/api/auth/reset-password` | Valida código temporário e redefine a senha |
| **Operadoras** | `GET` | `/api/operadoras` | Lista operadoras paginadas com busca e filtro por UF |
| **Operadoras** | `GET` | `/api/operadoras/<id>` | Detalha operadora por `registro_ans` ou `cnpj` |
| **Operadoras** | `GET` | `/api/operadoras/<id>/despesas` | Lista despesas da operadora |
| **Operadoras** | `POST` | `/api/operadoras` | Cadastra nova operadora (valida CNPJ e UF no backend) |
| **Operadoras** | `PUT` | `/api/operadoras/<id>` | Atualiza dados cadastrais da operadora |
| **Operadoras** | `DELETE` | `/api/operadoras/<id>` | Exclui operadora (bloqueia se houver despesas sem `?force=true`) |
| **Despesas** | `GET` | `/api/despesas` | Lista despesas paginadas com filtros (`reg_ans`, `ano`, `trimestre`) |
| **Despesas** | `GET` | `/api/despesas/<id>` | Detalha lançamento de despesa |
| **Despesas** | `POST` | `/api/despesas` | Lança nova despesa vinculada a uma operadora válida |
| **Despesas** | `PUT` | `/api/despesas/<id>` | Atualiza lançamento de despesa |
| **Despesas** | `DELETE` | `/api/despesas/<id>` | Exclui lançamento de despesa |
| **Dashboard** | `GET` | `/api/estatisticas` | Total geral, média, crescimento trimestral, Top 5 UFs e Top operadoras |

---

## Como Executar o Projeto

### 1. Pré-requisitos

- **Python 3.11+**
- **Flutter SDK 3.x+**
- **Docker & Docker Compose** (ou instância local de **MySQL 8.0**)

### 2. Subindo Backend + Banco MySQL com Docker

```bash
docker-compose up --build -d
```

- O MySQL 8.0 sobe na porta **`3307`** (mapeada para `3306` interna) e executa automaticamente `backend/database/backup_intuitive_care.sql` na primeira inicialização.
- A API Flask fica disponível em **`http://localhost:5000`**.
- Credenciais demonstrativas pré-carregadas no backup SQL:
  - **E-mail:** `admin@intuitivecare.com.br`
  - **Senha:** `Senha@123`

### 3. Executando o Backend Localmente (sem Docker)

```bash
pip install -r backend/requirements.txt
# Opcional para modo demonstração local com SQLite (ou configure DB_ENGINE=mysql no .env):
set DB_ENGINE=sqlite
python -m backend.app
```

### 4. Reaproveitando e Executando a Pipeline ETL (Opcional para Carga Completa da ANS)

```bash
pip install -r requirements.txt
python etl/scraping.py
python etl/processamento.py
python etl/enriquecimento.py
python etl/importar_sql.py
```

### 5. Executando o Aplicativo Mobile Flutter

```bash
cd frontend
flutter pub get
# Emulador Android (usa http://10.0.2.2:5000/api automaticamente):
flutter run

# Ou especificar IP da API manualmente (ex: dispositivo físico na mesma rede):
flutter run --dart-define=API_URL=http://192.168.0.10:5000/api
```

### 6. Executando Testes Automatizados

**Backend (Python unittest):**
```bash
python -m unittest discover -s backend/tests -v
```

**Frontend (Flutter test & analyze):**
```bash
cd frontend
flutter analyze
flutter test
```

### 7. Gerando o Pacote Compactado do Backend + SQL (Seção 4.2)

```bash
python utils/gerar_entregavel_backend.py
```

O arquivo `dist/intuitive_care_backend_e_sql.zip` será gerado contendo o código-fonte completo do backend, ETL, `backup_intuitive_care.sql` e arquivos de configuração.

---

## Documentação Complementar

- [Plano de Ataque da Migração](docs/PLANO_DE_ATAQUE.md)
- [Relatório Técnico Completo (Seção 4.3)](docs/RELATORIO_TECNICO.md)
