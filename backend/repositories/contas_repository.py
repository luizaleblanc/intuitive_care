from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence, Tuple

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
    def contas_comparadas(
        atual: PeriodoInput,
        anterior: PeriodoInput,
        prefixos: List[str],
        incluir_kpis: bool = True,
    ) -> Tuple[Dict[str, Dict[str, Any]], Dict[str, Dict[str, Any]], Dict[str, float], Dict[str, float]]:
        """Busca contas atuais/anteriores e KPIs de grupo em uma única consulta SQL."""
        p_atual = _norm_periodos(atual)
        p_ant = _norm_periodos(anterior)
        if not p_atual or not prefixos:
            return {}, {}, {}, {}

        cond_a, params_a = _filtro_periodos(p_atual, "", prefixo_param="a")
        if p_ant:
            cond_b, params_b = _filtro_periodos(p_ant, "", prefixo_param="b")
            cond_periodo = f"({cond_a} OR {cond_b})"
        else:
            cond_b, params_b = "1=0", {}
            cond_periodo = cond_a

        conds = " OR ".join(f"codigo LIKE :p{i}" for i in range(len(prefixos)))
        cond_filtro = f"(nivel <= 2 AND ({conds}))"
        if incluir_kpis:
            cond_filtro = f"({cond_filtro} OR (nivel = 0 AND codigo IN ('41', '43', '46')))"

        params: Dict[str, Any] = {
            **params_a,
            **params_b,
            **{f"p{i}": f"{p}%" for i, p in enumerate(prefixos)},
        }
        with get_connection() as conn:
            rows = (
                conn.execute(
                    text(
                        "SELECT codigo, MAX(descricao) AS descricao, MIN(nivel) AS nivel, "
                        f"SUM(CASE WHEN {cond_a} THEN valor ELSE 0 END) AS valor_atual, "
                        f"COUNT(CASE WHEN {cond_a} THEN 1 END) AS tem_atual, "
                        f"SUM(CASE WHEN {cond_b} THEN valor ELSE 0 END) AS valor_ant, "
                        f"COUNT(CASE WHEN {cond_b} THEN 1 END) AS tem_ant "
                        "FROM contas_setor "
                        f"WHERE {cond_periodo} AND {cond_filtro} "
                        "GROUP BY codigo ORDER BY codigo"
                    ),
                    params,
                )
                .mappings()
                .all()
            )

        atuais: Dict[str, Dict[str, Any]] = {}
        anteriores_map: Dict[str, Dict[str, Any]] = {}
        kpi_atual: Dict[str, float] = {}
        kpi_ant: Dict[str, float] = {}
        for r in rows:
            codigo = r["codigo"]
            nivel = int(r["nivel"])
            tem_a = int(r["tem_atual"] or 0) > 0
            tem_b = int(r["tem_ant"] or 0) > 0
            val_a = float(r["valor_atual"] or 0)
            val_b = float(r["valor_ant"] or 0)

            if incluir_kpis and nivel == 0 and codigo in ("41", "43", "46"):
                if tem_a:
                    kpi_atual[codigo] = val_a
                if tem_b:
                    kpi_ant[codigo] = val_b

            if any(codigo.startswith(p) for p in prefixos):
                if tem_a:
                    atuais[codigo] = {"codigo": codigo, "descricao": r["descricao"], "nivel": nivel, "valor": val_a}
                if tem_b:
                    anteriores_map[codigo] = {"codigo": codigo, "descricao": r["descricao"], "nivel": nivel, "valor": val_b}

        return atuais, anteriores_map, kpi_atual, kpi_ant

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
