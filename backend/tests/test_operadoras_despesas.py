from backend.tests.api_test_base import ApiTestCase  # noqa: F401 - configura APP_ENV/SQLite antes dos imports da API

import unittest


class OperadorasEDespesasApiTestCase(ApiTestCase):
    """Testes de CRUD e regras de negócio para operadoras, despesas e estatísticas."""

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

    def test_busca_cnpj_com_mascara(self):
        admin = self._auth_headers(self._login("admin@intuitivecare.com.br", "Admin@2025"))
        res = self.client.get("/api/operadoras?search=00.011.122/0001-83", headers=admin).get_json()
        self.assertEqual([o["registro_ans"] for o in res["data"]], ["326305"])


if __name__ == "__main__":
    unittest.main()
