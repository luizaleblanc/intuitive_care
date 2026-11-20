from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

from sqlalchemy import bindparam, text

from backend.database.connection import get_connection

Periodo = Tuple[int, int]
PeriodoInput = Union[Periodo, Sequence[Periodo]]


def _norm_periodos(entrada: PeriodoInput) -> List[Periodo]:
    if not entrada:
        return []
    if len(entrada) == 2 and isinstance(entrada[0], int) and isinstance(entrada[1], int):
        return [(int(entrada[0]), int(entrada[1]))]
    return [(int(p[0]), int(p[1])) for p in entrada]  # type: ignore[index]


def _norm_lista(valor: Union[str, Sequence[str], None], upper: bool = False) -> List[str]:
    if not valor:
        return []
    brutos = [v.strip() for v in valor.split(",")] if isinstance(valor, str) else [str(v).strip() for v in valor]
    itens = [v.upper() if upper else v for v in brutos if v]
    return list(dict.fromkeys(itens))


def _filtro_periodos(periodos: List[Periodo], alias: str = "d") -> Tuple[str, Dict[str, Any]]:
    if not periodos:
        return "1=0", {}
    prefixo = f"{alias}." if alias else ""
    partes, params = [], {}
    for i, (ano, tri) in enumerate(periodos):
        partes.append(f"({prefixo}ano = :pa{i} AND {prefixo}trimestre = :pt{i})")
        params[f"pa{i}"] = ano
        params[f"pt{i}"] = tri
    return "(" + " OR ".join(partes) + ")", params


def _filtro_operadora(
    uf: Union[str, Sequence[str]] = "",
    modalidade: Union[str, Sequence[str]] = "",
) -> Tuple[str, Dict[str, Any], List[str]]:
    where, params, expanding = [], {}, []
    ufs = _norm_lista(uf, upper=True)
    mods = _norm_lista(modalidade)
    if ufs:
        where.append("o.uf IN :ufs")
        params["ufs"] = ufs
        expanding.append("ufs")
    if mods:
        where.append("o.modalidade IN :mods")
        params["mods"] = mods
        expanding.append("mods")
    return (" AND " + " AND ".join(where)) if where else "", params, expanding


def _bind_expanding(sql_text: str, expanding: Sequence[str]):
    stmt = text(sql_text)
    for nome in expanding:
        stmt = stmt.bindparams(bindparam(nome, expanding=True))
    return stmt


