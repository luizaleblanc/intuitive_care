from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import text

from backend.database.connection import get_connection


class OperadoraRepository:
    """Camada de persistência CRUD para a tabela 'operadoras'."""

    @staticmethod
    def list_paginated(
        page: int = 1,
        limit: int = 10,
        search: str = "",
        uf: str = "",
    ) -> Tuple[List[Dict[str, Any]], int]:
        offset = (page - 1) * limit
        where_clauses = ["1=1"]
        params: Dict[str, Any] = {"limit": limit, "offset": offset}

        if search:
            where_clauses.append(
                "(LOWER(o.razao_social) LIKE LOWER(:search) "
                "OR LOWER(COALESCE(o.nome_fantasia, '')) LIKE LOWER(:search) "
                "OR o.cnpj LIKE :search "
                "OR o.registro_ans LIKE :search)"
            )
            params["search"] = f"%{search}%"

        if uf:
            where_clauses.append("UPPER(o.uf) = UPPER(:uf)")
            params["uf"] = uf

        where_sql = " AND ".join(where_clauses)

        with get_connection() as conn:
            total = conn.execute(
                text(f"SELECT COUNT(*) FROM operadoras o WHERE {where_sql}"),
                params,
            ).scalar_one()

            rows = (
                conn.execute(
                    text(
                        f"SELECT o.*, COALESCE(SUM(d.valor_despesa), 0) AS total_despesas "
                        f"FROM operadoras o "
                        f"LEFT JOIN despesas d ON o.registro_ans = d.reg_ans "
                        f"WHERE {where_sql} "
                        f"GROUP BY o.registro_ans "
                        f"ORDER BY o.razao_social ASC "
                        f"LIMIT :limit OFFSET :offset"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
            return [dict(r) for r in rows], int(total)

    @staticmethod
    def find_by_identifier(identifier: str) -> Optional[Dict[str, Any]]:
        """Busca operadora por registro_ans ou CNPJ."""
        with get_connection() as conn:
            row = (
                conn.execute(
                    text(
                        "SELECT o.*, COALESCE(SUM(d.valor_despesa), 0) AS total_despesas "
                        "FROM operadoras o "
                        "LEFT JOIN despesas d ON o.registro_ans = d.reg_ans "
                        "WHERE o.registro_ans = :ident OR o.cnpj = :ident "
                        "GROUP BY o.registro_ans "
                        "LIMIT 1"
                    ),
                    {"ident": identifier},
                )
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def find_by_cnpj(cnpj: str) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = (
                conn.execute(
                    text("SELECT * FROM operadoras WHERE cnpj = :cnpj LIMIT 1"),
                    {"cnpj": cnpj},
                )
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def create(data: Dict[str, Any]) -> Dict[str, Any]:
        with get_connection() as conn:
            conn.execute(
                text(
                    "INSERT INTO operadoras ("
                    "registro_ans, cnpj, razao_social, nome_fantasia, modalidade, "
                    "logradouro, numero, complemento, bairro, cidade, uf, cep, "
                    "telefone, email, representante, cargo_representante"
                    ") VALUES ("
                    ":registro_ans, :cnpj, :razao_social, :nome_fantasia, :modalidade, "
                    ":logradouro, :numero, :complemento, :bairro, :cidade, :uf, :cep, "
                    ":telefone, :email, :representante, :cargo_representante"
                    ")"
                ),
                data,
            )
        return OperadoraRepository.find_by_identifier(data["registro_ans"])  # type: ignore[return-value]

    @staticmethod
    def update(registro_ans: str, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        fields = [
            "cnpj",
            "razao_social",
            "nome_fantasia",
            "modalidade",
            "logradouro",
            "numero",
            "complemento",
            "bairro",
            "cidade",
            "uf",
            "cep",
            "telefone",
            "email",
            "representante",
            "cargo_representante",
        ]
        set_clauses = [f"{f} = :{f}" for f in fields if f in data]
        if not set_clauses:
            return OperadoraRepository.find_by_identifier(registro_ans)

        params = {f: data[f] for f in fields if f in data}
        params["registro_ans"] = registro_ans

        with get_connection() as conn:
            res = conn.execute(
                text(f"UPDATE operadoras SET {', '.join(set_clauses)} WHERE registro_ans = :registro_ans"),
                params,
            )
            if res.rowcount == 0:
                return None

        return OperadoraRepository.find_by_identifier(registro_ans)

    @staticmethod
    def count_linked_despesas(registro_ans: str) -> int:
        with get_connection() as conn:
            count = conn.execute(
                text("SELECT COUNT(*) FROM despesas WHERE reg_ans = :reg_ans"),
                {"reg_ans": registro_ans},
            ).scalar_one()
            return int(count)

    @staticmethod
    def delete(registro_ans: str, cascade_despesas: bool = False) -> bool:
        with get_connection() as conn:
            if cascade_despesas:
                conn.execute(
                    text("DELETE FROM despesas WHERE reg_ans = :reg_ans"),
                    {"reg_ans": registro_ans},
                )
            res = conn.execute(
                text("DELETE FROM operadoras WHERE registro_ans = :registro_ans"),
                {"registro_ans": registro_ans},
            )
            return res.rowcount > 0
