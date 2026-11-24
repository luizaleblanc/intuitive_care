from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence

from sqlalchemy import text

from backend.database.connection import get_connection
from backend.repositories.analitico_sql_helpers import (
    Periodo,
    PeriodoInput,
    _filtro_periodos,
    _norm_periodos,
)

_CODIGOS_MH = "('41111','41121','41131','41141','41151','41161','41171','41181','41191')"


class ContasRepository:
    """Consultas do plano de contas setorial, composição médico-hospitalar e lotes ETL."""

    @staticmethod
    def contas(periodo: PeriodoInput, prefixos: List[str], max_nivel: int = 2) -> Dict[str, Dict[str, Any]]:
        """Retorna contas contábeis do setor agrupadas por código para os prefixos informados."""
        periodos = _norm_periodos(periodo)
        if not periodos or not prefixos:
            return {}
        cond_p, params_p = _filtro_periodos(periodos, "")
        conds = " OR ".join(f"codigo LIKE :p{i}" for i in range(len(prefixos)))
        params: Dict[str, Any] = {
            **params_p,
            **{f"p{i}": f"{p}%" for i, p in enumerate(prefixos)},
            "nivel": max_nivel,
        }
        with get_connection() as conn:
            rows = (
                conn.execute(
                    text(
                        "SELECT codigo, MAX(descricao) AS descricao, MIN(nivel) AS nivel, SUM(valor) AS valor "
                        "FROM contas_setor "
                        f"WHERE {cond_p} AND nivel <= :nivel AND ({conds}) "
                        "GROUP BY codigo ORDER BY codigo"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
        return {r["codigo"]: {**dict(r), "valor": float(r["valor"] or 0)} for r in rows}

    @staticmethod
    def composicao_mh(periodo: PeriodoInput) -> Dict[str, float]:
        """Soma as despesas médico-hospitalares por forma de pagamento nos períodos informados."""
        periodos = _norm_periodos(periodo)
        if not periodos:
            return {}
        cond_p, params_p = _filtro_periodos(periodos, "")
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    f"SELECT codigo, SUM(valor) FROM contas_setor WHERE {cond_p} "
                    f"AND codigo IN {_CODIGOS_MH} GROUP BY codigo"
                ),
                params_p,
            ).all()
        return {r[0]: float(r[1] or 0) for r in rows}

    @staticmethod
    def lote(periodo: Periodo) -> Optional[Dict[str, Any]]:
        """Retorna os metadados do lote ETL de um único `(ano, trimestre)`."""
        encontrados = ContasRepository.lotes([periodo])
        return encontrados[0] if encontrados else None

    @staticmethod
    def lotes(periodos: Sequence[Periodo]) -> List[Dict[str, Any]]:
        """Retorna os metadados dos lotes ETL para os períodos solicitados."""
        lista = _norm_periodos(periodos)
        if not lista:
            return []
        cond_p, params_p = _filtro_periodos(lista, "")
        with get_connection() as conn:
            rows = conn.execute(text(f"SELECT * FROM lotes_etl WHERE {cond_p}"), params_p).mappings().all()
            return [dict(r) for r in rows]

    @staticmethod
    def auditar_lote(periodo: Periodo, usuario: str) -> int:
        """Marca o lote do período informado como auditado e retorna linhas afetadas."""
        with get_connection() as conn:
            res = conn.execute(
                text(
                    "UPDATE lotes_etl SET auditado = 1, auditado_por = :u, auditado_em = :agora "
                    "WHERE ano = :ano AND trimestre = :tri"
                ),
                {
                    "u": usuario,
                    "agora": datetime.now(timezone.utc).replace(tzinfo=None),
                    "ano": periodo[0],
                    "tri": periodo[1],
                },
            )
            return res.rowcount
