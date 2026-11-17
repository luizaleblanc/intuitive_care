"""Corrige textos com mojibake (ex.: "SaÃºde") já gravados no banco.

Uso (MySQL do docker-compose, porta 3308):
    python utils/corrigir_encoding.py
Variáveis opcionais: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME.
"""
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)

from sqlalchemy import create_engine, inspect, text

from etl.texto import corrigir_texto


def main():
    url = (
        f"mysql+pymysql://{os.getenv('DB_USER', 'root')}:{os.getenv('DB_PASSWORD', 'root')}"
        f"@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '3308')}"
        f"/{os.getenv('DB_NAME', 'intuitive_care')}?charset=utf8mb4"
    )
    engine = create_engine(url)
    insp = inspect(engine)
    total = 0
    with engine.begin() as conn:
        for tabela in insp.get_table_names():
            pk = insp.get_pk_constraint(tabela)["constrained_columns"]
            colunas = [c["name"] for c in insp.get_columns(tabela)
                       if c["type"].python_type is str and c["name"] not in pk]
            if not pk or not colunas:
                continue
            sel = ", ".join(f"`{c}`" for c in pk + colunas)
            for linha in conn.execute(text(f"SELECT {sel} FROM `{tabela}`")).mappings():
                novos = {c: corrigir_texto(linha[c]) for c in colunas}
                mudou = {c: v for c, v in novos.items() if v != linha[c]}
                if mudou:
                    sets = ", ".join(f"`{c}` = :{c}" for c in mudou)
                    where = " AND ".join(f"`{c}` = :pk_{c}" for c in pk)
                    params = {**mudou, **{f"pk_{c}": linha[c] for c in pk}}
                    conn.execute(text(f"UPDATE `{tabela}` SET {sets} WHERE {where}"), params)
                    total += 1
    print(f"Linhas corrigidas: {total}")


if __name__ == "__main__":
    main()
