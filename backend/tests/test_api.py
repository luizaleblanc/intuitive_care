import os
import unittest

os.environ["APP_ENV"] = "test"
os.environ["DB_ENGINE"] = "sqlite"
os.environ["SQLITE_PATH"] = ":memory:"

from datetime import datetime
from types import SimpleNamespace
from unittest.mock import patch

from sqlalchemy import text

from backend.app import create_app
from backend.config import Config
from backend.database.connection import get_connection, reset_engine
from backend.database.init_db import initialize_database
from backend.services.email_service import EmailService


class IntuitiveCareApiTestCase(unittest.TestCase):
    def setUp(self):
        Config.DB_ENGINE = "sqlite"
        Config.SQLITE_PATH = ":memory:"
        Config.APP_ENV = "test"
        reset_engine()
        self.app = create_app(init_db=False, seed_db=False)
        initialize_database(seed=True)
        self.client = self.app.test_client()

    def tearDown(self):
        reset_engine()

    def _auth_headers(self, token: str) -> dict:
        return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    def _login_demo(self) -> str:
        res = self.client.post(
            "/api/auth/login",
            json={"email": "admin@intuitivecare.com.br", "senha": "Admin@2025"},
        )
        self.assertEqual(res.status_code, 200)
        return res.get_json()["token"]

    def test_health_endpoint(self):
        res = self.client.get("/api/health")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["banco_dados"], "conectado")

    def test_auth_register_login_me_update_logout(self):
        # Cadastro de novo usuário
        reg_res = self.client.post(
            "/api/auth/register",
            json={
                "nome": "Maria Silva",
                "email": "maria@uninassau.edu.br",
                "senha": "Teste@123",
            },
        )
        self.assertEqual(reg_res.status_code, 201)
        reg_data = reg_res.get_json()
        self.assertIn("token", reg_data)
        self.assertEqual(reg_data["usuario"]["email"], "maria@uninassau.edu.br")
        self.assertNotIn("senha_hash", reg_data["usuario"])

        # E-mail duplicado deve retornar 409
        dup_res = self.client.post(
            "/api/auth/register",
            json={
                "nome": "Maria 2",
                "email": "maria@uninassau.edu.br",
                "senha": "Teste@123",
            },
        )
        self.assertEqual(dup_res.status_code, 409)

        token = reg_data["token"]

        # Consulta de usuário autenticado
        me_res = self.client.get("/api/auth/me", headers=self._auth_headers(token))
        self.assertEqual(me_res.status_code, 200)
        self.assertEqual(me_res.get_json()["usuario"]["nome"], "Maria Silva")

        # Atualização do perfil
        upd_res = self.client.put(
            "/api/auth/me",
            headers=self._auth_headers(token),
            json={"nome": "Maria Silva Souza"},
        )
        self.assertEqual(upd_res.status_code, 200)
        self.assertEqual(upd_res.get_json()["usuario"]["nome"], "Maria Silva Souza")

        # Logoff (revoga sessão no servidor)
        logout_res = self.client.post("/api/auth/logout", headers=self._auth_headers(token))
        self.assertEqual(logout_res.status_code, 200)

        # Token revogado deve ser rejeitado com 401
        after_logout = self.client.get("/api/auth/me", headers=self._auth_headers(token))
        self.assertEqual(after_logout.status_code, 401)

    def _pedir_reset(self, email="admin@intuitivecare.com.br"):
        """Pede o reset capturando o link, com o envio executado na mesma thread."""
        enviados = []
        thread = lambda target, args, daemon: SimpleNamespace(start=lambda: target(*args))
        with patch("backend.services.auth_service.Thread", thread), patch(
            "backend.services.auth_service.EmailService.enviar_reset_senha",
            side_effect=lambda para, nome, link: enviados.append(link),
        ):
            res = self.client.post("/api/auth/esqueci-senha", json={"email": email})
        token = enviados[0].split("token=")[1] if enviados else None
        return res, token

    def _redefinir(self, token, senha="NovaSenha@123"):
        return self.client.post("/api/auth/redefinir-senha", json={"token": token, "nova_senha": senha})

    def test_reset_senha_fluxo_completo(self):
        sessao = self._login_demo()
        res, token = self._pedir_reset()
        self.assertEqual(res.status_code, 200)
        self.assertNotIn("token", res.get_json())

        self.assertEqual(self._redefinir("invalido").status_code, 400)
        self.assertEqual(self._redefinir(token, "fraca").status_code, 400)
        self.assertEqual(self._redefinir(token).status_code, 200)

        reuso = self._redefinir(token, "OutraSenha@123")
        self.assertEqual(reuso.status_code, 400)
        self.assertIn("utilizado", reuso.get_json()["erro"])

        self.assertEqual(self.client.get("/api/auth/me", headers=self._auth_headers(sessao)).status_code, 401)
        antiga = {"email": "admin@intuitivecare.com.br", "senha": "Admin@2025"}
        self.assertEqual(self.client.post("/api/auth/login", json=antiga).status_code, 401)
        nova = self.client.post("/api/auth/login", json={**antiga, "senha": "NovaSenha@123"})
        self.assertEqual(nova.status_code, 200)
        self.assertEqual(nova.get_json()["usuario"]["perfil"], "ADMIN")

    def test_reset_senha_nao_revela_email(self):
        existente, token = self._pedir_reset()
        inexistente, sem_token = self._pedir_reset("ninguem@intuitivecare.com.br")
        self.assertEqual(existente.status_code, inexistente.status_code)
        self.assertEqual(existente.get_json(), inexistente.get_json())
        self.assertIsNotNone(token)
        self.assertIsNone(sem_token)

    def test_reset_senha_link_expirado_e_substituido(self):
        _, primeiro = self._pedir_reset()
        _, segundo = self._pedir_reset()
        self.assertIn("inválido", self._redefinir(primeiro).get_json()["erro"])
        with get_connection() as conn:
            conn.execute(text("UPDATE tokens_reset_senha SET expira_em = :e"), {"e": datetime(2020, 1, 1)})
        self.assertIn("expirou", self._redefinir(segundo).get_json()["erro"])

    def test_template_reset_preenche_e_escapa(self):
        corpo = EmailService._html_reset("<b>Ana</b>", "http://app/#/redefinir-senha?token=abc")
        self.assertIn("&lt;b&gt;Ana&lt;/b&gt;", corpo)
        self.assertIn('href="http://app/#/redefinir-senha?token=abc"', corpo)
        self.assertNotIn("$", corpo)

    def test_reset_senha_limite_de_pedidos(self):
        for email in ("admin@intuitivecare.com.br", "ninguem@intuitivecare.com.br"):
            for _ in range(3):
                self.assertEqual(self._pedir_reset(email)[0].status_code, 200)
            self.assertEqual(self._pedir_reset(email)[0].status_code, 429)

    def test_cadastro_grava_cargo_e_exige_senha_forte(self):
        dados = {"nome": "Ana Souza", "email": "ana@intuitivecare.com.br", "cargo": "Analista"}
        self.assertEqual(self.client.post("/api/auth/register", json={**dados, "senha": "Teste123"}).status_code, 400)
        res = self.client.post("/api/auth/register", json={**dados, "senha": "Teste@123"})
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.get_json()["usuario"]["cargo"], "Analista")
        self.assertEqual(res.get_json()["usuario"]["perfil"], "COLABORADOR")

    def test_operadoras_crud_and_business_rules(self):
        # Rota protegida sem token -> 401
        unauth = self.client.get("/api/operadoras")
        self.assertEqual(unauth.status_code, 401)

        token = self._login_demo()
        headers = self._auth_headers(token)

        # Listagem paginada
        list_res = self.client.get("/api/operadoras?page=1&limit=5", headers=headers)
        self.assertEqual(list_res.status_code, 200)
        self.assertEqual(len(list_res.get_json()["data"]), 5)
        self.assertEqual(list_res.get_json()["total"], 8)

        # Validação de CNPJ inválido no backend
        invalid_cnpj = self.client.post(
            "/api/operadoras",
            headers=headers,
            json={
                "registro_ans": "999001",
                "cnpj": "12345678000199",
                "razao_social": "Operadora Teste Invalida",
                "uf": "PB",
            },
        )
        self.assertEqual(invalid_cnpj.status_code, 400)

        # Validação de UF inválida
        invalid_uf = self.client.post(
            "/api/operadoras",
            headers=headers,
            json={
                "registro_ans": "999001",
                "cnpj": "00011122000183",
                "razao_social": "Operadora Teste UF",
                "uf": "XX",
            },
        )
        self.assertEqual(invalid_uf.status_code, 400)

        # Cadastro válido (POST) - CNPJ válido 889990000001xx -> vamos usar 11444777000161
        create_res = self.client.post(
            "/api/operadoras",
            headers=headers,
            json={
                "registro_ans": "999111",
                "cnpj": "11444777000161",
                "razao_social": "Clinica Vida PB Saude Ltda",
                "nome_fantasia": "Vida PB",
                "modalidade": "Medicina de Grupo",
                "cidade": "João Pessoa",
                "uf": "pb",
                "email": "contato@vidapb.com.br",
            },
        )
        self.assertEqual(create_res.status_code, 201)
        created = create_res.get_json()["data"]
        self.assertEqual(created["uf"], "PB")
        self.assertEqual(created["razao_social"], "CLINICA VIDA PB SAUDE LTDA")

        # Atualização (PUT)
        put_res = self.client.put(
            "/api/operadoras/999111",
            headers=headers,
            json={"nome_fantasia": "Vida PB Plus", "uf": "PE"},
        )
        self.assertEqual(put_res.status_code, 200)
        self.assertEqual(put_res.get_json()["data"]["uf"], "PE")

        # Regra de negócio: operadora seed com despesas não pode ser excluída sem force=true
        conflict_del = self.client.delete("/api/operadoras/359017", headers=headers)
        self.assertEqual(conflict_del.status_code, 409)

        # Exclusão válida (DELETE) da operadora sem despesas
        del_res = self.client.delete("/api/operadoras/999111", headers=headers)
        self.assertEqual(del_res.status_code, 200)

    def test_despesas_crud_and_statistics(self):
        token = self._login_demo()
        headers = self._auth_headers(token)

        # Cadastro de despesa vinculada a operadora inexistente -> 404
        not_found = self.client.post(
            "/api/despesas",
            headers=headers,
            json={"reg_ans": "000000", "ano": 2025, "trimestre": 2, "valor_despesa": 50000},
        )
        self.assertEqual(not_found.status_code, 404)

        # Cadastro com trimestre inválido -> 400
        bad_quarter = self.client.post(
            "/api/despesas",
            headers=headers,
            json={"reg_ans": "359017", "ano": 2025, "trimestre": 5, "valor_despesa": 50000},
        )
        self.assertEqual(bad_quarter.status_code, 400)

        # Cadastro válido (POST)
        create_res = self.client.post(
            "/api/despesas",
            headers=headers,
            json={
                "reg_ans": "359017",
                "ano": 2025,
                "trimestre": 2,
                "valor_despesa": 75000000.50,
                "categoria": "Despesa Assistencial",
                "descricao": "Lançamento 2T2025 PB",
            },
        )
        self.assertEqual(create_res.status_code, 201)
        desp = create_res.get_json()["data"]
        self.assertEqual(desp["faixa_porte"], "Médio Porte")
        desp_id = desp["id"]

        # Atualização (PUT)
        upd_res = self.client.put(
            f"/api/despesas/{desp_id}",
            headers=headers,
            json={"valor_despesa": 160000000.00},
        )
        self.assertEqual(upd_res.status_code, 200)
        self.assertEqual(upd_res.get_json()["data"]["faixa_porte"], "Grande Porte")

        # Consulta estatísticas consolidadas
        stats_res = self.client.get("/api/estatisticas", headers=headers)
        self.assertEqual(stats_res.status_code, 200)
        stats = stats_res.get_json()
        self.assertGreater(stats["total_geral"], 0)
        self.assertEqual(len(stats["top_ufs"]), 5)
        self.assertTrue(len(stats["serie_trimestral"]) >= 3)

        # Exclusão (DELETE)
        del_res = self.client.delete(f"/api/despesas/{desp_id}", headers=headers)
        self.assertEqual(del_res.status_code, 200)


