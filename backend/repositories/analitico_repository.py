from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

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

_TOTAIS_ZEROS = {
    "eventos": 0.0,
    "eventos_mh": 0.0,
    "contraprestacoes": 0.0,
    "comercializacao": 0.0,
    "administrativas": 0.0,
    "operadoras": 0.0,
}


def _condicoes_duplas(
    atual: PeriodoInput,
    anterior: PeriodoInput,
    uf: Union[str, Sequence[str]],
    modalidade: Union[str, Sequence[str]],
    alias: str,
) -> Optional[Tuple[str, str, str, Dict[str, Any], List[str]]]:
    p_atual = _norm_periodos(atual)
    if not p_atual:
        return None
    p_ant = _norm_periodos(anterior)
    cond_a, params_a = _filtro_periodos(p_atual, alias, prefixo_param="pa")
    if p_ant:
        cond_b, params_b = _filtro_periodos(p_ant, alias, prefixo_param="pb")
        cond_ab = f"({cond_a} OR {cond_b})"
    else:
        cond_b, params_b = "1=0", {}
        cond_ab = cond_a
    filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
    return cond_a, cond_b, f"{cond_ab}{filtro}", {**params_a, **params_b, **params_f}, expanding


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
        atual, _ = AnaliticoRepository.totais_comparados(periodo, (), uf, modalidade)
        return atual

    @staticmethod
    def totais_comparados(
        atual: PeriodoInput,
        anterior: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Tuple[Dict[str, float], Dict[str, float]]:
        """Calcula somatórios dos períodos atual e anterior em uma única query SQL."""
        comp = _condicoes_duplas(atual, anterior, uf, modalidade, "d")
        if not comp:
            return dict(_TOTAIS_ZEROS), dict(_TOTAIS_ZEROS)
        cond_a, cond_b, where_sql, params, expanding = comp
        stmt = _bind_expanding(
            "SELECT "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN d.eventos ELSE 0 END), 0) AS a_eventos, "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN d.eventos_mh ELSE 0 END), 0) AS a_eventos_mh, "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN d.contraprestacoes ELSE 0 END), 0) AS a_contraprestacoes, "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN d.comercializacao ELSE 0 END), 0) AS a_comercializacao, "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN d.administrativas ELSE 0 END), 0) AS a_administrativas, "
            f"COUNT(DISTINCT CASE WHEN {cond_a} THEN d.reg_ans END) AS a_operadoras, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN d.eventos ELSE 0 END), 0) AS b_eventos, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN d.eventos_mh ELSE 0 END), 0) AS b_eventos_mh, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN d.contraprestacoes ELSE 0 END), 0) AS b_contraprestacoes, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN d.comercializacao ELSE 0 END), 0) AS b_comercializacao, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN d.administrativas ELSE 0 END), 0) AS b_administrativas, "
            f"COUNT(DISTINCT CASE WHEN {cond_b} THEN d.reg_ans END) AS b_operadoras "
            "FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {where_sql}",
            expanding,
        )
        with get_connection() as conn:
            r = conn.execute(stmt, params).mappings().first()
        keys = tuple(_TOTAIS_ZEROS.keys())
        return (
            {k: float(r[f"a_{k}"] or 0) for k in keys},
            {k: float(r[f"b_{k}"] or 0) for k in keys},
        )

    @staticmethod
    def sinistralidade_media(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Optional[float]:
        """Média simples da sinistralidade por operadora (eventos / contraprestações)."""
        atual, _ = AnaliticoRepository.sinistralidades_comparadas(periodo, (), uf, modalidade)
        return atual

    @staticmethod
    def sinistralidades_comparadas(
        atual: PeriodoInput,
        anterior: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Tuple[Optional[float], Optional[float]]:
        """Calcula sinistralidade média dos períodos atual e anterior em 1 query."""
        comp = _condicoes_duplas(atual, anterior, uf, modalidade, "d")
        if not comp:
            return None, None
        cond_a, cond_b, where_sql, params, expanding = comp
        stmt = _bind_expanding(
            "SELECT "
            f"AVG(CASE WHEN {cond_a} THEN d.eventos * 1.0 / d.contraprestacoes END) AS atual, "
            f"AVG(CASE WHEN {cond_b} THEN d.eventos * 1.0 / d.contraprestacoes END) AS anterior "
            "FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE d.contraprestacoes > 0 AND d.eventos > 0 "
            f"AND d.eventos * 1.0 / d.contraprestacoes BETWEEN 0 AND 3 AND {where_sql}",
            expanding,
        )
        with get_connection() as conn:
            r = conn.execute(stmt, params).mappings().first()
        return (
            float(r["atual"]) if r["atual"] is not None else None,
            float(r["anterior"]) if r["anterior"] is not None else None,
        )

    @staticmethod
    def beneficiarios(
        periodo: Periodo,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> int:
        """Beneficiários médico-hospitalares no mês de fechamento do trimestre."""
        atual, _ = AnaliticoRepository.beneficiarios_comparados(periodo, None, uf, modalidade)
        return atual

    @staticmethod
    def beneficiarios_comparados(
        periodo_atual: Periodo,
        periodo_anterior: Optional[Periodo],
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Tuple[int, int]:
        """Soma beneficiários médico-hospitalares dos períodos atual e anterior em 1 query."""
        anteriores = [periodo_anterior] if periodo_anterior else []
        comp = _condicoes_duplas([periodo_atual], anteriores, uf, modalidade, "b")
        if not comp:
            return 0, 0
        cond_a, cond_b, where_sql, params, expanding = comp
        stmt = _bind_expanding(
            "SELECT "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN b.medico_hospitalar ELSE 0 END), 0) AS atual, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN b.medico_hospitalar ELSE 0 END), 0) AS anterior "
            "FROM beneficiarios_trimestre b "
            "JOIN operadoras o ON o.registro_ans = b.reg_ans "
            f"WHERE {where_sql}",
            expanding,
        )
        with get_connection() as conn:
            r = conn.execute(stmt, params).mappings().first()
        return int(r["atual"] or 0), int(r["anterior"] or 0)

    @staticmethod
    def beneficiarios_com_despesa(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> int:
        """Beneficiários médico-hospitalares das operadoras com despesa no período (base do ticket médio)."""
        atual, _ = AnaliticoRepository.beneficiarios_despesa_comparados(periodo, (), uf, modalidade)
        return atual

    @staticmethod
    def beneficiarios_despesa_comparados(
        atual: PeriodoInput,
        anterior: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> Tuple[int, int]:
        """Calcula base de beneficiários com despesa atual e anterior em 1 query."""
        comp = _condicoes_duplas(atual, anterior, uf, modalidade, "b")
        if not comp:
            return 0, 0
        cond_a, cond_b, where_sql, params, expanding = comp
        stmt = _bind_expanding(
            "SELECT "
            f"COALESCE(SUM(CASE WHEN {cond_a} THEN b.medico_hospitalar ELSE 0 END), 0) AS atual, "
            f"COALESCE(SUM(CASE WHEN {cond_b} THEN b.medico_hospitalar ELSE 0 END), 0) AS anterior "
            "FROM beneficiarios_trimestre b "
            "JOIN operadoras o ON o.registro_ans = b.reg_ans "
            "JOIN demonstracoes_operadora d ON d.reg_ans = b.reg_ans "
            "  AND d.ano = b.ano AND d.trimestre = b.trimestre "
            f"WHERE d.eventos_mh > 0 AND {where_sql}",
            expanding,
        )
        with get_connection() as conn:
            r = conn.execute(stmt, params).mappings().first()
        return int(r["atual"] or 0), int(r["anterior"] or 0)

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
    def contas_comparadas(
        atual: PeriodoInput,
        anterior: PeriodoInput,
        prefixos: List[str],
        incluir_kpis: bool = True,
    ):
        """Delega consulta consolidada de contas e KPIs para `ContasRepository`."""
        return ContasRepository.contas_comparadas(atual, anterior, prefixos, incluir_kpis=incluir_kpis)

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
