from backend.tests.api_test_base import ApiTestCase  # noqa: F401 - configura APP_ENV/SQLite antes dos imports da API

import unittest

from sqlalchemy import text

from backend.database.connection import get_connection
from backend.models.permissoes import PERMISSOES


class PerfisEAnaliticoTestCase(ApiTestCase):
    """Regras de perfil do MVP (ADMIN x COLABORADOR) e endpoints analíticos."""

    def _seed_analitico(self):
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

        multi = self.client.get(
            "/api/explorar?porte=pequeno,grande&faixa_despesa=ate_10mi,acima_1bi"
            "&consolidacao=consolidado,pendente",
            headers=admin,
        ).get_json()
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

    def test_colaborador_somente_leitura(self):
        token = self._login("colaborador@intuitivecare.com.br", "Colaborador@2025")
        h = self._auth_headers(token)
        me = self.client.get("/api/auth/me", headers=h).get_json()["usuario"]
        self.assertEqual(me["perfil"], "COLABORADOR")
        self.assertEqual(self.client.post("/api/operadoras", json={}, headers=h).status_code, 403)
        self.assertEqual(
            self.client.patch("/api/operadoras/326305/status", json={"status": "Inativa"}, headers=h).status_code,
            403,
        )
        self.assertEqual(self.client.delete("/api/operadoras/326305", headers=h).status_code, 403)
        self.assertNotIn("dados.exportar", me["permissoes"])
        self.assertNotIn("operadoras.criar", me["permissoes"])

    def test_regras_de_perfil_gravadas_no_banco(self):
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

    def test_exportacao_csv_somente_admin(self):
        colab = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        self.assertEqual(self.client.get("/api/operadoras/exportar.csv", headers=colab).status_code, 403)
        h = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        res = self.client.get("/api/operadoras/exportar.csv", headers=h)
        self.assertEqual(res.status_code, 200)
        self.assertIn("text/csv", res.content_type)
        self.assertTrue(res.data.decode("utf-8").lstrip("\ufeff").startswith("Registro ANS;CNPJ"))

    def test_painel_escopo_por_perfil(self):
        self._seed_analitico()
        admin = self._auth_headers(self._login_demo())
        res_admin = self.client.get("/api/painel?escopo=admin", headers=admin).get_json()
        self.assertAlmostEqual(res_admin["admin"]["total_despesas"], 110.0)
        self.assertEqual(res_admin["colaborador"]["ranking"], [])

        res_colab = self.client.get("/api/painel?escopo=colaborador", headers=admin).get_json()
        self.assertAlmostEqual(res_colab["colaborador"]["sinistralidade"], 110 / 150)
        self.assertEqual(res_colab["admin"]["total_despesas"], 0.0)
        self.assertEqual(res_colab["admin"]["modalidades"], [])


if __name__ == "__main__":
    unittest.main()
