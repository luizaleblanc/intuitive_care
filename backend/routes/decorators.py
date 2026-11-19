from functools import wraps
from typing import Any, Dict

from flask import g, request

from backend.models.permissoes import PERMISSOES
from backend.services.auth_service import AuthService
from backend.services.validators import BusinessRuleError


def get_json_body() -> Dict[str, Any]:
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise BusinessRuleError("Corpo da requisição deve ser um objeto JSON válido.", 400)
    return data


def token_required(fn):
    """Middleware que exige Bearer Token válido e sessão ativa no banco de dados."""

    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise BusinessRuleError("Cabeçalho Authorization (Bearer <token>) obrigatório.", 401)
        token = auth_header.split(" ", 1)[1].strip()
        session_info = AuthService.verify_token(token)
        g.current_user = session_info["user"]
        g.current_jti = session_info["jti"]
        return fn(*args, **kwargs)

    return wrapper


def permissao_required(permissao: str):
    """Exige a permissão (ver backend/models/permissoes.py). Usar abaixo de @token_required."""
    if permissao not in PERMISSOES:
        raise KeyError(f"Permissão desconhecida: {permissao}")

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            user = getattr(g, "current_user", None)
            if user is None or not user.pode(permissao):
                raise BusinessRuleError("Ação permitida apenas para o perfil Administrador.", 403)
            return fn(*args, **kwargs)

        return wrapper

    return decorator
