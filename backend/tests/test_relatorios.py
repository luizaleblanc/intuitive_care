import os
import unittest
from io import BytesIO
from unittest.mock import patch

os.environ["APP_ENV"] = "test"
os.environ["DB_ENGINE"] = "sqlite"
os.environ["SQLITE_PATH"] = ":memory:"

from openpyxl import load_workbook
from sqlalchemy import text

from backend.app import create_app
from backend.config import Config
from backend.database.connection import get_connection, reset_engine
from backend.database.init_db import initialize_database
from backend.services import relatorio_service as rel_mod
from backend.services.relatorio_service import FMT_INT, FMT_MOEDA, FMT_PCT, RelatorioService


class RelatoriosEtlTestCase(unittest.TestCase):
    """Testes abrangentes da geração de planilhas XLSX/CSV/JSON a partir das bases ETL da ANS."""

    def setUp(self):
        Config.DB_ENGINE = "sqlite"
        Config.SQLITE_PATH = ":memory:"
        Config.APP_ENV = "test"
        reset_engine()
        self.app = create_app(init_db=False, seed_db=False)
        initialize_database(seed=True)
        self._popular_bases_etl()
        self.client = self.app.test_client()

    def tearDown(self):
        reset_engine()

    def _popular_bases_etl(self):
        """Popula demonstracoes_operadora, beneficiarios_trimestre, contas_setor, lotes_etl e status/porte em operadoras."""
        with get_connection() as conn:
            # Atualiza porte (beneficiarios) e status em operadoras seed para testar filtros
            conn.execute(text("UPDATE operadoras SET status='Ativa', beneficiarios=250000, beneficiarios_mh=200000 WHERE registro_ans='326305'"))  # AMIL - SP - Grande
            conn.execute(text("UPDATE operadoras SET status='Ativa', beneficiarios=150000, beneficiarios_mh=130000 WHERE registro_ans='302147'"))  # BRADESCO - RJ - Grande
            conn.execute(text("UPDATE operadoras SET status='Ativa', beneficiarios=60000, beneficiarios_mh=55000 WHERE registro_ans='359017'"))    # UNIMED JP - PB - Médio
            conn.execute(text("UPDATE operadoras SET status='Inativa', beneficiarios=8000, beneficiarios_mh=8000 WHERE registro_ans='352501'"))    # UNIMED CURITIBA - PR - Pequeno

            demos = [
                # (reg_ans, ano, tri, contraprestacoes, eventos, eventos_mh, comercializacao, administrativas)
                ("326305", 2024, 3, 250000000.00, 185000000.00, 175000000.00, 12000000.00, 18000000.00),
                ("326305", 2024, 4, 260000000.00, 198000000.00, 188000000.00, 13000000.00, 19000000.00),
                ("326305", 2025, 1, 280000000.00, 210000000.00, 200000000.00, 14000000.00, 20000000.00),
                ("302147", 2024, 4, 300000000.00, 265000000.00, 250000000.00, 10000000.00, 15000000.00),
                ("302147", 2025, 1, 310000000.00, 275000000.00, 260000000.00, 11000000.00, 16000000.00),
                ("359017", 2025, 1, 50000000.00, 32000000.00, 30000000.00, 2000000.00, 4000000.00),
                ("352501", 2024, 4, 10000000.00, 7500000.00, 7000000.00, 500000.00, 900000.00),
            ]
            for d in demos:
                conn.execute(
                    text(
                        "INSERT INTO demonstracoes_operadora "
                        "(reg_ans, ano, trimestre, contraprestacoes, eventos, eventos_mh, comercializacao, administrativas) "
                        "VALUES (:r, :a, :t, :c, :e, :emh, :com, :adm)"
                    ),
                    {"r": d[0], "a": d[1], "t": d[2], "c": d[3], "e": d[4], "emh": d[5], "com": d[6], "adm": d[7]},
                )

            benefs = [
                ("326305", 2024, 3, 190000, 45000),
                ("326305", 2024, 4, 195000, 48000),
                ("326305", 2025, 1, 200000, 50000),
                ("302147", 2024, 4, 125000, 20000),
                ("302147", 2025, 1, 130000, 20000),
                ("359017", 2025, 1, 55000, 5000),
                ("352501", 2024, 4, 8000, 0),
            ]
            for b in benefs:
                conn.execute(
                    text(
                        "INSERT INTO beneficiarios_trimestre (reg_ans, ano, trimestre, medico_hospitalar, odontologico) "
                        "VALUES (:r, :a, :t, :mh, :od)"
                    ),
                    {"r": b[0], "a": b[1], "t": b[2], "mh": b[3], "od": b[4]},
                )

            contas = [
                (2024, 4, "31", "RECEITAS DE CONTRAPRESTAÇÕES", 0, 570000000.00),
                (2024, 4, "41", "EVENTOS INDENIZÁVEIS LÍQUIDOS", 0, 470500000.00),
                (2024, 4, "411", "Eventos Médico-Hospitalares", 1, 445000000.00),
                (2025, 1, "31", "RECEITAS DE CONTRAPRESTAÇÕES", 0, 640000000.00),
                (2025, 1, "41", "EVENTOS INDENIZÁVEIS LÍQUIDOS", 0, 517000000.00),
                (2025, 1, "46", "DESPESAS ADMINISTRATIVAS", 0, 40000000.00),
            ]
            for c in contas:
                conn.execute(
                    text(
                        "INSERT INTO contas_setor (ano, trimestre, codigo, descricao, nivel, valor) "
                        "VALUES (:a, :t, :cod, :desc, :niv, :val)"
                    ),
                    {"a": c[0], "t": c[1], "cod": c[2], "desc": c[3], "niv": c[4], "val": c[5]},
                )

            lotes = [
                (2024, 3, 12000, 1, 1, "Luiza Leblanc", "2025-01-10 10:30:00"),
                (2024, 4, 35000, 3, 1, "Luiza Leblanc", "2025-02-15 14:00:00"),
                (2025, 1, 36000, 3, 0, None, None),
            ]
            for l in lotes:
                conn.execute(
                    text(
                        "INSERT INTO lotes_etl (ano, trimestre, registros_extraidos, operadoras, auditado, auditado_por, auditado_em) "
                        "VALUES (:a, :t, :reg, :ops, :aud, :por, :em)"
                    ),
                    {"a": l[0], "t": l[1], "reg": l[2], "ops": l[3], "aud": l[4], "por": l[5], "em": l[6]},
                )

    def _login(self, email: str, senha: str) -> str:
        res = self.client.post("/api/auth/login", json={"email": email, "senha": senha})
        self.assertEqual(res.status_code, 200)
        return res.get_json()["token"]

    def _headers(self, token: str) -> dict:
        return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    def test_permissoes_endpoint_exportar(self):
        # Sem token -> 401
        res_unauth = self.client.post("/api/relatorios/exportar", json={"anos": [2025], "formato": "XLSX"})
        self.assertEqual(res_unauth.status_code, 401)

        # Colaborador não tem permissão dados.exportar -> 403
        token_colab = self._login("colaborador@intuitivecare.com.br", "Colaborador@2025")
        res_colab = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_colab),
            json={"anos": [2025], "formato": "XLSX"},
        )
        self.assertEqual(res_colab.status_code, 403)

    def test_exportar_xlsx_completo_todas_abas_formulas_tipos_e_graficos(self):
        token_admin = self._login("admin@intuitivecare.com.br", "Admin@2025")
        res = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_admin),
            json={"anos": [2024, 2025], "granularidade": "trimestre", "formato": "XLSX"},
        )
        self.assertEqual(res.status_code, 200)
        self.assertIn("spreadsheetml.sheet", res.mimetype)
        self.assertIn('attachment; filename="relatorio_etl_ans_2024_2025.xlsx"', res.headers.get("Content-Disposition", ""))

        wb = load_workbook(BytesIO(res.data), data_only=False)
        abas_esperadas = [
            "Resumo Executivo",
            "Evolução Período",
            "Por Modalidade",
            "Por UF",
            "Operadoras Consolidado",
            "Plano de Contas ANS",
            "Base ETL Demonstrações",
            "Lotes ETL",
            "Cadastro Operadoras",
        ]
        self.assertEqual(wb.sheetnames, abas_esperadas)

        # 1. Resumo Executivo: fórmulas vivas + números nativos (int/float, nunca str)
        ws_res = wb["Resumo Executivo"]
        self.assertIsInstance(ws_res["B6"].value, int)           # Operadoras
        self.assertIsInstance(ws_res["B7"].value, (int, float))  # Receitas
        self.assertEqual(ws_res["B7"].number_format, FMT_MOEDA)
        self.assertEqual(ws_res["B12"].value, "=B7-B8-B10-B11")
        self.assertEqual(ws_res["B13"].value, "=IF(B7>0,B8/B7,0)")
        self.assertEqual(ws_res["B13"].number_format, FMT_PCT)
        self.assertEqual(ws_res["B17"].value, "=B15+B16")

        # 2. Evolução Período: 3 trimestres + linha TOTAL + gráfico nativo BarChart
        ws_ev = wb["Evolução Período"]
        self.assertEqual(ws_ev.max_row, 8)  # 4 header + 3 períodos + 1 total
        self.assertEqual(len(ws_ev._charts), 1)
        self.assertEqual(ws_ev["I5"].value, "=D5-E5-G5-H5")
        self.assertEqual(ws_ev["D8"].value, "=SUM(D5:D7)")
        self.assertIsInstance(ws_ev["D5"].value, (int, float))
        self.assertIsInstance(ws_ev["M5"].value, int)

        # 3. Por Modalidade: gráfico nativo BarChart + fórmula de participação
        ws_mod = wb["Por Modalidade"]
        self.assertEqual(len(ws_mod._charts), 1)
        self.assertTrue(str(ws_mod["J5"].value).startswith("=IF(D$"))

        # 4. Operadoras Consolidado: fórmulas + tipos numéricos reais + CNPJ formatado
        ws_op = wb["Operadoras Consolidado"]
        self.assertIsInstance(ws_op["K5"].value, (int, float))
        self.assertIsInstance(ws_op["S5"].value, int)
        self.assertEqual(ws_op["P5"].value, "=K5-L5-N5-O5")
        self.assertEqual(ws_op["Q5"].value, "=IF(K5>0,L5/K5,0)")
        self.assertIn("/", str(ws_op["B5"].value))

        # 5. Plano de Contas ANS: todas as 6 contas inseridas + valor numérico
        ws_contas = wb["Plano de Contas ANS"]
        self.assertEqual(ws_contas.max_row, 10)  # 4 header + 6 contas
        self.assertIsInstance(ws_contas["H5"].value, (int, float))
        self.assertEqual(ws_contas["H5"].number_format, FMT_MOEDA)

        # 6. Base ETL Demonstrações: 7 linhas fato + fórmulas + tipos numéricos
        ws_base = wb["Base ETL Demonstrações"]
        self.assertEqual(ws_base.max_row, 11)  # 4 header + 7 demonstrações
        self.assertIsInstance(ws_base["K5"].value, (int, float))
        self.assertIsInstance(ws_base["Q5"].value, int)
        self.assertEqual(ws_base["P5"].value, "=IF(K5>0,L5/K5,0)")
        self.assertEqual(ws_base["S5"].value, "=Q5+R5")

        # 7. Lotes ETL + Cadastro Operadoras
        ws_lotes = wb["Lotes ETL"]
        self.assertEqual(ws_lotes.max_row, 8)  # 4 header + 3 lotes + 1 total
        self.assertEqual(ws_lotes["D8"].value, "=SUM(D5:D7)")
        ws_cad = wb["Cadastro Operadoras"]
        self.assertEqual(ws_cad.max_row, 12)  # 4 header + 8 operadoras seed
        self.assertIsInstance(ws_cad["I5"].value, int)
        self.assertEqual(ws_cad["I5"].number_format, FMT_INT)

    def test_xlsx_caminho_streaming_ooxml_preserva_estilos_e_formulas(self):
        """Força o caminho OOXML streaming (_STREAM_THRESHOLD=1) e valida reabertura limpa via openpyxl."""
        with patch.object(rel_mod, "_STREAM_THRESHOLD", 1):
            conteudo, nome = RelatorioService.gerar_xlsx({"anos": [2024, 2025]}, usuario_nome="Admin")
        self.assertEqual(nome, "relatorio_etl_ans_2024_2025.xlsx")

        wb_f = load_workbook(BytesIO(conteudo), data_only=False)
        wb_v = load_workbook(BytesIO(conteudo), data_only=True)

        ws_op_f = wb_f["Operadoras Consolidado"]
        ws_op_v = wb_v["Operadoras Consolidado"]
        self.assertEqual(ws_op_f.max_row, 9)  # 4 header + 4 operadoras + 1 total
        self.assertEqual(ws_op_f["P5"].value, "=K5-L5-N5-O5")
        self.assertEqual(ws_op_f["Q5"].value, "=IF(K5>0,L5/K5,0)")
        self.assertEqual(ws_op_f["K9"].value, "=SUM(K5:K8)")
        self.assertIsInstance(ws_op_v["P5"].value, (int, float))
        self.assertEqual(ws_op_f["K5"].number_format, FMT_MOEDA)
        self.assertEqual(ws_op_f["Q5"].number_format, FMT_PCT)

        ws_base_f = wb_f["Base ETL Demonstrações"]
        self.assertEqual(ws_base_f.max_row, 11)  # 4 header + 7 linhas
        self.assertIsInstance(ws_base_f["K5"].value, (int, float))
        self.assertEqual(ws_base_f["K5"].number_format, FMT_MOEDA)
        self.assertEqual(ws_base_f["P5"].value, "=IF(K5>0,L5/K5,0)")
        self.assertEqual(ws_base_f["S5"].value, "=Q5+R5")

        ws_contas = wb_f["Plano de Contas ANS"]
        self.assertEqual(ws_contas.max_row, 10)
        self.assertEqual(ws_contas["H5"].number_format, FMT_MOEDA)

        ws_cad = wb_f["Cadastro Operadoras"]
        self.assertEqual(ws_cad.max_row, 12)
        self.assertEqual(ws_cad["I5"].number_format, FMT_INT)

    def test_filtros_avancados_ano_trimestre_uf_modalidade_porte_status_consolidacao_ordem_limite(self):
        # Filtro por UF + Ano + Trimestre
        dados_sp = RelatorioService.coletar_dados(
            {"anos": [2024], "trimestres": [4], "ufs": ["SP"], "secoes": ["resumo", "operadoras", "base_demonstracoes"]}
        )
        self.assertEqual(dados_sp["kpis"]["operadoras"], 1)
        self.assertEqual(dados_sp["operadoras"][0]["registro_ans"], "326305")
        self.assertEqual(dados_sp["kpis"]["despesas"], 198000000.00)

        # Filtro por modalidade + porte
        dados_grande = RelatorioService.coletar_dados(
            {"anos": [2024, 2025], "modalidades": ["Seguradora Especializada em Saúde"], "portes": ["grande"]}
        )
        self.assertEqual([o["registro_ans"] for o in dados_grande["operadoras"]], ["302147"])

        # Filtro por status Inativa
        dados_inat = RelatorioService.coletar_dados({"anos": [2024, 2025], "statuses": ["Inativa"]})
        self.assertEqual([o["registro_ans"] for o in dados_inat["operadoras"]], ["352501"])

        # Filtro por consolidação (auditado vs pendente)
        dados_pend = RelatorioService.coletar_dados({"anos": [2024, 2025], "consolidacoes": ["pendente"]})
        self.assertTrue(all(int(r["ano"]) == 2025 and int(r["trimestre"]) == 1 for r in dados_pend["base_demonstracoes"]))

        # Ordenação por sinistralidade + limite_operadoras=2
        dados_ord = RelatorioService.coletar_dados(
            {"anos": [2025], "ordenar_por": "sinistralidade", "limite_operadoras": 2}
        )
        self.assertEqual(len(dados_ord["operadoras"]), 2)
        # 302147 tem 275/310 (~88.7%) > 326305 (210/280 = 75%) > 359017 (32/50 = 64%)
        self.assertEqual([o["registro_ans"] for o in dados_ord["operadoras"]], ["302147", "326305"])

        # Subconjunto de seções retorna apenas as abas solicitadas
        xlsx_sub, _ = RelatorioService.gerar_xlsx({"anos": [2025], "secoes": ["resumo", "ufs"]})
        wb_sub = load_workbook(BytesIO(xlsx_sub))
        self.assertEqual(wb_sub.sheetnames, ["Resumo Executivo", "Por UF"])

    def test_exportar_csv_utf8_bom_e_json_para_pdf(self):
        token_admin = self._login("admin@intuitivecare.com.br", "Admin@2025")

        # CSV com UTF-8 BOM
        res_csv = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_admin),
            json={"anos": [2025], "formato": "CSV"},
        )
        self.assertEqual(res_csv.status_code, 200)
        self.assertTrue(res_csv.data.startswith(b"\xef\xbb\xbf"))
        self.assertIn('filename="relatorio_etl_ans_2025.csv"', res_csv.headers.get("Content-Disposition", ""))
        texto_csv = res_csv.data.decode("utf-8-sig")
        self.assertIn("Resumo Executivo", texto_csv)
        self.assertIn("Plano de Contas ANS (ETL)", texto_csv)
        self.assertIn("Base ETL · Demonstrações", texto_csv)
        self.assertIn("Base ETL · Lotes Extraídos", texto_csv)
        self.assertIn("Base ETL · Cadastro CADOP", texto_csv)

        # JSON estruturado para renderização de PDF no frontend
        res_json = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_admin),
            json={"anos": [2025], "formato": "JSON", "limite_linhas_brutas": 50},
        )
        self.assertEqual(res_json.status_code, 200)
        body = res_json.get_json()
        self.assertEqual(body["nome_base"], "relatorio_etl_ans_2025")
        titulos = [a["titulo"] for a in body["abas"]]
        self.assertIn("Resumo Executivo", titulos)
        self.assertIn("Evolução no Período", titulos)
        self.assertIn("Por Modalidade", titulos)
        self.assertIn("Por UF", titulos)
        self.assertIn("Ranking de Operadoras", titulos)
        self.assertIn("Plano de Contas ANS (ETL)", titulos)
        self.assertIn("Base ETL · Demonstrações", titulos)
        self.assertIn("Base ETL · Lotes Extraídos", titulos)
        self.assertIn("Base ETL · Cadastro CADOP", titulos)

    def test_validacao_parametros_invalidos(self):
        token_admin = self._login("admin@intuitivecare.com.br", "Admin@2025")
        res = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_admin),
            json={"anos": [2099], "formato": "XLSX"},
        )
        self.assertEqual(res.status_code, 400)
        res_fmt = self.client.post(
            "/api/relatorios/exportar",
            headers=self._headers(token_admin),
            json={"anos": [2025], "formato": "DOCX"},
        )
        self.assertEqual(res_fmt.status_code, 400)


if __name__ == "__main__":
    unittest.main()
