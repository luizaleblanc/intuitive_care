import os
import unittest

os.environ["APP_ENV"] = "test"
os.environ["DB_ENGINE"] = "sqlite"
os.environ["SQLITE_PATH"] = ":memory:"

from backend.app import create_app
from backend.config import Config
from backend.database.connection import reset_engine
from backend.database.init_db import initialize_database


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
            json={"email": "admin@intuitivecare.com.br", "senha": "Senha@123"},
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
                "senha": "Teste123",
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
                "senha": "Teste123",
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

    def test_password_recovery_flow(self):
        forgot_res = self.client.post(
            "/api/auth/forgot-password",
            json={"email": "admin@intuitivecare.com.br"},
        )
        self.assertEqual(forgot_res.status_code, 200)
        forgot_data = forgot_res.get_json()
        self.assertTrue(forgot_data["email_enviado"])
        code = forgot_data.get("codigo_demonstracao")
        self.assertIsNotNone(code)

        # Redefinição com código incorreto falha
        bad_reset = self.client.post(
            "/api/auth/reset-password",
            json={
                "email": "admin@intuitivecare.com.br",
                "codigo": "000000",
                "nova_senha": "NovaSenha123",
            },
        )
        self.assertEqual(bad_reset.status_code, 400)

        # Redefinição com código correto funciona
        ok_reset = self.client.post(
            "/api/auth/reset-password",
            json={
                "email": "admin@intuitivecare.com.br",
                "codigo": code,
                "nova_senha": "NovaSenha123",
            },
        )
        self.assertEqual(ok_reset.status_code, 200)

        # Senha antiga falha, senha nova autentica
        old_login = self.client.post(
            "/api/auth/login",
            json={"email": "admin@intuitivecare.com.br", "senha": "Senha@123"},
        )
        self.assertEqual(old_login.status_code, 401)

        new_login = self.client.post(
            "/api/auth/login",
            json={"email": "admin@intuitivecare.com.br", "senha": "NovaSenha123"},
        )
        self.assertEqual(new_login.status_code, 200)

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
