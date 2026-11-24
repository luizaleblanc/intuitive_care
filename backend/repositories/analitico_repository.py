from typing import Any, Dict, List, Optional, Sequence, Union

from sqlalchemy import text

from backend.database.connection import get_connection
from backend.repositories.analitico_sql_helpers import (
    Periodo,
    PeriodoInput,
    _bind_expanding,
    _filtro_operadora,
    _filtro_periodos,
    _norm_periodos,
    _preparar_filtros,
)
from backend.repositories.contas_repository import ContasRepository


class AnaliticoRepository:
    """Consultas agregadas sobre as demonstrações contábeis carregadas pelo ETL."""

    @staticmethod
    def periodos() -> List[Periodo]:
        """Lista os pares `(ano, trimestre)` disponíveis ordenados do mais recente ao mais antigo."""
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    "SELECT DISTINCT ano, trimestre FROM demonstracoes_operadora "
                    "ORDER BY ano DESC, trimestre DESC"
                )
            ).all()
            return [(int(r[0]), int(r[1])) for r in rows]

    @staticmethod
    def totais_periodo(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Dict[str, float]:
        """Soma despesas, receitas e operadoras distintas no recorte informado."""
        filtros = _preparar_filtros(periodo, uf, modalidade, "d")
        if not filtros:
            return {
                "eventos": 0.0,
                "eventos_mh": 0.0,
                "contraprestacoes": 0.0,
                "comercializacao": 0.0,
                "administrativas": 0.0,
                "operadoras": 0.0,
            }
        cond_p, filtro, params, expanding = filtros
        stmt = _bind_expanding(
            "SELECT COALESCE(SUM(d.eventos), 0) AS eventos, "
            "COALESCE(SUM(d.eventos_mh), 0) AS eventos_mh, "
            "COALESCE(SUM(d.contraprestacoes), 0) AS contraprestacoes, "
            "COALESCE(SUM(d.comercializacao), 0) AS comercializacao, "
            "COALESCE(SUM(d.administrativas), 0) AS administrativas, "
            "COUNT(DISTINCT d.reg_ans) AS operadoras "
            "FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_p}{filtro}",
            expanding,
        )
        with get_connection() as conn:
            r = conn.execute(stmt, params).mappings().first()
            return {k: float(r[k] or 0) for k in r.keys()}

    @staticmethod
    def sinistralidade_media(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Optional[float]:
        """Média simples da sinistralidade por operadora (eventos / contraprestações)."""
        filtros = _preparar_filtros(periodo, uf, modalidade, "d")
        if not filtros:
            return None
        cond_p, filtro, params, expanding = filtros
        stmt = _bind_expanding(
            "SELECT AVG(d.eventos * 1.0 / d.contraprestacoes) FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_p} AND d.contraprestacoes > 0 "
            f"AND d.eventos > 0 AND d.eventos * 1.0 / d.contraprestacoes BETWEEN 0 AND 3{filtro}",
            expanding,
        )
        with get_connection() as conn:
            valor = conn.execute(stmt, params).scalar()
            return float(valor) if valor is not None else None

    @staticmethod
    def beneficiarios(
        periodo: Periodo,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> int:
        """Beneficiários médico-hospitalares no mês de fechamento do trimestre."""
        filtro, params, expanding = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1]})
        stmt = _bind_expanding(
            "SELECT COALESCE(SUM(b.medico_hospitalar), 0) FROM beneficiarios_trimestre b "
            "JOIN operadoras o ON o.registro_ans = b.reg_ans "
            f"WHERE b.ano = :ano AND b.trimestre = :tri{filtro}",
            expanding,
        )
        with get_connection() as conn:
            valor = conn.execute(stmt, params).scalar()
            return int(valor or 0)

    @staticmethod
    def beneficiarios_com_despesa(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> int:
        """Beneficiários médico-hospitalares das operadoras com despesa no período (base do ticket médio)."""
        filtros = _preparar_filtros(periodo, uf, modalidade, "b")
        if not filtros:
            return 0
        cond_p, filtro, params, expanding = filtros
        stmt = _bind_expanding(
            "SELECT COALESCE(SUM(b.medico_hospitalar), 0) FROM beneficiarios_trimestre b "
            "JOIN operadoras o ON o.registro_ans = b.reg_ans "
            "JOIN demonstracoes_operadora d ON d.reg_ans = b.reg_ans "
            "  AND d.ano = b.ano AND d.trimestre = b.trimestre "
            f"WHERE {cond_p} AND d.eventos_mh > 0{filtro}",
            expanding,
        )
        with get_connection() as conn:
            valor = conn.execute(stmt, params).scalar()
            return int(valor or 0)

    @staticmethod
    def serie(
        campo: str,
        ate: Optional[Periodo] = None,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
        limite: int = 8,
        selecionados: Optional[Sequence[Periodo]] = None,
    ):
        """Retorna série temporal trimestral de `eventos` ou `eventos_mh`."""
        assert campo in ("eventos", "eventos_mh")
        filtro, params, expanding = _filtro_operadora(uf, modalidade)
        if selecionados and len(selecionados) > 1:
            cond_periodo, params_p = _filtro_periodos(_norm_periodos(selecionados), "d")
            params.update(params_p)
            order_limit, inverter = "ORDER BY d.ano ASC, d.trimestre ASC", False
        else:
            cond_periodo = "1=1"
            if ate:
                cond_periodo += " AND (d.ano * 10 + d.trimestre) <= :ate"
                params["ate"] = ate[0] * 10 + ate[1]
            params["lim"] = limite
            order_limit, inverter = "ORDER BY d.ano DESC, d.trimestre DESC LIMIT :lim", True

        stmt = _bind_expanding(
            f"SELECT d.ano, d.trimestre, SUM(d.{campo}) AS total "
            "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_periodo}{filtro} GROUP BY d.ano, d.trimestre {order_limit}",
            expanding,
        )
        with get_connection() as conn:
            rows = conn.execute(stmt, params).all()
        itens = reversed(rows) if inverter else rows
        return [{"ano": int(r[0]), "trimestre": int(r[1]), "valor": float(r[2] or 0)} for r in itens]

    @staticmethod
    def por_modalidade(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> List[Dict[str, Any]]:
        """Agrupa despesas assistenciais por modalidade de operadora."""
        filtros = _preparar_filtros(periodo, uf, modalidade, "d")
        if not filtros:
            return []
        cond_p, filtro, params, expanding = filtros
        stmt = _bind_expanding(
            "SELECT COALESCE(o.modalidade, 'Não informada') AS modalidade, SUM(d.eventos) AS total "
            "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_p} AND d.eventos > 0{filtro} "
            "GROUP BY o.modalidade ORDER BY total DESC",
            expanding,
        )
        with get_connection() as conn:
            rows = conn.execute(stmt, params).all()
        return [{"modalidade": r[0], "valor": float(r[1] or 0)} for r in rows]

    @staticmethod
    def ranking(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
        limite: int = 5,
    ):
        """Retorna as operadoras com maior despesa médico-hospitalar no período."""
        filtros = _preparar_filtros(periodo, uf, modalidade, "d")
        if not filtros:
            return []
        cond_p, filtro, params, expanding = filtros
        stmt = _bind_expanding(
            "SELECT o.registro_ans, o.razao_social, o.nome_fantasia, o.uf, o.modalidade, "
            "SUM(d.eventos_mh) AS valor FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_p}{filtro} "
            "GROUP BY o.registro_ans, o.razao_social, o.nome_fantasia, o.uf, o.modalidade "
            "ORDER BY valor DESC LIMIT :lim",
            expanding,
        )
        with get_connection() as conn:
            rows = conn.execute(stmt, {**params, "lim": limite}).mappings().all()
        return [{**dict(r), "valor": float(r["valor"] or 0)} for r in rows]

    @staticmethod
    def operadoras_ativas() -> int:
        """Conta o total de operadoras cadastradas com status `Ativa`."""
        with get_connection() as conn:
            return int(conn.execute(text("SELECT COUNT(*) FROM operadoras WHERE status = 'Ativa'")).scalar() or 0)

    # ------------------------------------------------------------------ contas e lotes
    @staticmethod
    def contas(periodo: PeriodoInput, prefixos: List[str], max_nivel: int = 2) -> Dict[str, Dict[str, Any]]:
        """Delega consulta de contas do setor para `ContasRepository`."""
        return ContasRepository.contas(periodo, prefixos, max_nivel=max_nivel)

    @staticmethod
    def composicao_mh(periodo: PeriodoInput) -> Dict[str, float]:
        """Delega consulta de composição médico-hospitalar para `ContasRepository`."""
        return ContasRepository.composicao_mh(periodo)

    @staticmethod
    def lote(periodo: Periodo) -> Optional[Dict[str, Any]]:
        """Delega consulta de lote ETL para `ContasRepository`."""
        return ContasRepository.lote(periodo)

    @staticmethod
    def lotes(periodos: Sequence[Periodo]) -> List[Dict[str, Any]]:
        """Delega consulta de múltiplos lotes ETL para `ContasRepository`."""
        return ContasRepository.lotes(periodos)

    @staticmethod
    def auditar_lote(periodo: Periodo, usuario: str) -> int:
        """Delega registro de auditoria de lote para `ContasRepository`."""
        return ContasRepository.auditar_lote(periodo, usuario)
