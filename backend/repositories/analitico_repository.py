from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import text

from backend.database.connection import get_connection

Periodo = Tuple[int, int]


def _filtro_operadora(uf: str, modalidade: str) -> Tuple[str, Dict[str, Any]]:
    where, params = [], {}
    if uf:
        where.append("o.uf = :uf")
        params["uf"] = uf
    if modalidade:
        where.append("o.modalidade = :modalidade")
        params["modalidade"] = modalidade
    return (" AND " + " AND ".join(where)) if where else "", params


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
    def totais_periodo(periodo: Periodo, uf: str = "", modalidade: str = "") -> Dict[str, float]:
        filtro, params = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1]})
        with get_connection() as conn:
            r = (
                conn.execute(
                    text(
                        "SELECT COALESCE(SUM(d.eventos), 0) AS eventos, "
                        "COALESCE(SUM(d.eventos_mh), 0) AS eventos_mh, "
                        "COALESCE(SUM(d.contraprestacoes), 0) AS contraprestacoes, "
                        "COALESCE(SUM(d.comercializacao), 0) AS comercializacao, "
                        "COALESCE(SUM(d.administrativas), 0) AS administrativas, "
                        "COUNT(*) AS operadoras "
                        "FROM demonstracoes_operadora d "
                        "JOIN operadoras o ON o.registro_ans = d.reg_ans "
                        f"WHERE d.ano = :ano AND d.trimestre = :tri{filtro}"
                    ),
                    params,
                )
                .mappings()
                .first()
            )
            return {k: float(r[k] or 0) for k in r.keys()}

    @staticmethod
    def sinistralidade_media(periodo: Periodo, uf: str = "", modalidade: str = "") -> Optional[float]:
        """Média simples da sinistralidade por operadora (eventos / contraprestações)."""
        filtro, params = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1]})
        with get_connection() as conn:
            valor = conn.execute(
                text(
                    "SELECT AVG(d.eventos * 1.0 / d.contraprestacoes) FROM demonstracoes_operadora d "
                    "JOIN operadoras o ON o.registro_ans = d.reg_ans "
                    f"WHERE d.ano = :ano AND d.trimestre = :tri AND d.contraprestacoes > 0 "
                    f"AND d.eventos > 0 AND d.eventos * 1.0 / d.contraprestacoes BETWEEN 0 AND 3{filtro}"
                ),
                params,
            ).scalar()
            return float(valor) if valor is not None else None

    @staticmethod
    def beneficiarios(periodo: Periodo, uf: str = "", modalidade: str = "") -> int:
        """Beneficiários médico-hospitalares no mês de fechamento do trimestre."""
        filtro, params = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1]})
        with get_connection() as conn:
            valor = conn.execute(
                text(
                    "SELECT COALESCE(SUM(b.medico_hospitalar), 0) FROM beneficiarios_trimestre b "
                    "JOIN operadoras o ON o.registro_ans = b.reg_ans "
                    f"WHERE b.ano = :ano AND b.trimestre = :tri{filtro}"
                ),
                params,
            ).scalar()
            return int(valor or 0)

    @staticmethod
    def beneficiarios_com_despesa(periodo: Periodo, uf: str = "", modalidade: str = "") -> int:
        """Beneficiários médico-hospitalares das operadoras com despesa no período (base do ticket médio)."""
        filtro, params = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1]})
        with get_connection() as conn:
            valor = conn.execute(
                text(
                    "SELECT COALESCE(SUM(b.medico_hospitalar), 0) FROM beneficiarios_trimestre b "
                    "JOIN operadoras o ON o.registro_ans = b.reg_ans "
                    "JOIN demonstracoes_operadora d ON d.reg_ans = b.reg_ans "
                    "  AND d.ano = b.ano AND d.trimestre = b.trimestre "
                    f"WHERE b.ano = :ano AND b.trimestre = :tri AND d.eventos_mh > 0{filtro}"
                ),
                params,
            ).scalar()
            return int(valor or 0)

    @staticmethod
    def serie(campo: str, ate: Optional[Periodo] = None, uf: str = "", modalidade: str = "", limite: int = 8):
        assert campo in ("eventos", "eventos_mh")
        filtro, params = _filtro_operadora(uf, modalidade)
        cond = ""
        if ate:
            cond = " AND (d.ano * 10 + d.trimestre) <= :ate"
            params["ate"] = ate[0] * 10 + ate[1]
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    f"SELECT d.ano, d.trimestre, SUM(d.{campo}) AS total "
                    "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
                    f"WHERE 1=1{cond}{filtro} GROUP BY d.ano, d.trimestre "
                    "ORDER BY d.ano DESC, d.trimestre DESC LIMIT :lim"
                ),
                {**params, "lim": limite},
            ).all()
        return [{"ano": int(r[0]), "trimestre": int(r[1]), "valor": float(r[2] or 0)} for r in reversed(rows)]

    @staticmethod
    def por_modalidade(periodo: Periodo) -> List[Dict[str, Any]]:
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    "SELECT COALESCE(o.modalidade, 'Não informada') AS modalidade, SUM(d.eventos) AS total "
                    "FROM demonstracoes_operadora d JOIN operadoras o ON o.registro_ans = d.reg_ans "
                    "WHERE d.ano = :ano AND d.trimestre = :tri AND d.eventos > 0 "
                    "GROUP BY o.modalidade ORDER BY total DESC"
                ),
                {"ano": periodo[0], "tri": periodo[1]},
            ).all()
        return [{"modalidade": r[0], "valor": float(r[1] or 0)} for r in rows]

    @staticmethod
    def ranking(periodo: Periodo, uf: str = "", modalidade: str = "", limite: int = 5):
        filtro, params = _filtro_operadora(uf, modalidade)
        params.update({"ano": periodo[0], "tri": periodo[1], "lim": limite})
        with get_connection() as conn:
            rows = (
                conn.execute(
                    text(
                        "SELECT o.registro_ans, o.razao_social, o.nome_fantasia, o.uf, o.modalidade, "
                        "d.eventos_mh AS valor FROM demonstracoes_operadora d "
                        "JOIN operadoras o ON o.registro_ans = d.reg_ans "
                        f"WHERE d.ano = :ano AND d.trimestre = :tri{filtro} "
                        "ORDER BY d.eventos_mh DESC LIMIT :lim"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
        return [{**dict(r), "valor": float(r["valor"] or 0)} for r in rows]

    @staticmethod
    def operadoras_ativas() -> int:
        with get_connection() as conn:
            return int(conn.execute(text("SELECT COUNT(*) FROM operadoras WHERE status = 'Ativa'")).scalar() or 0)

    # ------------------------------------------------------------------ contas
    @staticmethod
    def contas(periodo: Periodo, prefixos: List[str], max_nivel: int = 2) -> Dict[str, Dict[str, Any]]:
        conds = " OR ".join(f"codigo LIKE :p{i}" for i in range(len(prefixos)))
        params: Dict[str, Any] = {f"p{i}": f"{p}%" for i, p in enumerate(prefixos)}
        params.update({"ano": periodo[0], "tri": periodo[1], "nivel": max_nivel})
        with get_connection() as conn:
            rows = (
                conn.execute(
                    text(
                        "SELECT codigo, descricao, nivel, valor FROM contas_setor "
                        f"WHERE ano = :ano AND trimestre = :tri AND nivel <= :nivel AND ({conds}) "
                        "ORDER BY codigo"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
        return {r["codigo"]: {**dict(r), "valor": float(r["valor"] or 0)} for r in rows}

    @staticmethod
    def composicao_mh(periodo: Periodo) -> Dict[str, float]:
        with get_connection() as conn:
            rows = conn.execute(
                text(
                    "SELECT codigo, valor FROM contas_setor WHERE ano = :ano AND trimestre = :tri "
                    "AND codigo IN ('41111','41121','41131','41141','41151','41161','41171','41181','41191')"
                ),
                {"ano": periodo[0], "tri": periodo[1]},
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
