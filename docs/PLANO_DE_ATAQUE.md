# Plano de Ataque — Migração Arquitetural e Frontend (Intuitive Care)

**Instituição:** Centro Universitário Maurício de Nassau de João Pessoa (UNINASSAU)  
**Disciplinas:** Códigos de Alta Performance (Mobile) & Backend Frameworks  
**Projeto:** Intuitive Care — Plataforma Mobile de Análise e Gestão de Operadoras de Saúde e Despesas (ANS)

---

## 1. Diagnóstico do Estado Atual (Antes da Migração)

O repositório original possui uma base funcional de engenharia de dados (ETL em Python) e um protótipo web, porém incompatível com os novos critérios da 2ª Avaliação:

| Camada | Estado Original | Lacunas frente às Diretrizes |
| :--- | :--- | :--- |
| **ETL (Python)** | Scripts em `etl/` (`scraping.py`, `processamento.py`, `enriquecimento.py`, `importar_sql.py`, `queries_analiticas.py`) funcionais. | Divergência de nomes de chave entre scripts (`registro_ans` vs `reg_ans`) e uso de `if_exists='replace'` no Pandas, removendo chaves primárias e estrangeiras. |
| **Backend (Flask)** | Arquivo único `api/main_api.py` com apenas 4 rotas `GET` de leitura. | Sem separação de camadas (`routes`, `services`, `repositories`, `models`, `database`), sem operações `POST`/`PUT`/`DELETE` (CRUD completo), sem autenticação/sessão/logout, sem recuperação de senha por API de e-mail e sem validação centralizada de regras de negócio. |
| **Banco de Dados** | MySQL 8.0 no `docker-compose.yml`, sem dump SQL consolidado ou tabelas de usuários/sessões. | Falta schema relacional completo com FKs explícitas, tabelas de controle de usuário/tokens e arquivo de backup `.sql` exportado para entrega. |
| **Frontend** | Aplicação Web em Vue.js 3 (`web-app/` e `frontend/index.html`). | Precisa ser integralmente migrado para **Flutter** utilizando arquitetura **MVVM** com gerenciamento de estado via **Provider**, consumindo exclusivamente a API Flask. |
| **Documentação** | `README.md` curto focado em Docker + Vue. | Falta Relatório Técnico completo (9 tópicos obrigatórios da Seção 4.3) e documentação detalhada das mudanças e da comunicação Flutter ↔ Flask. |

---

## 2. Estratégia de Execução (Fases)

### Fase 1 — Padronização do Banco de Dados e Reaproveitamento do ETL
1. Definir o modelo relacional oficial em `backend/database/schema.sql` (MySQL 8.0) com 5 tabelas principais e relacionamentos por chave estrangeira:
   - `usuarios` (id, nome, email, senha_hash, perfil, ativo, criado_em, atualizado_em)
   - `sessoes_tokens` (id, usuario_id FK, token_jti, expira_em, revogado, criado_em)
   - `recuperacao_senha` (id, usuario_id FK, codigo_hash, expira_em, utilizado, criado_em)
   - `operadoras` (registro_ans PK, cnpj UNIQUE, razao_social, nome_fantasia, modalidade, logradouro, numero, complemento, bairro, cidade, uf, cep, telefone, email, representante, cargo_representante, criado_em, atualizado_em)
   - `despesas` (id PK AUTO_INCREMENT, reg_ans FK -> operadoras.registro_ans, ano, trimestre, valor_despesa, categoria, descricao, criado_em, atualizado_em)
2. Gerar `backend/database/backup_intuitive_care.sql` contendo DDL completo, relacionamentos, dados realistas de operadoras/despesas da ANS e usuário demonstrativo pré-cadastrado.
3. Ajustar `etl/importar_sql.py`, `etl/queries_analiticas.py` e `utils/criar_tabelas_docker.py` para reaproveitar integralmente a pipeline ETL existente sem destruir o schema nem as FKs.

### Fase 2 — Reestruturação do Backend (Python + Flask em Camadas)
1. Reorganizar o backend em `backend/` separando claramente:
   - `database/` (conexão SQLAlchemy/PyMySQL, schema e inicialização)
   - `models/` (estruturas de dados de domínio e serialização JSON)
   - `repositories/` (consultas SQL parametrizadas e persistência)
   - `services/` (regras de negócio centralizadas, validações de CNPJ/UF/valores, autenticação, revogação de sessão e serviço de e-mail por API)
   - `routes/` (blueprints REST com tratamento adequado de métodos HTTP e códigos de status)
