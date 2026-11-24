from backend.tests.api_test_base import ApiTestCase  # noqa: F401 - configura APP_ENV/SQLite antes dos imports da API

import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import patch

from sqlalchemy import text

from backend.database.connection import get_connection
from backend.services.email_service import EmailService


class IntuitiveCareApiTestCase(ApiTestCase):
    """Testes de saúde, autenticação, cadastro, redefinição de senha e perfil do usuário."""

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

    def test_preferencia_graficos_explorar(self):
        h = self._auth_headers(self._login_demo())
        ok = self.client.put(
            "/api/auth/me",
            json={"preferencias": {"graficos_explorar": [{"tipo": "trend_area", "metrica": "sinistralidade"}]}},
            headers=h,
        )
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.get_json()["usuario"]["preferencias"]["graficos_explorar"][0]["tipo"], "trend_area")
        ruim = self.client.put(
            "/api/auth/me",
            json={"preferencias": {"graficos_explorar": [{"tipo": "pizza3d", "metrica": "despesas"}]}},
            headers=h,
        )
        self.assertEqual(ruim.status_code, 400)

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

        # Persiste foto WebP, telefone e preferências e mantém após novo login (Colaborador).
        res_foto = self.client.put(
            "/api/auth/me",
            json={
                "telefone": "(83) 99999-1234",
                "foto": "data:image/webp;base64,UklGRh4AAABXRUJQ",
                "preferencias": {"tema": "escuro", "uf_padrao": "PB", "trimestre_padrao": 2},
            },
            headers=h,
        )
        self.assertEqual(res_foto.status_code, 200, res_foto.get_json())
        self.assertEqual(self.client.post("/api/auth/logout", headers=h).status_code, 200)
        h_novo = self._auth_headers(self._login("colaborador@intuitivecare.com.br", "Colaborador@2025"))
        recarregado = self.client.get("/api/auth/me", headers=h_novo).get_json()["usuario"]
        self.assertEqual(recarregado["cargo"], "Analista Externo")
        self.assertEqual(recarregado["telefone"], "(83) 99999-1234")
        self.assertEqual(recarregado["foto"], "data:image/webp;base64,UklGRh4AAABXRUJQ")
        self.assertEqual(recarregado["preferencias"]["tema"], "escuro")
        self.assertEqual(recarregado["preferencias"]["uf_padrao"], "PB")
        self.assertEqual(recarregado["preferencias"]["trimestre_padrao"], 2)

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

        ruim = self.client.put("/api/auth/me", json={"foto": "data:image/gif;base64,AAA"}, headers=h_novo)
        self.assertEqual(ruim.status_code, 400)


if __name__ == "__main__":
    unittest.main()
