"""Funções puras de formatação, normalização de listas e classificação para relatórios ETL."""
from datetime import date, datetime
from typing import Any, List, Optional, Sequence, Tuple

from backend.services.analitico_service import GRUPOS_CONTAS
from backend.services.validators import BusinessRuleError


def fmt_cnpj(valor: Any) -> str:
    s = str(valor or "")
    if len(s) == 14 and s.isdigit():
        return f"{s[:2]}.{s[2:5]}.{s[5:8]}/{s[8:12]}-{s[12:]}"
    d = "".join(c for c in s if c.isdigit())
    if len(d) != 14:
        return s
    return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"


def fmt_periodo(ano: int, tri: Optional[int]) -> str:
    return f"{ano}" if not tri else f"{tri}º trimestre de {ano}"


def fmt_data(valor: Any, formato: str = "DD/MM/AAAA", hora: bool = False) -> str:
    if not valor:
        return ""
    dt: Optional[datetime] = None
    if isinstance(valor, datetime):
        dt = valor
    elif isinstance(valor, date):
        dt = datetime(valor.year, valor.month, valor.day)
    else:
        bruto = str(valor).strip().replace("Z", "")
        for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
            try:
                dt = datetime.strptime(bruto[:19] if len(fmt) > 10 else bruto[:10], fmt)
                break
            except ValueError:
                continue
    if dt is None:
        return str(valor)
    base = dt.strftime("%Y-%m-%d") if formato == "AAAA-MM-DD" else dt.strftime("%d/%m/%Y")
    return f"{base} {dt.strftime('%H:%M')}" if hora else base


def classificar_porte(benef: int) -> str:
    if benef >= 100_000:
        return "Grande porte"
    if benef >= 20_000:
        return "Médio porte"
    return "Pequeno porte"


def na_faixa(valor: float, faixa: Tuple[float, Optional[float]]) -> bool:
    minimo, maximo = faixa
    return valor >= minimo and (maximo is None or valor < maximo)


def norm_lista_str(valor: Any) -> List[str]:
    if not valor:
        return []
    if isinstance(valor, str):
        return [v.strip() for v in valor.split(",") if v.strip()]
    if isinstance(valor, (list, tuple, set)):
        return [str(v).strip() for v in valor if str(v).strip()]
    return []


def norm_lista_int(valor: Any, nome: str) -> List[int]:
    itens = norm_lista_str(valor)
    try:
        return sorted({int(x) for x in itens})
    except ValueError:
        raise BusinessRuleError(f"Parâmetro '{nome}' deve conter apenas números inteiros.", 400)


def grupo_conta(codigo: str) -> str:
    for pref, nome in GRUPOS_CONTAS.items():
        if codigo.startswith(pref):
            return f"{pref} · {nome}"
    return "Outras contas"


def rotulo_anos(anos: Sequence[int]) -> str:
    if not anos:
        return ""
    if len(anos) == 1:
        return str(anos[0])
    if len(anos) == anos[-1] - anos[0] + 1:
        return f"{anos[0]}–{anos[-1]}"
    return ", ".join(str(a) for a in anos)


def rotulo_trimestres(tris: Sequence[int]) -> str:
    if not tris or len(tris) == 4:
        return "Todos os trimestres"
    return ", ".join(f"{t}º trimestre" for t in tris)