2. Implementar autenticação completa (`/api/auth/*`):
   - `POST /api/auth/register` (cadastro com e-mail, nome e senha com hash seguro)
   - `POST /api/auth/login` (validação de credenciais e emissão de token assinado + registro de sessão)
   - `GET /api/auth/me` e `PUT /api/auth/me` (retorno e atualização do usuário autenticado via JSON)
   - `POST /api/auth/logout` (revogação imediata do token no banco de dados)
   - `POST /api/auth/forgot-password` e `POST /api/auth/reset-password` (recuperação de senha via integração com API de e-mail configurável — Resend/Brevo/SMTP — com modo de demonstração seguro para testes locais)
3. Implementar CRUD completo (`GET`, `POST`, `PUT`, `DELETE`) nas tabelas principais:
   - `/api/operadoras` (listar paginado/filtrado, detalhar, criar, atualizar, excluir com verificação de integridade)
   - `/api/despesas` e `/api/operadoras/<registro_ans>/despesas` (listar, detalhar, criar, atualizar, excluir com validação de operadora e trimestre/ano)
   - `/api/estatisticas` (indicadores agregados calculados exclusivamente no backend)
4. Criar suíte de testes automatizados (`backend/tests/test_api.py`) validando todo o fluxo de autenticação, CRUD, regras de negócio e respostas HTTP/JSON.

### Fase 3 — Migração do Frontend para Flutter (MVVM + Provider)
1. Remover o frontend legado em Vue.js (`web-app/` e `frontend/index.html`) e criar o projeto Flutter oficial em `frontend/`.
2. Estruturar estritamente no padrão **MVVM + Provider**:
   - `models/` (`UserModel`, `OperadoraModel`, `DespesaModel`, `EstatisticaModel`, `PaginatedResponse`)
   - `services/` (`ApiClient`, `SessionStorageService`, `AuthService`, `OperadoraService`, `DespesaService`, `EstatisticaService`)
   - `repositories/` (`AuthRepository`, `OperadoraRepository`, `DespesaRepository`, `EstatisticaRepository`)
   - `viewmodels/` (`AuthViewModel`, `DashboardViewModel`, `OperadoraViewModel`, `DespesaViewModel` estendendo `ChangeNotifier`)
   - `views/` (Splash, Login, Cadastro, Recuperação de Senha, Shell Principal, Dashboard, Listagem/Detalhes/Formulário de Operadoras, Listagem/Formulário de Despesas, Perfil do Usuário Autenticado)
   - `widgets/` (componentes reutilizáveis: cards de KPI, gráfico de barras por UF, cards de operadora, tiles de despesa, diálogos de confirmação e banners de erro)
3. Garantir tratamento explícito de erros e loading vindos da API Flask, além de testes unitários e de widget (`flutter test` e `flutter analyze`).

### Fase 4 — Infraestrutura, Relatório Técnico, README e Entrega GitHub
1. Atualizar `docker-compose.yml`, `intuitive_care_collection.json` e criar `utils/gerar_entregavel_backend.py` para geração da pasta compactada do backend (Seção 4.2).
2. Redigir `docs/RELATORIO_TECNICO.md` contemplando todos os 9 itens exigidos na Seção 4.3, incluindo registros reais dos testes executados.
3. Reescrever o `README.md` detalhando todas as mudanças da migração, arquitetura MVVM, endpoints da API e instruções passo a passo de execução.
4. Executar validação final completa (testes do backend, análise e testes do Flutter, verificação de backup SQL) e realizar commit/push para `https://github.com/luizaleblanc/intuitive_care`.

---

## 3. Checklist de Conformidade Acadêmica

- [x] Reaproveitamento da pipeline ETL em Python (`etl/`)
- [x] API REST em Python + Flask com comunicação 100% JSON
- [x] Uso correto de `GET`, `POST`, `PUT` e `DELETE` com CRUD completo
- [x] Autenticação por e-mail/senha, sessão autenticada, `logout` e recuperação de senha via API
- [x] Regras de negócio e validações centralizadas no backend
- [x] Backup SQL exportado com estrutura, relacionamentos e dados (`backup_intuitive_care.sql`)
- [x] Aplicativo Flutter em arquitetura MVVM (`Models`, `Views`, `ViewModels`, `Services`, `Repositories`, `Widgets`)
- [x] Gerenciamento de estado com `Provider` sem persistência substituta (sem Firebase)
- [x] Relatório Técnico completo + README atualizado + commit no GitHub
