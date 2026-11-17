import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from backend.database.init_db import initialize_database


def main():
    db_host = os.getenv("DB_HOST", "127.0.0.1")
    db_port = os.getenv("DB_PORT", "3307")
    db_user = os.getenv("DB_USER", "root")
    db_pass = os.getenv("DB_PASSWORD", "root")
    db_name = os.getenv("DB_NAME", "intuitive_care")

    url = f"mysql+pymysql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}?charset=utf8mb4"
    print(f"Inicializando schema e dados em {db_host}:{db_port}/{db_name}...")
    initialize_database(database_url=url, seed=True)
    print("Sucesso! Tabelas, relacionamentos e massa inicial verificados.")


if __name__ == "__main__":
    main()
