from typing import Any, Dict, List, Sequence, Tuple

from sqlalchemy import bindparam, text

from backend.database.connection import get_connection


def _rows_to_dicts(result) -> List[Dict[str, Any]]:
    cols = tuple(result.keys())
    return [dict(zip(cols, row)) for row in result.all()]


class RelatorioRepository:
    """Consultas completas diretamente sobre todas as tabelas alimentadas pelo ETL da ANS."""

    @staticmethod
    def anos_disponiveis(conn=None) -> List[int]:
        def _run(c):
            return [
                int(r[0])
                for r in c.execute(text("SELECT DISTINCT ano FROM demonstracoes_operadora ORDER BY ano"))
            ]

        if conn is not None:
            return _run(conn)
        with get_connection() as c:
            return _run(c)

    @staticmethod
    def demonstracoes_detalhadas(
        anos: Sequence[int],
        trimestres: Sequence[int] = (),
        ufs: Sequence[str] = (),
        modalidades: Sequence[str] = (),
        statuses: Sequence[str] = (),
        consolidacao: str = "",
        conn=None,
    ) -> List[Dict[str, Any]]:
        """Retorna a base fato granular (demonstracoes_operadora + operadoras + beneficiarios_trimestre + lotes_etl)."""
        condicoes = ["d.ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]

        if trimestres:
            condicoes.append("d.trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")
        if ufs:
            condicoes.append("o.uf IN :ufs")
            params["ufs"] = list(ufs)
            expanding.append("ufs")
        if modalidades:
            condicoes.append("o.modalidade IN :mods")
            params["mods"] = list(modalidades)
            expanding.append("mods")
        if statuses:
            condicoes.append("o.status IN :statuses")
            params["statuses"] = list(statuses)
            expanding.append("statuses")
        if consolidacao == "consolidado":
            condicoes.append("COALESCE(l.auditado, 0) = 1")
        elif consolidacao == "pendente":
            condicoes.append("COALESCE(l.auditado, 0) = 0")

        sql = text(
            "SELECT d.ano, d.trimestre, d.reg_ans, "
            "o.cnpj, o.razao_social, o.nome_fantasia, o.modalidade, o.uf, o.cidade, o.status, "
            "COALESCE(o.beneficiarios, 0) AS benef_cadop, "
            "COALESCE(d.contraprestacoes, 0) AS contraprestacoes, "
            "COALESCE(d.eventos, 0) AS eventos, "
            "COALESCE(d.eventos_mh, 0) AS eventos_mh, "
            "COALESCE(d.comercializacao, 0) AS comercializacao, "
            "COALESCE(d.administrativas, 0) AS administrativas, "
            "COALESCE(b.medico_hospitalar, 0) AS benef_mh, "
            "COALESCE(b.odontologico, 0) AS benef_odonto, "
            "COALESCE(l.auditado, 0) AS auditado "
            "FROM demonstracoes_operadora d "
            "JOIN operadoras o ON o.registro_ans = d.reg_ans "
            "LEFT JOIN lotes_etl l ON l.ano = d.ano AND l.trimestre = d.trimestre "
            "LEFT JOIN beneficiarios_trimestre b "
            "  ON b.reg_ans = d.reg_ans AND b.ano = d.ano AND b.trimestre = d.trimestre "
            f"WHERE {' AND '.join(condicoes)}"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        def _run(c):
            linhas = _rows_to_dicts(c.execute(sql, params))
            linhas.sort(
                key=lambda r: (int(r["ano"]), int(r["trimestre"]), float(r["eventos"] or 0)),
                reverse=True,
            )
            return linhas

        if conn is not None:
            return _run(conn)
        with get_connection() as c:
            return _run(c)

    @staticmethod
    def demonstracoes_brutas(
        anos: Sequence[int], trimestres: Sequence[int] = (), conn=None
    ) -> List[Tuple[Any, ...]]:
        """Leitura compacta (sem JOIN repetindo strings) da tabela `demonstracoes_operadora`."""
        condicoes = ["ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]
        if trimestres:
            condicoes.append("trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")

        sql = text(
            "SELECT ano, trimestre, reg_ans, "
            "COALESCE(contraprestacoes, 0), COALESCE(eventos, 0), COALESCE(eventos_mh, 0), "
            "COALESCE(comercializacao, 0), COALESCE(administrativas, 0) "
            "FROM demonstracoes_operadora "
            f"WHERE {' AND '.join(condicoes)}"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        if conn is not None:
            return conn.execute(sql, params).all()
        with get_connection() as c:
            return c.execute(sql, params).all()

    @staticmethod
    def beneficiarios_mapa(
        anos: Sequence[int], trimestres: Sequence[int] = (), conn=None
    ) -> Dict[Tuple[str, int, int], Tuple[int, int]]:
        """Mapa O(1) `(reg_ans, ano, trimestre) -> (medico_hospitalar, odontologico)`."""
        condicoes = ["ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]
        if trimestres:
            condicoes.append("trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")

        sql = text(
            "SELECT reg_ans, ano, trimestre, "
            "COALESCE(medico_hospitalar, 0), COALESCE(odontologico, 0) "
            "FROM beneficiarios_trimestre "
            f"WHERE {' AND '.join(condicoes)}"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        def _run(c):
            return {
                (r[0], int(r[1]), int(r[2])): (int(r[3] or 0), int(r[4] or 0))
                for r in c.execute(sql, params).all()
            }

        if conn is not None:
            return _run(conn)
        with get_connection() as c:
            return _run(c)

    @staticmethod
    def contas_setor(anos: Sequence[int], trimestres: Sequence[int] = (), conn=None) -> List[Dict[str, Any]]:
        """Plano de contas consolidado do setor (tabela contas_setor)."""
        condicoes = ["ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]
        if trimestres:
            condicoes.append("trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")

        sql = text(
            "SELECT ano, trimestre, codigo, descricao, nivel, COALESCE(valor, 0) AS valor "
            "FROM contas_setor "
            f"WHERE {' AND '.join(condicoes)} "
            "ORDER BY ano DESC, trimestre DESC, codigo ASC"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        if conn is not None:
            return _rows_to_dicts(conn.execute(sql, params))
        with get_connection() as c:
            return _rows_to_dicts(c.execute(sql, params))

    @staticmethod
    def lotes_etl(anos: Sequence[int], trimestres: Sequence[int] = (), conn=None) -> List[Dict[str, Any]]:
        """Histórico de extração e auditoria dos lotes ETL (tabela lotes_etl)."""
        condicoes = ["ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]
        if trimestres:
            condicoes.append("trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")

        sql = text(
            "SELECT ano, trimestre, registros_extraidos, operadoras, carregado_em, "
            "auditado, auditado_por, auditado_em "
            "FROM lotes_etl "
            f"WHERE {' AND '.join(condicoes)} "
            "ORDER BY ano DESC, trimestre DESC"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        if conn is not None:
            return _rows_to_dicts(conn.execute(sql, params))
        with get_connection() as c:
            return _rows_to_dicts(c.execute(sql, params))

    @staticmethod
    def cadastro_operadoras(
        ufs: Sequence[str] = (),
        modalidades: Sequence[str] = (),
        statuses: Sequence[str] = (),
        conn=None,
    ) -> List[Dict[str, Any]]:
        """Cadastro completo CADOP de operadoras (tabela operadoras)."""
        condicoes = ["1=1"]
        params: Dict[str, Any] = {}
        expanding: List[str] = []
        if ufs:
            condicoes.append("uf IN :ufs")
            params["ufs"] = list(ufs)
            expanding.append("ufs")
        if modalidades:
            condicoes.append("modalidade IN :mods")
            params["mods"] = list(modalidades)
            expanding.append("mods")
        if statuses:
            condicoes.append("status IN :statuses")
            params["statuses"] = list(statuses)
            expanding.append("statuses")

        sql = text(
            "SELECT registro_ans, cnpj, razao_social, nome_fantasia, modalidade, status, "
            "uf, cidade, COALESCE(beneficiarios, 0) AS beneficiarios, "
            "COALESCE(beneficiarios_mh, 0) AS beneficiarios_mh, "
            "data_descredenciamento, representante, email, telefone "
            "FROM operadoras "
            f"WHERE {' AND '.join(condicoes)} "
            "ORDER BY status ASC, beneficiarios DESC, razao_social ASC"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        if conn is not None:
            return _rows_to_dicts(conn.execute(sql, params))
        with get_connection() as c:
            return _rows_to_dicts(c.execute(sql, params))

    @staticmethod
    def resumo_despesas(anos: Sequence[int], trimestres: Sequence[int] = (), conn=None) -> Dict[str, Any]:
        """Resumo de registros presentes na tabela `despesas` no período filtrado (compatível SQLite e MySQL)."""
        condicoes = ["ano IN :anos"]
        params: Dict[str, Any] = {"anos": list(anos)}
        expanding = ["anos"]
        if trimestres:
            condicoes.append("trimestre IN :tris")
            params["tris"] = list(trimestres)
            expanding.append("tris")

        sql = text(
            "SELECT COUNT(*) AS total_registros, COALESCE(SUM(valor_despesa), 0) AS total_valor "
            "FROM despesas "
            f"WHERE {' AND '.join(condicoes)}"
        )
        for nome in expanding:
            sql = sql.bindparams(bindparam(nome, expanding=True))

        def _run(c):
            row = c.execute(sql, params).first()
            return {
                "total_registros": int(row[0] or 0) if row else 0,
                "total_valor": float(row[1] or 0) if row else 0.0,
            }

        if conn is not None:
            return _run(conn)
        with get_connection() as c:
            return _run(c)

    @classmethod
    def carregar_pacote_etl(
        cls,
        anos: Sequence[int],
        trimestres: Sequence[int] = (),
        ufs: Sequence[str] = (),
        modalidades: Sequence[str] = (),
        statuses: Sequence[str] = (),
        incluir_contas: bool = True,
    ) -> Dict[str, Any]:
        """Carrega todas as tabelas ETL sem JOINs redundantes em uma única conexão com o banco."""
        with get_connection() as conn:
            return {
                "operadoras": cls.cadastro_operadoras(ufs, modalidades, statuses, conn=conn),
                "demonstracoes_brutas": cls.demonstracoes_brutas(anos, trimestres, conn=conn),
                "beneficiarios_mapa": cls.beneficiarios_mapa(anos, trimestres, conn=conn),
                "contas_setor": cls.contas_setor(anos, trimestres, conn=conn) if incluir_contas else [],
                "lotes_etl": cls.lotes_etl(anos, trimestres, conn=conn),
                "despesas_resumo": cls.resumo_despesas(anos, trimestres, conn=conn),
            }
