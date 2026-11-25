import re
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import bindparam, text

from backend.database.cache import obter_ou_carregar
from backend.database.connection import get_connection

# Despesa (conta 41) do trimestre mais recente carregado para cada operadora.
_SUBQUERY_ULTIMO_TRIMESTRE = (
    "LEFT JOIN ("
    "  SELECT dm.reg_ans, dm.eventos AS despesa_trimestre FROM demonstracoes_operadora dm "
    "  JOIN (SELECT ano, trimestre FROM demonstracoes_operadora "
    "        ORDER BY ano DESC, trimestre DESC LIMIT 1) ult "
    "    ON dm.ano = ult.ano AND dm.trimestre = ult.trimestre"
    ") dt ON dt.reg_ans = o.registro_ans "
)


class OperadoraRepository:
    """Camada de persistência CRUD para a tabela 'operadoras'."""

    @staticmethod
    def _filtros(
        search: str = "",
        uf: str = "",
        modalidade: str = "",
        status: str = "",
        incluir_inativas: bool = True,
    ) -> Tuple[str, Dict[str, Any], List[str]]:
        where = ["1=1"]
        params: Dict[str, Any] = {}
        expanding: List[str] = []

        if search:
            termo = search.strip()
            digitos = re.sub(r"\D", "", termo)
            condicoes = [
                "LOWER(o.razao_social) LIKE LOWER(:search)",
                "LOWER(COALESCE(o.nome_fantasia, '')) LIKE LOWER(:search)",
                "o.registro_ans LIKE :search",
                "o.cnpj LIKE :search",
            ]
            params["search"] = f"%{termo}%"
            # CNPJ/Registro buscáveis com ou sem máscara ("29.309.127/0001-79").
            if digitos and digitos != termo:
                condicoes += ["o.cnpj LIKE :digitos", "o.registro_ans LIKE :digitos"]
                params["digitos"] = f"%{digitos}%"
            where.append("(" + " OR ".join(condicoes) + ")")

        ufs = [u.strip().upper() for u in uf.split(",") if u.strip()]
        if ufs:
            where.append("UPPER(o.uf) IN :ufs")
            params["ufs"] = ufs
            expanding.append("ufs")
        modalidades = [m.strip() for m in modalidade.split(",") if m.strip()]
        if modalidades:
            where.append("o.modalidade IN :modalidades")
            params["modalidades"] = modalidades
            expanding.append("modalidades")
        statuses = [s.strip() for s in status.split(",") if s.strip()]
        if statuses:
            where.append("o.status IN :statuses")
            params["statuses"] = statuses
            expanding.append("statuses")
        if not incluir_inativas:
            where.append("o.status <> 'Inativa'")

        return " AND ".join(where), params, expanding

    @staticmethod
    def _stmt(sql_str: str, expanding: List[str]):
        stmt = text(sql_str)
        for key in expanding:
            stmt = stmt.bindparams(bindparam(key, expanding=True))
        return stmt

    @staticmethod
    def list_paginated(
        page: int = 1,
        limit: int = 10,
        search: str = "",
        uf: str = "",
        modalidade: str = "",
        status: str = "",
        incluir_inativas: bool = True,
    ) -> Tuple[List[Dict[str, Any]], int]:
        where_sql, params, expanding = OperadoraRepository._filtros(search, uf, modalidade, status, incluir_inativas)
        params.update({"limit": limit, "offset": (page - 1) * limit})

        with get_connection() as conn:
            total = conn.execute(
                OperadoraRepository._stmt(f"SELECT COUNT(*) FROM operadoras o WHERE {where_sql}", expanding),
                params,
            ).scalar_one()
            rows = (
                conn.execute(
                    OperadoraRepository._stmt(
                        f"SELECT o.*, dt.despesa_trimestre "
                        f"FROM operadoras o {_SUBQUERY_ULTIMO_TRIMESTRE}"
                        f"WHERE {where_sql} "
                        f"ORDER BY CASE o.status WHEN 'Inativa' THEN 1 ELSE 0 END, "
                        f"o.beneficiarios DESC, o.razao_social ASC "
                        f"LIMIT :limit OFFSET :offset",
                        expanding,
                    ),
                    params,
                )
                .mappings()
                .all()
            )
            return [dict(r) for r in rows], int(total)

    @staticmethod
    def list_all(**filtros) -> List[Dict[str, Any]]:
        """Lista sem paginação (exportação CSV)."""
        where_sql, params, expanding = OperadoraRepository._filtros(**filtros)
        with get_connection() as conn:
            rows = (
                conn.execute(
                    OperadoraRepository._stmt(
                        f"SELECT o.*, dt.despesa_trimestre FROM operadoras o {_SUBQUERY_ULTIMO_TRIMESTRE}"
                        f"WHERE {where_sql} ORDER BY o.beneficiarios DESC, o.razao_social ASC",
                        expanding,
                    ),
                    params,
                )
                .mappings()
                .all()
            )
            return [dict(r) for r in rows]

    @staticmethod
    def resumo(incluir_inativas: bool = True) -> Dict[str, Any]:
        return obter_ou_carregar(
            f"operadoras:resumo:{int(incluir_inativas)}",
            lambda: OperadoraRepository._carregar_resumo(incluir_inativas),
        )

    @staticmethod
    def _carregar_resumo(incluir_inativas: bool = True) -> Dict[str, Any]:
        with get_connection() as conn:
            linha = (
                conn.execute(
                    text(
                        "SELECT "
                        "SUM(CASE WHEN status = 'Ativa' THEN 1 ELSE 0 END) AS ativas, "
                        "SUM(CASE WHEN status = 'Em análise' THEN 1 ELSE 0 END) AS em_analise, "
                        "SUM(CASE WHEN status = 'Inativa' AND data_descredenciamento >= :desde THEN 1 ELSE 0 END) "
                        "  AS inativadas_12m, "
                        "SUM(CASE WHEN status <> 'Inativa' THEN beneficiarios ELSE 0 END) AS beneficiarios "
                        "FROM operadoras"
                    ),
                    {"desde": _data_ha_12_meses()},
                )
                .mappings()
                .first()
            )
            pares = conn.execute(
                text("SELECT DISTINCT uf, modalidade, status FROM operadoras")
            ).all()
        modalidades = sorted({
            r[1] for r in pares
            if r[1] is not None and (incluir_inativas or r[2] != "Inativa")
        })
        ufs = sorted({r[0] for r in pares if r[0] and r[2] != "Inativa"})
        return {
            "ativas": int(linha["ativas"] or 0),
            "em_analise": int(linha["em_analise"] or 0),
            "inativadas_12m": int(linha["inativadas_12m"] or 0),
            "beneficiarios": int(linha["beneficiarios"] or 0),
            "modalidades": modalidades,
            "ufs": ufs,
        }

    @staticmethod
    def find_by_identifier(identifier: str) -> Optional[Dict[str, Any]]:
        """Busca operadora por registro_ans ou CNPJ."""
        with get_connection() as conn:
            row = (
                conn.execute(
                    text(
                        f"SELECT o.*, dt.despesa_trimestre, "
                        f"(SELECT COALESCE(SUM(d.valor_despesa), 0) FROM despesas d "
                        f" WHERE d.reg_ans = o.registro_ans) AS total_despesas "
                        f"FROM operadoras o {_SUBQUERY_ULTIMO_TRIMESTRE}"
                        f"WHERE o.registro_ans = :ident OR o.cnpj = :ident LIMIT 1"
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
                conn.execute(text("SELECT * FROM operadoras WHERE cnpj = :cnpj LIMIT 1"), {"cnpj": cnpj})
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
                    "telefone, email, representante, cargo_representante, status, beneficiarios"
                    ") VALUES ("
                    ":registro_ans, :cnpj, :razao_social, :nome_fantasia, :modalidade, "
                    ":logradouro, :numero, :complemento, :bairro, :cidade, :uf, :cep, "
                    ":telefone, :email, :representante, :cargo_representante, :status, :beneficiarios"
                    ")"
                ),
                {"status": "Em análise", "beneficiarios": 0, **data},
            )
        return OperadoraRepository.find_by_identifier(data["registro_ans"])  # type: ignore[return-value]

    @staticmethod
    def update(registro_ans: str, data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        fields = [
            "cnpj", "razao_social", "nome_fantasia", "modalidade", "logradouro", "numero",
            "complemento", "bairro", "cidade", "uf", "cep", "telefone", "email",
            "representante", "cargo_representante", "status", "beneficiarios", "data_descredenciamento",
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
            return int(
                conn.execute(
                    text("SELECT COUNT(*) FROM despesas WHERE reg_ans = :reg_ans"), {"reg_ans": registro_ans}
                ).scalar_one()
            )

    @staticmethod
    def delete(registro_ans: str, cascade_despesas: bool = False) -> bool:
        with get_connection() as conn:
            if cascade_despesas:
                conn.execute(text("DELETE FROM despesas WHERE reg_ans = :reg_ans"), {"reg_ans": registro_ans})
            res = conn.execute(
                text("DELETE FROM operadoras WHERE registro_ans = :registro_ans"), {"registro_ans": registro_ans}
            )
            return res.rowcount > 0


def _data_ha_12_meses():
    from datetime import date

    hoje = date.today()
    try:
        return hoje.replace(year=hoje.year - 1)
    except ValueError:  # 29/02
        return hoje.replace(year=hoje.year - 1, day=28)
