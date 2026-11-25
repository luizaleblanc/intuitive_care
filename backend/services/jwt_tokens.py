import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from backend.config import Config
from backend.models.usuario_model import Usuario
from backend.repositories.usuario_repository import UsuarioRepository
from backend.services.validators import BusinessRuleError


def utc_now() -> datetime:
    """Retorna o instante atual em UTC sem tzinfo para comparação uniforme com o banco."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def token_expiration(hours: Optional[int] = None) -> datetime:
    """Calcula a data/hora de expiração do token de sessão."""
    ttl = Config.TOKEN_EXPIRATION_HOURS if hours is None else hours
    return utc_now() + timedelta(hours=ttl)


def _secret_key_bytes() -> bytes:
    return Config.SECRET_KEY.encode("utf-8")


def _sign_hs256(signing_input: bytes) -> bytes:
    return hmac.new(_secret_key_bytes(), signing_input, hashlib.sha256).digest()


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _create_jwt(user: Usuario, jti: str, expires_at: datetime) -> str:
    """Gera e assina um JWT HS256 para a sessão autenticada do usuário."""
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "nome": user.nome,
        "perfil": user.perfil,
        "jti": jti,
        "iat": int(utc_now().timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    signature = _sign_hs256(signing_input)
    return f"{header_b64}.{payload_b64}.{_b64url_encode(signature)}"


def decode_jwt(token: str) -> Dict[str, Any]:
    """Valida formato, assinatura HMAC-SHA256 e expiração de um JWT."""
    if not token or token.count(".") != 2:
        raise BusinessRuleError("Token de autenticação inválido.", 401)

    header_b64, payload_b64, sig_b64 = token.split(".")
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    expected_sig = _sign_hs256(signing_input)
    try:
        provided_sig = _b64url_decode(sig_b64)
    except Exception:
        raise BusinessRuleError("Assinatura do token malformada.", 401)

    if not hmac.compare_digest(expected_sig, provided_sig):
        raise BusinessRuleError("Token de autenticação com assinatura inválida.", 401)

    try:
        payload = json.loads(_b64url_decode(payload_b64).decode("utf-8"))
    except Exception:
        raise BusinessRuleError("Carga útil do token inválida.", 401)

    if int(payload.get("exp", 0)) < int(utc_now().timestamp()):
        raise BusinessRuleError("Sessão expirada. Faça login novamente.", 401)

    return payload


def verify_token(token: str) -> Dict[str, Any]:
    """Verifica o JWT, confirma sessão ativa no banco e carrega o usuário ativo em 1 consulta."""
    payload = decode_jwt(token)

    jti = payload.get("jti")
    row = UsuarioRepository.find_active_session_user(jti) if jti else None
    if not row or bool(row.get("sessao_revogada")):
        raise BusinessRuleError("Sessão encerrada ou revogada. Faça login novamente.", 401)

    expira_em = row.get("sessao_expira_em")
    if isinstance(expira_em, str):
        expira_em = datetime.fromisoformat(expira_em)
    if not expira_em or expira_em <= utc_now():
        raise BusinessRuleError("Sessão encerrada ou revogada. Faça login novamente.", 401)

    user_data = {k: v for k, v in row.items() if k not in ("sessao_revogada", "sessao_expira_em")}
    if user_data.get("id") is None or int(user_data["id"]) != int(payload["sub"]) or not bool(user_data.get("ativo", 1)):
        raise BusinessRuleError("Usuário inativo ou não encontrado.", 401)

    return {"user": Usuario.from_row(user_data), "jti": jti, "payload": payload}
