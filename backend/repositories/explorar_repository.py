from typing import Any, Dict, List, Sequence

from sqlalchemy import bindparam, text

from backend.database.connection import get_connection


class ExplorarRepository:
    """Consultas brutas da exploração analítica: uma linha por operadora e trimestre."""

    @staticmethod
    def anos_disponiveis() -> List[int]:
        with get_connection() as conn:
            return [int(r[0]) for r in conn.execute(text("SELECT DISTINCT ano FROM demonstracoes_operadora ORDER BY ano"))]

    @staticmethod
    def trimestres_por_ano() -> Dict[int, int]:
        with get_connection() as conn:
            linhas = conn.execute(
                text("SELECT ano, COUNT(DISTINCT trimestre) FROM demonstracoes_operadora GROUP BY ano")
            ).all()
        return {int(a): int(n) for a, n in linhas}

    @staticmethod
    def facetas() -> Dict[str, List[str]]:
        with get_connection() as conn:
            ufs = [r[0] for r in conn.execute(text(
                "SELECT DISTINCT o.uf FROM operadoras o JOIN demonstracoes_operadora d ON d.reg_ans = o.registro_ans "
                "WHERE o.uf IS NOT NULL AND o.uf <> '' ORDER BY o.uf"))]
            modalidades = [r[0] for r in conn.execute(text(
                "SELECT DISTINCT o.modalidade FROM operadoras o JOIN demonstracoes_operadora d "
                "ON d.reg_ans = o.registro_ans WHERE o.modalidade IS NOT NULL AND o.modalidade <> '' "
                "ORDER BY o.modalidade"))]
        return {"ufs": ufs, "modalidades": modalidades}

    @staticmethod
    def linhas(
        anos: Sequence[int],
        ufs: Sequence[str],
        modalidades: Sequence[str],
        status: Any,
        consolidacao: str,
        trimestres: Sequence[int] = (),
    ) -> List[Dict[str, Any]]:
        condicoes = ["d.ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        if trimestres:
            condicoes.append("d.trimestre IN :tris")
            params["tris"] = list(trimestres)
        if ufs:
            condicoes.append("o.uf IN :ufs")
            params["ufs"] = list(ufs)
        if modalidades:
            condicoes.append("o.modalidade IN :mods")
            params["mods"] = list(modalidades)
        statuses = [status] if isinstance(status, str) and status else ([s for s in status if s] if status and not isinstance(status, str) else [])
        if statuses:
            condicoes.append("o.status IN :statuses")
            params["statuses"] = list(statuses)
        if consolidacao == "consolidado":
            condicoes.append("COALESCE(l.auditado, 0) = 1")
        elif consolidacao == "pendente":
            condicoes.append("COALESCE(l.auditado, 0) = 0")

        sql = text(
            "SELECT d.reg_ans, d.ano, d.trimestre, d.eventos, d.contraprestacoes, "
            "o.razao_social, o.nome_fantasia, o.uf, o.modalidade, o.status, o.beneficiarios, "
            "COALESCE(b.medico_hospitalar, 0) AS benef "
            "FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            "LEFT JOIN lotes_etl l ON l.ano = d.ano AND l.trimestre = d.trimestre "
            "LEFT JOIN beneficiarios_trimestre b ON b.reg_ans = d.reg_ans AND b.ano = d.ano AND b.trimestre = d.trimestre "
            f"WHERE {' AND '.join(condicoes)}"
        )
        sql = sql.bindparams(bindparam("anos", expanding=True))
        if trimestres:
            sql = sql.bindparams(bindparam("tris", expanding=True))
        if ufs:
            sql = sql.bindparams(bindparam("ufs", expanding=True))
        if modalidades:
            sql = sql.bindparams(bindparam("mods", expanding=True))
        if statuses:
            sql = sql.bindparams(bindparam("statuses", expanding=True))
        with get_connection() as conn:
            return [dict(r) for r in conn.execute(sql, params).mappings()]