class AnaliticoRepository:
    """Consultas agregadas sobre as demonstrações contábeis carregadas pelo ETL."""

    @staticmethod
    def periodos() -> List[Periodo]:
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
        periodos = _norm_periodos(periodo)
        if not periodos:
            return {"eventos": 0.0, "eventos_mh": 0.0, "contraprestacoes": 0.0,
                    "comercializacao": 0.0, "administrativas": 0.0, "operadoras": 0.0}
        cond_p, params_p = _filtro_periodos(periodos, "d")
        filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
        params = {**params_p, **params_f}
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
        periodos = _norm_periodos(periodo)
        if not periodos:
            return None
        cond_p, params_p = _filtro_periodos(periodos, "d")
        filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
        params = {**params_p, **params_f}
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
        periodos = _norm_periodos(periodo)
        if not periodos:
            return 0
        cond_p, params_p = _filtro_periodos(periodos, "b")
        filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
        params = {**params_p, **params_f}
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
        assert campo in ("eventos", "eventos_mh")
        filtro, params, expanding = _filtro_operadora(uf, modalidade)
        if selecionados and len(selecionados) > 1:
            cond_p, params_p = _filtro_periodos(_norm_periodos(selecionados), "d")
            stmt = _bind_expanding(
                f"SELECT d.ano, d.trimestre, SUM(d.{campo}) AS total "
                "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
                f"WHERE {cond_p}{filtro} GROUP BY d.ano, d.trimestre "
                "ORDER BY d.ano ASC, d.trimestre ASC",
                expanding,
            )
            with get_connection() as conn:
                rows = conn.execute(stmt, {**params, **params_p}).all()
            return [{"ano": int(r[0]), "trimestre": int(r[1]), "valor": float(r[2] or 0)} for r in rows]

        cond = ""
        if ate:
            cond = " AND (d.ano * 10 + d.trimestre) <= :ate"
            params["ate"] = ate[0] * 10 + ate[1]
        stmt = _bind_expanding(
            f"SELECT d.ano, d.trimestre, SUM(d.{campo}) AS total "
            "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE 1=1{cond}{filtro} GROUP BY d.ano, d.trimestre "
            "ORDER BY d.ano DESC, d.trimestre DESC LIMIT :lim",
            expanding,
        )
        with get_connection() as conn:
            rows = conn.execute(stmt, {**params, "lim": limite}).all()
        return [{"ano": int(r[0]), "trimestre": int(r[1]), "valor": float(r[2] or 0)} for r in reversed(rows)]

    @staticmethod
    def por_modalidade(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
    ) -> List[Dict[str, Any]]:
        periodos = _norm_periodos(periodo)
        if not periodos:
            return []
        cond_p, params_p = _filtro_periodos(periodos, "d")
        filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
        stmt = _bind_expanding(
            "SELECT COALESCE(o.modalidade, 'Não informada') AS modalidade, SUM(d.eventos) AS total "
            "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
            f"WHERE {cond_p} AND d.eventos > 0{filtro} "
            "GROUP BY o.modalidade ORDER BY total DESC",
            expanding,
        )
        with get_connection() as conn:
            rows = conn.execute(stmt, {**params_p, **params_f}).all()
        return [{"modalidade": r[0], "valor": float(r[1] or 0)} for r in rows]

    @staticmethod
    def ranking(
        periodo: PeriodoInput,
        uf: Union[str, Sequence[str]] = "",
        modalidade: Union[str, Sequence[str]] = "",
        limite: int = 5,
    ):
        periodos = _norm_periodos(periodo)
        if not periodos:
            return []
        cond_p, params_p = _filtro_periodos(periodos, "d")
        filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
        params = {**params_p, **params_f, "lim": limite}
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
            rows = conn.execute(stmt, params).mappings().all()
        return [{**dict(r), "valor": float(r["valor"] or 0)} for r in rows]

    @staticmethod
    def operadoras_ativas() -> int:
        with get_connection() as conn:
            return int(conn.execute(text("SELECT COUNT(*) FROM operadoras WHERE status = 'Ativa'")).scalar() or 0)

    # ------------------------------------------------------------------ contas
    @staticmethod
    def contas(periodo: PeriodoInput, prefixos: List[str], max_nivel: int = 2) -> Dict[str, Dict[str, Any]]:
        periodos = _norm_periodos(periodo)
        if not periodos or not prefixos:
            return {}
        cond_p, params_p = _filtro_periodos(periodos, "")
        conds = " OR ".join(f"codigo LIKE :p{i}" for i in range(len(prefixos)))
        params: Dict[str, Any] = {**params_p, **{f"p{i}": f"{p}%" for i, p in enumerate(prefixos)}, "nivel": max_nivel}
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
        periodos = _norm_periodos(periodo)
        if not periodos:
            return {}
        cond_p, params_p = _filtro_periodos(periodos, "")
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    f"SELECT codigo, SUM(valor) FROM contas_setor WHERE {cond_p} "
                    "AND codigo IN ('41111','41121','41131','41141','41151','41161','41171','41181','41191') "
                    "GROUP BY codigo"
                ),
                params_p,
            ).all()
        return {r[0]: float(r[1] or 0) for r in rows}

    # ------------------------------------------------------------------ lotes
    @staticmethod
    def lote(periodo: Periodo) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            r = (
                conn.execute(
                    text("SELECT * FROM lotes_etl WHERE ano = :ano AND trimestre = :tri"),
                    {"ano": periodo[0], "tri": periodo[1]},
                )
                .mappings()
                .first()
            )
            return dict(r) if r else None

    @staticmethod
    def lotes(periodos: Sequence[Periodo]) -> List[Dict[str, Any]]:
        lista = _norm_periodos(periodos)
        if not lista:
            return []
        cond_p, params_p = _filtro_periodos(lista, "")
        with get_connection() as conn:
            rows = conn.execute(text(f"SELECT * FROM lotes_etl WHERE {cond_p}"), params_p).mappings().all()
            return [dict(r) for r in rows]

    @staticmethod
    def auditar_lote(periodo: Periodo, usuario: str) -> int:
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
