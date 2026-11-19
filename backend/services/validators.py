import re
from datetime import datetime, timezone
from typing import Optional

VALID_UFS = {
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA",
    "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN",
    "RS", "RO", "RR", "SC", "SP", "SE", "TO",
}

EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class BusinessRuleError(Exception):
    """Exceção de regra de negócio/validação com código HTTP apropriado."""

    def __init__(self, message: str, status_code: int = 400, details: Optional[dict] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.details = details or {}


def only_digits(value: Optional[str]) -> str:
    return re.sub(r"\D", "", value or "")


def validate_email(email: Optional[str]) -> str:
    cleaned = (email or "").strip().lower()
    if not cleaned or not EMAIL_REGEX.match(cleaned):
        raise BusinessRuleError("Informe um endereço de e-mail válido.", 400)
    return cleaned


def validate_password(password: Optional[str]) -> str:
    pwd = password or ""
    if (
        len(pwd) < 8
        or not re.search(r"[A-Z]", pwd)
        or not re.search(r"\d", pwd)
        or not re.search(r"[^A-Za-z0-9]", pwd)
    ):
        raise BusinessRuleError(
            "A senha deve ter ao menos 8 caracteres, com letra maiúscula, número e símbolo.", 400
        )
    return pwd


def validate_cnpj(cnpj: Optional[str]) -> str:
    digits = only_digits(cnpj)
    if len(digits) != 14:
        raise BusinessRuleError("O CNPJ deve conter exatamente 14 dígitos numéricos.", 400)
    if digits == digits[0] * 14:
        raise BusinessRuleError("CNPJ inválido (sequência repetida).", 400)

    weights_1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    weights_2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]

    sum_1 = sum(int(d) * w for d, w in zip(digits[:12], weights_1))
    d1 = 0 if (sum_1 % 11) < 2 else 11 - (sum_1 % 11)

    sum_2 = sum(int(d) * w for d, w in zip(digits[:13], weights_2))
    d2 = 0 if (sum_2 % 11) < 2 else 11 - (sum_2 % 11)

    if digits[-2:] != f"{d1}{d2}":
        raise BusinessRuleError("CNPJ inválido: dígitos verificadores não conferem.", 400)
    return digits


def validate_registro_ans(registro_ans: Optional[str]) -> str:
    digits = only_digits(registro_ans)
    if not digits or not (4 <= len(digits) <= 20):
        raise BusinessRuleError("O Registro ANS deve conter entre 4 e 20 dígitos numéricos.", 400)
    return digits


def validate_uf(uf: Optional[str]) -> str:
    cleaned = (uf or "").strip().upper()
    if cleaned not in VALID_UFS:
        raise BusinessRuleError(f"UF '{cleaned}' inválida. Informe uma sigla estadual brasileira válida.", 400)
    return cleaned


def validate_ano(ano) -> int:
    try:
        year = int(ano)
    except (TypeError, ValueError):
        raise BusinessRuleError("O ano da despesa deve ser um número inteiro válido.", 400)
    max_year = datetime.now(timezone.utc).year + 1
    if year < 2000 or year > max_year:
        raise BusinessRuleError(f"O ano da despesa deve estar entre 2000 e {max_year}.", 400)
    return year


def validate_trimestre(trimestre) -> int:
    try:
        quarter = int(trimestre)
    except (TypeError, ValueError):
        raise BusinessRuleError("O trimestre deve ser um número inteiro entre 1 e 4.", 400)
    if quarter not in (1, 2, 3, 4):
        raise BusinessRuleError("O trimestre deve estar entre 1 e 4.", 400)
    return quarter


def validate_valor_despesa(valor) -> float:
    try:
        amount = float(str(valor).replace(",", "."))
    except (TypeError, ValueError):
        raise BusinessRuleError("O valor da despesa deve ser numérico.", 400)
    if amount <= 0:
        raise BusinessRuleError("O valor da despesa deve ser maior que zero.", 400)
    return round(amount, 2)


TIPOS_GRAFICO = ("pill_bar", "donut_sage", "trend_area", "horizontal_ranking")
METRICAS_GRAFICO = ("despesas", "receitas", "sinistralidade", "beneficiarios")


def validar_graficos(graficos):
    """Layout de gráficos da tela Explorar salvo nas preferências (até 8 cartões)."""
    if graficos is None:
        return None
    if not isinstance(graficos, list) or len(graficos) > 8:
        raise BusinessRuleError("Configuração de gráficos inválida (máximo de 8).", 400)
    limpos = []
    for g in graficos:
        if not isinstance(g, dict) or g.get("tipo") not in TIPOS_GRAFICO or g.get("metrica") not in METRICAS_GRAFICO:
            raise BusinessRuleError("Tipo de gráfico ou métrica inválida.", 400)
        limpos.append({"tipo": g["tipo"], "metrica": g["metrica"]})
    return limpos
