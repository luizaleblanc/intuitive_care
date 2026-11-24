import os
import unittest

os.environ["APP_ENV"] = "test"
os.environ["DB_ENGINE"] = "sqlite"
os.environ["SQLITE_PATH"] = ":memory:"

from backend.app import create_app
from backend.config import Config
from backend.database.connection import reset_engine
from backend.database.init_db import initialize_database


class ApiTestCase(unittest.TestCase):
    """Fixture base compartilhada pelos testes de integração da API Flask."""

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

    def _login(self, email: str, senha: str) -> str:
        res = self.client.post("/api/auth/login", json={"email": email, "senha": senha})
        self.assertEqual(res.status_code, 200, res.get_json())
        return res.get_json()["token"]

    def _login_demo(self) -> str:
        return self._login("admin@intuitivecare.com.br", "Admin@2025")
