from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import text

from backend.database.connection import get_connection


class DespesaRepository:
    """Camada de persistência CRUD e agregações analíticas para a tabela 'despesas'."""

    @staticmethod
    def list_paginated(
        page: int = 1,
        limit: int = 20,
        reg_ans: str = "",
        ano: Optional[int] = None,
        trimestre: Optional[int] = None,
        semestre: Optional[int] = None,
    ) -> Tuple[List[Dict[str, Any]], int]:
        offset = (page - 1) * limit
        where_clauses = ["1=1"]
        params: Dict[str, Any] = {"limit": limit, "offset": offset}

        if reg_ans:
            where_clauses.append("d.reg_ans = :reg_ans")
            params["reg_ans"] = reg_ans
        if ano is not None:
            where_clauses.append("d.ano = :ano")
            params["ano"] = ano
        if trimestre is not None:
            where_clauses.append("d.trimestre = :trimestre")
            params["trimestre"] = trimestre
        if semestre is not None:
            # 1º semestre = trimestres 1 e 2; 2º semestre = trimestres 3 e 4.
            where_clauses.append("d.trimestre BETWEEN :tri_ini AND :tri_fim")
            params["tri_ini"] = 1 if semestre == 1 else 3
            params["tri_fim"] = 2 if semestre == 1 else 4

        where_sql = " AND ".join(where_clauses)

        with get_connection() as conn:
            total = conn.execute(
                text(f"SELECT COUNT(*) FROM despesas d WHERE {where_sql}"),
                params,
            ).scalar_one()

            rows = (
                conn.execute(
                    text(
                        f"SELECT d.*, o.razao_social, o.uf "
                        f"FROM despesas d "
                        f"JOIN operadoras o ON d.reg_ans = o.registro_ans "
                        f"WHERE {where_sql} "
                        f"ORDER BY d.ano DESC, d.trimestre DESC, d.id DESC "
                        f"LIMIT :limit OFFSET :offset"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
            return [dict(r) for r in rows], int(total)

    @staticmethod
    def anos_disponiveis() -> List[int]:
        with get_connection() as conn:
            rows = conn.execute(text("SELECT DISTINCT ano FROM despesas ORDER BY ano DESC")).all()
            return [int(r[0]) for r in rows]

    @staticmethod
    def list_by_operadora(registro_ans: str) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = (
                conn.execute(
                    text(
                        "SELECT d.*, o.razao_social, o.uf "
                        "FROM despesas d "
                        "JOIN operadoras o ON d.reg_ans = o.registro_ans "
                        "WHERE d.reg_ans = :reg_ans "
                        "ORDER BY d.ano DESC, d.trimestre DESC, d.id DESC"
                    ),
                    {"reg_ans": registro_ans},
                )
                .mappings()
                .all()
            )
            return [dict(r) for r in rows]

    @staticmethod
    def find_by_id(despesa_id: int) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = (
                conn.execute(
                    text(
                        "SELECT d.*, o.razao_social, o.uf "
                        "FROM despesas d "
                        "JOIN operadoras o ON d.reg_ans = o.registro_ans "
                        "WHERE d.id = :id LIMIT 1"
                    ),
                    {"id": despesa_id},
                )
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def create(data: Dict[str, Any]) -> Dict[str, Any]:
        with get_connection() as conn:
            res = conn.execute(
                text(
                    "INSERT INTO despesas (reg_ans, ano, trimestre, valor_despesa, categoria, descricao) "
                    "VALUES (:reg_ans, :ano, :trimestre, :valor_despesa, :categoria, :descricao)"
                ),
                data,
            )
            new_id = res.lastrowid
        return DespesaRepository.find_by_id(new_id)  # type: ignore[return-value]

    @staticmethod
    def update(despesa_id: int, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        fields = ["reg_ans", "ano", "trimestre", "valor_despesa", "categoria", "descricao"]
        set_clauses = [f"{f} = :{f}" for f in fields if f in data]
        if not set_clauses:
            return DespesaRepository.find_by_id(despesa_id)

        params = {f: data[f] for f in fields if f in data}
        params["id"] = despesa_id

        with get_connection() as conn:
            res = conn.execute(
                text(f"UPDATE despesas SET {', '.join(set_clauses)} WHERE id = :id"),
                params,
            )
            if res.rowcount == 0:
                return None

        return DespesaRepository.find_by_id(despesa_id)

    @staticmethod
    def delete(despesa_id: int) -> bool:
        with get_connection() as conn:
            res = conn.execute(
                text("DELETE FROM despesas WHERE id = :id"),
                {"id": despesa_id},
            )
            return res.rowcount > 0

    @staticmethod
    def get_dashboard_statistics() -> Dict[str, Any]:
        with get_connection() as conn:
            top_ufs = (
                conn.execute(
                    text(
                        "SELECT o.uf, SUM(d.valor_despesa) AS total, COUNT(DISTINCT o.registro_ans) AS qtd_operadoras "
                        "FROM operadoras o "
                        "JOIN despesas d ON o.registro_ans = d.reg_ans "
                        "GROUP BY o.uf "
                        "ORDER BY total DESC "
                        "LIMIT 5"
                    )
                )
                .mappings()
                .all()
            )

            totals = (
                conn.execute(
                    text(
                        "SELECT "
                        "COALESCE(SUM(valor_despesa), 0) AS total_geral, "
                        "COALESCE(AVG(valor_despesa), 0) AS media_despesa, "
                        "COUNT(*) AS total_lancamentos "
                        "FROM despesas"
                    )
                )
                .mappings()
                .first()
            )

            total_operadoras = conn.execute(text("SELECT COUNT(*) FROM operadoras")).scalar_one()

            serie_trimestral = (
                conn.execute(
                    text(
                        "SELECT ano, trimestre, SUM(valor_despesa) AS total "
                        "FROM despesas "
                        "GROUP BY ano, trimestre "
                        "ORDER BY ano ASC, trimestre ASC"
                    )
                )
                .mappings()
                .all()
            )

            top_operadoras = (
                conn.execute(
                    text(
                        "SELECT o.registro_ans, o.razao_social, o.uf, SUM(d.valor_despesa) AS total "
                        "FROM operadoras o "
                        "JOIN despesas d ON o.registro_ans = d.reg_ans "
                        "GROUP BY o.registro_ans, o.razao_social, o.uf "
                        "ORDER BY total DESC "
                        "LIMIT 5"
                    )
                )
                .mappings()
                .all()
            )

            return {
                "total_geral": float(totals["total_geral"]) if totals else 0.0,
                "media_despesa": float(totals["media_despesa"]) if totals else 0.0,
                "total_lancamentos": int(totals["total_lancamentos"]) if totals else 0,
                "total_operadoras": int(total_operadoras or 0),
                "top_ufs": [
                    {
                        "uf": r["uf"],
                        "total": float(r["total"]),
                        "qtd_operadoras": int(r["qtd_operadoras"]),
                    }
                    for r in top_ufs
                ],
                "serie_trimestral": [
                    {
                        "ano": int(r["ano"]),
                        "trimestre": int(r["trimestre"]),
                        "periodo": f"{r['trimestre']}º trimestre de {r['ano']}",
                        "total": float(r["total"]),
                    }
                    for r in serie_trimestral
                ],
                "top_operadoras": [
                    {
                        "registro_ans": r["registro_ans"],
                        "razao_social": r["razao_social"],
                        "uf": r["uf"],
                        "total": float(r["total"]),
                    }
                    for r in top_operadoras
                ],
            }