if __name__ == "__main__":
    unittest.main()


class PerfisEAnaliticoTestCase(IntuitiveCareApiTestCase):
    """Regras de perfil do MVP (ADMIN x COLABORADOR) e endpoints analíticos."""

    def _login(self, email: str, senha: str) -> str:
        res = self.client.post("/api/auth/login", json={"email": email, "senha": senha})
        self.assertEqual(res.status_code, 200, res.get_json())
        return res.get_json()["token"]

    def _seed_analitico(self):
        from sqlalchemy import text

        from backend.database.connection import get_connection

        with get_connection() as conn:
            conn.execute(text("UPDATE operadoras SET status = 'Inativa' WHERE registro_ans = '352501'"))
            for ano, tri, ev, cp in ((2026, 1, 100.0, 140.0), (2026, 2, 110.0, 150.0)):
                conn.execute(
                    text(
                        "INSERT INTO demonstracoes_operadora (reg_ans, ano, trimestre, contraprestacoes, eventos, "
                        "eventos_mh, comercializacao, administrativas) VALUES ('326305', :a, :t, :cp, :ev, :ev, 5, 9)"
                    ),
                    {"a": ano, "t": tri, "ev": ev, "cp": cp},
                )
                conn.execute(
                    text(
                        "INSERT INTO contas_setor (ano, trimestre, codigo, descricao, nivel, valor) "
                        "VALUES (:a, :t, '41', 'EVENTOS', 0, :ev), (:a, :t, '41111', 'PROC', 3, :ev)"
                    ),
                    {"a": ano, "t": tri, "ev": ev},
                )
                conn.execute(
                    text("INSERT INTO lotes_etl (ano, trimestre, registros_extraidos, operadoras) VALUES (:a, :t, 10, 1)"),
                    {"a": ano, "t": tri},
                )

    def test_explorar_periodo_facetas_e_perfis(self):
        self._seed_analitico()
        admin = self._auth_headers(self._login_demo())
        colab = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))

        r = self.client.get("/api/explorar?ano_inicio=2026&ano_fim=2026&granularidade=trimestre", headers=admin)
        self.assertEqual(r.status_code, 200)
        d = r.get_json()
        self.assertEqual(d["kpis"]["despesas"], 210.0)
        self.assertEqual(d["kpis"]["receitas"], 290.0)
        self.assertAlmostEqual(d["kpis"]["sinistralidade"], 72.41, places=2)
        self.assertEqual([(s["ano"], s["trimestre"]) for s in d["serie"]], [(2026, 1), (2026, 2)])
        self.assertEqual(d["operadoras"][0]["registro_ans"], "326305")

        anual = self.client.get("/api/explorar?granularidade=ano", headers=admin).get_json()
        self.assertEqual(len(anual["serie"]), 1)
        self.assertIsNone(anual["serie"][0]["trimestre"])

        vazio = self.client.get("/api/explorar?modalidade=Cooperativa%20M%C3%A9dica", headers=admin).get_json()
        self.assertEqual(vazio["kpis"]["operadoras"], 0)
        filtrado = self.client.get("/api/explorar?uf=SP&faixa_despesa=ate_10mi", headers=admin).get_json()
        self.assertEqual(filtrado["kpis"]["operadoras"], 1)

        multi = self.client.get("/api/explorar?porte=pequeno,grande&faixa_despesa=ate_10mi,acima_1bi"
                                "&consolidacao=consolidado,pendente", headers=admin).get_json()
        self.assertEqual(multi["kpis"]["operadoras"], 0)  # AMIL de teste não tem beneficiários cadastrados
        especificos = self.client.get("/api/explorar?anos=2026&granularidade=ano", headers=admin).get_json()
        self.assertEqual(especificos["periodo"]["anos"], [2026])
        self.assertEqual(self.client.get("/api/explorar?anos=2019,2026", headers=admin).status_code, 400)
        tri1 = self.client.get("/api/explorar?anos=2026&trimestres=1", headers=admin).get_json()
        self.assertEqual(tri1["kpis"]["despesas"], 100.0)
        self.assertEqual(tri1["periodo"]["trimestres"], [1])
        tris12 = self.client.get("/api/explorar?anos=2026&trimestres=1,2", headers=admin).get_json()
        self.assertEqual(tris12["kpis"]["despesas"], 210.0)
        self.assertEqual(self.client.get("/api/explorar?trimestres=5", headers=admin).status_code, 400)

        comp = self.client.get("/api/explorar?comparar=1", headers=admin).get_json()
        self.assertIsNone(comp["comparativo"]["kpis"])

        self.assertEqual(self.client.get("/api/explorar?ano_inicio=2027&ano_fim=2026", headers=admin).status_code, 400)
        self.assertEqual(self.client.get("/api/explorar?porte=gigante", headers=admin).status_code, 400)
        self.assertEqual(colab_status := self.client.get("/api/explorar?status=Inativa", headers=colab).status_code, 200)
        self.assertEqual(self.client.get("/api/explorar", headers=colab).get_json()["facetas"]["status"], ["Ativa"])

    def test_preferencia_graficos_explorar(self):
        h = self._auth_headers(self._login_demo())
        ok = self.client.put("/api/auth/me", json={"preferencias": {"graficos_explorar": [
            {"tipo": "trend_area", "metrica": "sinistralidade"}]}}, headers=h)
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.get_json()["usuario"]["preferencias"]["graficos_explorar"][0]["tipo"], "trend_area")
        ruim = self.client.put("/api/auth/me", json={"preferencias": {"graficos_explorar": [
            {"tipo": "pizza3d", "metrica": "despesas"}]}}, headers=h)
        self.assertEqual(ruim.status_code, 400)

    def test_colaborador_somente_leitura(self):
        token = self._login("colaborador@intuitivecare.com.br", "Colaborador@2025")
        h = self._auth_headers(token)
        me = self.client.get("/api/auth/me", headers=h).get_json()["usuario"]
        self.assertEqual(me["perfil"], "COLABORADOR")
        self.assertEqual(self.client.post("/api/operadoras", json={}, headers=h).status_code, 403)
        self.assertEqual(
            self.client.patch("/api/operadoras/326305/status", json={"status": "Inativa"}, headers=h).status_code, 403
        )
        self.assertEqual(self.client.delete("/api/operadoras/326305", headers=h).status_code, 403)
        self.assertNotIn("dados.exportar", me["permissoes"])
        self.assertNotIn("operadoras.criar", me["permissoes"])

    def test_regras_de_perfil_gravadas_no_banco(self):
        from backend.models.permissoes import PERMISSOES

        with get_connection() as conn:
            linhas = conn.execute(text("SELECT perfil, permissao FROM permissoes_perfil")).all()
            perfis = {r[0] for r in conn.execute(text("SELECT perfil FROM perfis_acesso")).all()}
        esperado = {(p, c) for c, (_, ps) in PERMISSOES.items() for p in ps}
        self.assertEqual(set(map(tuple, linhas)), esperado)
        self.assertEqual(perfis, {"ADMIN", "COLABORADOR"})
        admin = self.client.get("/api/auth/me", headers=self._auth_headers(self._login_demo())).get_json()["usuario"]
        self.assertEqual(set(admin["permissoes"]), set(PERMISSOES))

    def test_inativas_visiveis_somente_para_admin(self):
        self._seed_analitico()
        admin = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        cons = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        total_admin = self.client.get("/api/operadoras", headers=admin).get_json()["total"]
        total_cons = self.client.get("/api/operadoras", headers=cons).get_json()["total"]
        self.assertEqual(total_admin, total_cons + 1)
        self.assertEqual(self.client.get("/api/operadoras/352501", headers=cons).status_code, 404)

    def test_busca_cnpj_com_mascara(self):
        admin = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        res = self.client.get("/api/operadoras?search=00.011.122/0001-83", headers=admin).get_json()
        self.assertEqual([o["registro_ans"] for o in res["data"]], ["326305"])

    def test_painel_contas_e_auditoria(self):
        self._seed_analitico()
        admin = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        painel = self.client.get("/api/painel", headers=admin).get_json()
        self.assertEqual(painel["periodo"], {"ano": 2026, "trimestre": 2})
        self.assertAlmostEqual(painel["admin"]["total_despesas"], 110.0)
        self.assertAlmostEqual(painel["colaborador"]["sinistralidade"], 110 / 150)
        self.assertEqual(len(painel["admin"]["serie"]), 2)

        contas = self.client.get("/api/contas?ano=2026&trimestre=2", headers=admin).get_json()
        self.assertAlmostEqual(contas["kpis"]["41"]["valor_atual"], 110.0)
        self.assertAlmostEqual(contas["kpis"]["41"]["valor_anterior"], 100.0)
        self.assertFalse(contas["lote"]["auditado"])

        res = self.client.post("/api/contas/lotes/2026/2/auditar", headers=admin)
        self.assertEqual(res.status_code, 200)
        contas = self.client.get("/api/contas?ano=2026&trimestre=2", headers=admin).get_json()
        self.assertTrue(contas["lote"]["auditado"])

        cons = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        self.assertEqual(self.client.post("/api/contas/lotes/2026/1/auditar", headers=cons).status_code, 403)

        # Múltiplos trimestres, UFs, modalidades e grupos de contas
        painel_multi = self.client.get(
            "/api/painel?ano=2026&trimestre=1,2&uf=SP,RJ&modalidade=Medicina%20de%20Grupo,Autogest%C3%A3o",
            headers=admin,
        ).get_json()
        self.assertEqual(len(painel_multi["periodos_selecionados"]), 2)
        self.assertAlmostEqual(painel_multi["admin"]["total_despesas"], 210.0)
        self.assertAlmostEqual(painel_multi["colaborador"]["despesas_mh"], 210.0)

        # Trimestre padrão sem ano deve selecionar apenas o ano mais recente com aquele trimestre.
        painel_tri = self.client.get("/api/painel?trimestre=1", headers=admin).get_json()
        self.assertEqual(painel_tri["periodos_selecionados"], [{"ano": 2026, "trimestre": 1}])

        contas_multi = self.client.get("/api/contas?ano=2026&trimestre=1,2&grupo=41,46", headers=admin).get_json()
        self.assertEqual(len(contas_multi["periodos_selecionados"]), 2)
        self.assertAlmostEqual(contas_multi["kpis"]["41"]["valor_atual"], 210.0)

        ops_multi = self.client.get(
            "/api/operadoras?modalidade=Medicina%20de%20Grupo,Cooperativa%20M%C3%A9dica", headers=admin
        ).get_json()
        self.assertGreaterEqual(ops_multi["total"], 2)

    def test_perfil_preferencias_e_foto(self):
        h = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        res = self.client.put(
            "/api/auth/me",
            json={
                "cargo": "Analista Externo",
                "data_nascimento": "1994-03-12",
                "foto": "data:image/png;base64,iVBORw0KGgo=",
                "preferencias": {
                    "tema": "escuro",
                    "formato_exportacao": "PDF",
                    "resumo_semanal": False,
                    "alerta_novos_dados": False,
                },
            },
            headers=h,
        )
        self.assertEqual(res.status_code, 200, res.get_json())
        u = res.get_json()["usuario"]
        self.assertEqual(u["cargo"], "Analista Externo")
        self.assertEqual(u["data_nascimento"], "1994-03-12")
        # Preferências exclusivas de Administrador não são alteradas por Colaborador.
        self.assertEqual(u["preferencias"]["formato_exportacao"], "CSV")
        self.assertTrue(u["preferencias"]["resumo_semanal"])
        self.assertTrue(u["preferencias"]["alerta_novos_dados"])
        self.assertEqual(u["preferencias"]["tema"], "escuro")
        self.assertEqual(u["preferencias"]["idioma"], "pt-BR")

        # Tema "sistema" não é mais aceito: apenas "claro" e "escuro".
        tema_invalido = self.client.put("/api/auth/me", json={"preferencias": {"tema": "sistema"}}, headers=h)
        self.assertEqual(tema_invalido.status_code, 400)

        admin = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        res_admin = self.client.put(
            "/api/auth/me",
            json={"preferencias": {"formato_exportacao": "PDF", "resumo_semanal": False, "alerta_novos_dados": False}},
            headers=admin,
        )
        self.assertEqual(res_admin.status_code, 200)
        prefs_admin = res_admin.get_json()["usuario"]["preferencias"]
        self.assertEqual(prefs_admin["formato_exportacao"], "PDF")
        self.assertFalse(prefs_admin["resumo_semanal"])
        self.assertFalse(prefs_admin["alerta_novos_dados"])

        ruim = self.client.put("/api/auth/me", json={"foto": "data:image/gif;base64,AAA"}, headers=h)
        self.assertEqual(ruim.status_code, 400)

    def test_exportacao_csv_somente_admin(self):
        colab = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        self.assertEqual(self.client.get("/api/operadoras/exportar.csv", headers=colab).status_code, 403)
        for email, senha in (("admin@intuitivecare.com.br", "Admin@2025"),):
            h = self._auth_headers(self._login(email, senha))
            res = self.client.get("/api/operadoras/exportar.csv", headers=h)
            self.assertEqual(res.status_code, 200)
            self.assertIn("text/csv", res.content_type)
            self.assertTrue(res.data.decode("utf-8").lstrip("﻿").startswith("Registro ANS;CNPJ"))
