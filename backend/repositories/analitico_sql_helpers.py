from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

from sqlalchemy import bindparam, text

Periodo = Tuple[int, int]
PeriodoInput = Union[Periodo, Sequence[Periodo]]


def _norm_periodos(entrada: PeriodoInput) -> List[Periodo]:
    """Normaliza um período `(ano, trimestre)` ou sequência de períodos para lista."""
    if not entrada:
        return []
    if len(entrada) == 2 and isinstance(entrada[0], int) and isinstance(entrada[1], int):
        return [(int(entrada[0]), int(entrada[1]))]
    return [(int(p[0]), int(p[1])) for p in entrada]  # type: ignore[index]


def _norm_lista(valor: Union[str, Sequence[str], None], upper: bool = False) -> List[str]:
    """Normaliza string separada por vírgula ou sequência de textos sem duplicatas."""
    if not valor:
        return []
    brutos = [v.strip() for v in valor.split(",")] if isinstance(valor, str) else [str(v).strip() for v in valor]
    itens = [v.upper() if upper else v for v in brutos if v]
    return list(dict.fromkeys(itens))


def _filtro_periodos(periodos: List[Periodo], alias: str = "d") -> Tuple[str, Dict[str, Any]]:
    """Constrói cláusula SQL parametrizada combinando pares `(ano, trimestre)` com OR."""
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
    """Constrói filtros opcionais de UF e modalidade sobre o alias `o` de `operadoras`."""
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
    """Cria `sqlalchemy.text` aplicando `bindparam(..., expanding=True)` nos nomes informados."""
    stmt = text(sql_text)
    for nome in expanding:
        stmt = stmt.bindparams(bindparam(nome, expanding=True))
    return stmt


def _preparar_filtros(
    periodo: PeriodoInput,
    uf: Union[str, Sequence[str]] = "",
    modalidade: Union[str, Sequence[str]] = "",
    alias: str = "d",
) -> Optional[Tuple[str, str, Dict[str, Any], List[str]]]:
    """Combina filtros de período e operadora; retorna `None` quando não há períodos."""
    periodos = _norm_periodos(periodo)
    if not periodos:
        return None
    cond_p, params_p = _filtro_periodos(periodos, alias)
    filtro, params_f, expanding = _filtro_operadora(uf, modalidade)
    return cond_p, filtro, {**params_p, **params_f}, expanding
