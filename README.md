# Intuitive Care — Plataforma Mobile de Análise e Gestão ANS

Sistema computacional completo composto por **Aplicativo Mobile em Flutter (Arquitetura MVVM + Provider)**, **API REST em Python + Flask (Arquitetura em Camadas)**, **Pipeline ETL em Python (Reaproveitada)** e **Banco de Dados Relacional MySQL 8.0**.

Projeto desenvolvido e migrado para atender rigorosamente às diretrizes da **2ª Avaliação** das disciplinas de **Códigos de Alta Performance (Mobile)** e **Backend Frameworks** — Curso de Graduação em Ciências da Computação (UNINASSAU João Pessoa).

---

## Sumário das Mudanças Realizadas na Migração

A tabela abaixo compara o estado **antigo (legado)** do projeto com o que está **100% implementado e ativo na versão atual**:

| Funcionalidade / Camada | Como era no Projeto Antigo (Antes) | Como está no Projeto Atual (Agora) |
| :--- | :--- | :--- |
| **Autenticação & Controle de Sessão** | ❌ **Inexistente no projeto original** (não havia login, senhas nem usuários; rotas eram abertas). | ✅ **100% Implementado e Ativo:**<br>• Cadastro (`POST /api/auth/register`) com senha criptografada em hash seguro.<br>• Login (`POST /api/auth/login`) com validação no backend e emissão de JWT.<br>• Identificação do usuário logado via JSON (`GET /api/auth/me`).<br>• Atualização de perfil (`PUT /api/auth/me`): nome, e-mail, cargo, telefone, data de nascimento, foto (JPG/PNG até 2 MB) e preferências.<br>• Logoff com revogação no banco (`POST /api/auth/logout` invalida a sessão em `sessoes_tokens`).<br>• Recuperação de senha por e-mail via API (`POST /api/auth/forgot-password` e `POST /api/auth/reset-password`). |
| **Perfis de Acesso** | ❌ Inexistentes. | ✅ **ADMIN** (leitura + escrita) e **CONSUMIDOR** (somente leitura). Toda rota de escrita exige ADMIN (`HTTP 403` para o Consumidor), e operadoras inativas só aparecem para o Administrador. |
| **Frontend** | ❌ Aplicação Web legada em Vue.js 3 + Tailwind CSS (`web-app/` e `frontend/index.html`). | ✅ **100% Migrado para Flutter** (`frontend/`, foco em web desktop) em **MVVM** (`models`, `views`, `viewmodels`, `services`, `repositories`) com **Provider** e rotas via **go_router**. Visual fiel ao **Design System Intuitive Care** (`frontend/web/design-system.html`): Página inicial, Login, Painel Geral, Operadoras ANS, Despesas Contábeis e Configurações de Perfil. |
| **Arquitetura do Backend** | ❌ Script monolítico em arquivo único `api/main_api.py` com apenas 4 endpoints `GET`. | ✅ **100% Reestruturado em Camadas** (`backend/`): separação clara em **Rotas (`routes/`)**, **Regras de Negócio e Validações (`services/`)**, **Persistência (`repositories/`)**, **Modelos (`models/`)** e **Banco (`database/`)**. |
| **Operações HTTP & CRUD** | ❌ Somente leitura (`GET`). | ✅ **CRUD Completo (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`)** em `operadoras`, `despesas` e no perfil de `usuarios`, mais endpoints analíticos (painel, plano de contas, auditoria de lotes e exportação CSV). |
| **Regras de Negócio** | ❌ Quase inexistentes (lógicas soltas na interface). | ✅ **Centralizadas e validadas no Backend**: dígito verificador do CNPJ (módulo 11), validação das 27 UFs, unicidade cadastral, bloqueio de integridade referencial ao excluir operadora com despesas (`HTTP 409`), status da operadora (Ativa / Em análise / Inativa), sinistralidade, ticket médio por vida e variação entre trimestres. |
| **Banco de Dados & ETL** | ❌ Carga ETL sobrescrevia tabelas apagando chaves (`if_exists='replace'`); sem backup SQL; dados de exemplo. | ✅ **Schema relacional com integridade e FKs** (`backend/database/schema.sql`, com migração automática em `init_db.py`), backup demonstrativo (`backend/database/backup_intuitive_care.sql`) e **pipeline ETL com dados reais da ANS**: demonstrações contábeis trimestrais (contas 31, 41, 43 e 46), operadoras ativas e canceladas e beneficiários por operadora. A carga é idempotente e corrige textos com acentuação quebrada. |

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
│   ├── models/                         # Modelos de domínio (Usuario + preferências, Operadora, Despesa)
│   ├── repositories/                   # Persistência SQL parametrizada (inclui analitico_repository.py)
│   ├── services/                       # Regras de negócio, validadores, auth JWT, e-mail e indicadores
│   ├── routes/                         # Blueprints REST e middlewares @token_required / @admin_required
│   └── tests/                          # Suíte automatizada de testes de integração da API
├── etl/                                # Pipeline ETL com dados abertos da ANS
│   ├── scraping.py                     # Baixa demonstrações contábeis, operadoras ativas/canceladas e beneficiários
│   ├── processamento.py                # Contas 31/41/43/46 por operadora e do setor (valor do trimestre = final − inicial)
│   ├── enriquecimento.py               # Cruzamento com Relatorio_cadop.csv e agregação estatística
│   ├── importar_sql.py                 # Carga idempotente no MySQL preservando PK/FK
│   ├── texto.py                        # Leitura UTF-8/latin1 e correção de acentuação quebrada
│   └── queries_analiticas.py           # Consultas analíticas SQL sobre a base ANS
├── frontend/                           # Aplicativo Flutter (MVVM + Provider), foco em web desktop
│   ├── pubspec.yaml                    # provider, http, go_router, google_fonts, lucide_icons, pdf, excel...
│   ├── web/design-system.html          # Design System Intuitive Care (aberto pelo botão "Design System")
│   ├── lib/
│   │   ├── main.dart                   # Injeção de dependências via MultiProvider
│   │   ├── app/                        # Tema (tokens de cor, tipografia, sombras) e rotas (go_router)
│   │   ├── config/api_config.dart      # URL base da API Flask (emulador Android / desktop / web)
│   │   ├── models/                     # UserModel, OperadoraModel, PainelModel, ContasModel
│   │   ├── services/                   # Comunicação HTTP/JSON com a API Flask (ApiClient + services)
│   │   ├── repositories/               # Intermediação entre ViewModels e Services
│   │   ├── viewmodels/                 # Auth, Painel, Operadoras e Contas
│   │   ├── views/                      # Início, Login, AppShell, Painel, Operadoras, Despesas e Perfil
│   │   └── shared/                     # Componentes do Design System (ui/), gráficos (charts/), marca (brand/) e utilitários (utils/)
│   └── test/                           # Testes unitários de modelos, formatação e ViewModels
├── docs/
│   ├── PLANO_DE_ATAQUE.md              # Plano de ataque da migração e checklist acadêmico
│   └── RELATORIO_TECNICO.md            # Relatório Técnico completo (Seção 4.3)
├── utils/
│   ├── corrigir_encoding.py            # Corrige acentuação quebrada já gravada no banco
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

Todas as requisições e respostas utilizam **JSON**. Rotas protegidas exigem cabeçalho `Authorization: Bearer <token>`. Rotas marcadas com **(ADMIN)** devolvem `HTTP 403` para o perfil Consumidor.

| Grupo | Método | Rota | Descrição |
| :--- | :--- | :--- | :--- |
| **Saúde** | `GET` | `/api/health` | Verifica status da API e conectividade com o SGBD |
| **Auth** | `POST` | `/api/auth/register` | Cadastro de usuário (perfil CONSUMIDOR) com e-mail, nome e senha |
| **Auth** | `POST` | `/api/auth/login` | Autenticação por e-mail/senha e emissão de JWT |
| **Auth** | `GET` | `/api/auth/me` | Retorna dados, perfil e preferências do usuário autenticado |
| **Auth** | `PUT` | `/api/auth/me` | Atualiza nome, e-mail, cargo, telefone, nascimento, foto e preferências |
| **Auth** | `POST` | `/api/auth/logout` | Encerra sessão revogando o token no banco de dados |
| **Auth** | `POST` | `/api/auth/forgot-password` | Gera código de recuperação e dispara e-mail via API |
| **Auth** | `POST` | `/api/auth/reset-password` | Valida código temporário e redefine a senha |
| **Painel** | `GET` | `/api/painel` | KPIs, série trimestral, modalidades e ranking (`ano`, `trimestre`, `uf`, `modalidade`) |
| **Contas** | `GET` | `/api/contas` | Plano de contas ANS do setor com comparação ao trimestre anterior (`ano`, `trimestre`, `grupo`) |
| **Contas** | `POST` | `/api/contas/lotes/<ano>/<trimestre>/auditar` | Marca o lote do trimestre como auditado **(ADMIN)** |
| **Operadoras** | `GET` | `/api/operadoras` | Lista paginada com busca (Registro ANS, razão social, nome fantasia ou CNPJ com/sem máscara) e filtros `uf`, `modalidade`, `status` |
| **Operadoras** | `GET` | `/api/operadoras/resumo` | Ativas, em análise, inativadas em 12 meses, beneficiários, modalidades e UFs |
| **Operadoras** | `GET` | `/api/operadoras/exportar.csv` | Exporta a lista filtrada em CSV |
| **Operadoras** | `GET` | `/api/operadoras/<id>` | Detalha operadora por `registro_ans` ou `cnpj` |
| **Operadoras** | `GET` | `/api/operadoras/<id>/despesas` | Lista despesas da operadora |
| **Operadoras** | `POST` | `/api/operadoras` | Cadastra nova operadora (valida CNPJ e UF no backend) **(ADMIN)** |
| **Operadoras** | `PUT` | `/api/operadoras/<id>` | Atualiza dados cadastrais da operadora **(ADMIN)** |
| **Operadoras** | `PATCH` | `/api/operadoras/<id>/status` | Inativa, reativa ou coloca em análise **(ADMIN)** |
| **Operadoras** | `DELETE` | `/api/operadoras/<id>` | Exclui operadora (bloqueia se houver despesas sem `?force=true`) **(ADMIN)** |
| **Despesas** | `GET` | `/api/despesas` | Lista despesas paginadas com filtros (`reg_ans`, `ano`, `trimestre`, `semestre`) |
| **Despesas** | `GET` | `/api/despesas/anos` | Anos com despesas carregadas |
| **Despesas** | `GET` | `/api/despesas/<id>` | Detalha lançamento de despesa |
| **Despesas** | `POST` | `/api/despesas` | Lança nova despesa vinculada a uma operadora válida **(ADMIN)** |
| **Despesas** | `PUT` | `/api/despesas/<id>` | Atualiza lançamento de despesa **(ADMIN)** |
| **Despesas** | `DELETE` | `/api/despesas/<id>` | Exclui lançamento de despesa **(ADMIN)** |
| **Estatísticas** | `GET` | `/api/estatisticas` | Indicadores legados: total geral, média, Top 5 UFs e Top operadoras |

---

## Como Executar o Projeto

### 1. Pré-requisitos

- **Python 3.11+**
- **Flutter SDK 3.x+**
- **Docker & Docker Compose** (ou instância local de **MySQL 8.0**)

### 2. Configurando o `.env`

Crie um arquivo `.env` na raiz do projeto, a partir de `backend/.env.example`. A API e o ETL leem esse arquivo automaticamente, e ele não é versionado. Cada linha deve seguir o formato `NOME=valor`, sem espaços no nome:

```env
DB_ENGINE=mysql
DB_HOST=127.0.0.1
DB_PORT=3308
DB_USER=root
DB_PASSWORD=sua_senha_do_mysql
DB_NAME=intuitive_care
```

### 3. Subindo Backend + Banco MySQL com Docker

```bash
docker-compose up --build -d
```

- O MySQL 8.0 sobe na porta **`3308`** (mapeada para `3306` interna) e executa automaticamente `backend/database/backup_intuitive_care.sql` na primeira inicialização.
- A API Flask fica disponível em **`http://localhost:5000`** e usa a senha do banco definida no `.env`.
- Ao iniciar, a API cria as tabelas novas e garante as contas de demonstração:

| Perfil | E-mail | Senha |
| :--- | :--- | :--- |
| Administrador | `admin@intuitivecare.com.br` | `Admin@2025` |
| Consumidor | `consumidor@intuitivecare.com.br` | `Consulta@2025` |

### 4. Executando o Backend Localmente (sem Docker)

```bash
pip install -r backend/requirements.txt
# Opcional para modo demonstração local com SQLite (no PowerShell: $env:DB_ENGINE = "sqlite"):
set DB_ENGINE=sqlite
python -m backend.app
```

### 5. Carregando os Dados Reais da ANS (Pipeline ETL)

```bash
pip install -r requirements.txt
python etl/scraping.py --anos 3   # demonstrações contábeis + operadoras ativas/canceladas + beneficiários
python etl/processamento.py       # contas 31/41/43/46 por operadora, plano de contas do setor e lotes
python etl/enriquecimento.py
python etl/importar_sql.py        # carga idempotente no MySQL (usa as variáveis DB_* do .env)
```

Fontes: `dadosabertos.ans.gov.br/FTP/PDA/` (`demonstracoes_contabeis`, `operadoras_de_plano_de_saude_ativas`, `operadoras_de_plano_de_saude_canceladas` e `beneficiarios_vinculos_tipo_contratacao_vda`). O valor de cada trimestre é `VL_SALDO_FINAL − VL_SALDO_INICIAL`, porque a DRE da ANS acumula os saldos ao longo do ano.

Para corrigir acentuação quebrada já gravada no banco: `python utils/corrigir_encoding.py`.

### 6. Executando o Aplicativo Flutter

```bash
cd frontend
flutter pub get
# Navegador (recomendado: telas desktop a partir de 1280px). Em localhost, usa http://localhost:5000/api automaticamente:
flutter run -d chrome

# Emulador Android (usa http://10.0.2.2:5000/api automaticamente):
flutter run

# Ou especificar a API manualmente (ex.: dispositivo físico na mesma rede):
flutter run --dart-define=API_URL=http://192.168.0.10:5000/api
```

Rotas do app: `/` (início), `/login`, `/painel`, `/operadoras`, `/despesas` e `/perfil`. As rotas autenticadas redirecionam para `/login` quando não há sessão.

### 7. Executando Testes Automatizados

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

### 8. Gerando o Pacote Compactado do Backend + SQL (Seção 4.2)

```bash
python utils/gerar_entregavel_backend.py
```

O arquivo `dist/intuitive_care_backend_e_sql.zip` será gerado contendo o código-fonte completo do backend, ETL, `backup_intuitive_care.sql` e arquivos de configuração.

---

## Documentação Complementar

- [Plano de Ataque da Migração](docs/PLANO_DE_ATAQUE.md)
- [Relatório Técnico Completo (Seção 4.3)](docs/RELATORIO_TECNICO.md)
