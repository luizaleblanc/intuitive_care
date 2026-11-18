import os
import sys

# Garante que o diretório raiz esteja no sys.path
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

os.environ.setdefault("APP_ENV", "production")

for variavel in ("SECRET_KEY", "DB_HOST", "DB_USER", "DB_PASSWORD", "DB_NAME"):
    if not os.getenv(variavel):
        raise RuntimeError(f"Variável de ambiente obrigatória ausente: {variavel}")

from backend.app import create_app  # noqa: E402

# O schema e os dados são preparados por utils/migrar_para_nuvem.py, não a cada cold start.
app = create_app(init_db=False)
