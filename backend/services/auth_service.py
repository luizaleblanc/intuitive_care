import base64
import hashlib
import hmac
import json
import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict

from werkzeug.security import check_password_hash, generate_password_hash

from backend.config import Config
from backend.models.usuario_model import PREFERENCIAS_PADRAO, Usuario
from backend.repositories.usuario_repository import UsuarioRepository
from backend.services.email_service import EmailService
from backend.services.validators import BusinessRuleError, validate_email, validate_password


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


class AuthService:
    """Regras de negócio de autenticação, controle de sessão e recuperação de senha."""

    @staticmethod
    def _create_jwt(user: Usuario, jti: str, expires_at: datetime) -> str:
        header = {"alg": "HS256", "typ": "JWT"}
        payload = {
            "sub": str(user.id),
            "email": user.email,
            "nome": user.nome,
            "perfil": user.perfil,
            "jti": jti,
            "iat": int(datetime.now(timezone.utc).replace(tzinfo=None).timestamp()),
            "exp": int(expires_at.timestamp()),
        }
        header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
        payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
        signature = hmac.new(Config.SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
        return f"{header_b64}.{payload_b64}.{_b64url_encode(signature)}"

    @staticmethod
    def verify_token(token: str) -> Dict[str, Any]:
        if not token or token.count(".") != 2:
            raise BusinessRuleError("Token de autenticação inválido.", 401)

        header_b64, payload_b64, sig_b64 = token.split(".")
        signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
        expected_sig = hmac.new(Config.SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
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

        if int(payload.get("exp", 0)) < int(datetime.now(timezone.utc).replace(tzinfo=None).timestamp()):
            raise BusinessRuleError("Sessão expirada. Faça login novamente.", 401)

        jti = payload.get("jti")
        if not jti or not UsuarioRepository.is_session_active(jti):
            raise BusinessRuleError("Sessão encerrada ou revogada. Faça login novamente.", 401)

        user_row = UsuarioRepository.find_by_id(int(payload["sub"]))
        if not user_row or not bool(user_row.get("ativo", 1)):
            raise BusinessRuleError("Usuário inativo ou não encontrado.", 401)

        return {"user": Usuario.from_row(user_row), "jti": jti, "payload": payload}

    @classmethod
    def register(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        nome = (data.get("nome") or "").strip()
        if len(nome) < 3:
            raise BusinessRuleError("O nome completo deve ter pelo menos 3 caracteres.", 400)

        email = validate_email(data.get("email"))
        password = validate_password(data.get("senha") or data.get("password"))

        existing = UsuarioRepository.find_by_email(email)
        if existing:
            raise BusinessRuleError("Já existe um usuário cadastrado com este e-mail.", 409)

        senha_hash = generate_password_hash(password, method="pbkdf2:sha256")
        user_row = UsuarioRepository.create_user(nome=nome, email=email, senha_hash=senha_hash, perfil="CONSUMIDOR")
        user = Usuario.from_row(user_row)

        jti = uuid.uuid4().hex
        expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=Config.TOKEN_EXPIRATION_HOURS)
        UsuarioRepository.save_session_token(user.id, jti, expires_at)  # type: ignore[arg-type]
        token = cls._create_jwt(user, jti, expires_at)

        return {
            "mensagem": "Usuário cadastrado com sucesso.",
            "token": token,
            "expira_em": expires_at.isoformat() + "Z",
            "usuario": user.to_dict(),
        }

    @classmethod
    def login(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        email = validate_email(data.get("email"))
        password = data.get("senha") or data.get("password") or ""
        if not password:
            raise BusinessRuleError("Informe a senha para autenticação.", 400)

        user_row = UsuarioRepository.find_by_email(email)
        if not user_row or not check_password_hash(user_row["senha_hash"], password):
            raise BusinessRuleError("E-mail ou senha inválidos.", 401)

        if not bool(user_row.get("ativo", 1)):
            raise BusinessRuleError("Conta de usuário desativada.", 403)

        UsuarioRepository.touch_ultimo_acesso(user_row["id"])
        user = Usuario.from_row(UsuarioRepository.find_by_id(user_row["id"]) or user_row)
        jti = uuid.uuid4().hex
        expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=Config.TOKEN_EXPIRATION_HOURS)
        UsuarioRepository.save_session_token(user.id, jti, expires_at)  # type: ignore[arg-type]
        token = cls._create_jwt(user, jti, expires_at)

        return {
            "mensagem": "Autenticação realizada com sucesso.",
            "token": token,
            "expira_em": expires_at.isoformat() + "Z",
            "usuario": user.to_dict(),
        }

    @staticmethod
    def logout(jti: str) -> Dict[str, Any]:
        UsuarioRepository.revoke_session_token(jti)
        return {"mensagem": "Logoff realizado com sucesso. Sessão invalidada."}

    @staticmethod
    def update_profile(user_id: int, data: Dict[str, Any]) -> Dict[str, Any]:
        campos: Dict[str, Any] = {}

        if "nome" in data:
            nome = (data.get("nome") or "").strip()
            if len(nome) < 3:
                raise BusinessRuleError("O nome completo deve ter pelo menos 3 caracteres.", 400)
            campos["nome"] = nome[:120]

        if "email" in data:
            email = validate_email(data.get("email"))
            dono = UsuarioRepository.find_by_email(email)
            if dono and int(dono["id"]) != int(user_id):
                raise BusinessRuleError("Este e-mail já está em uso por outro usuário.", 409)
            campos["email"] = email

        for chave, limite in (("cargo", 120), ("telefone", 30)):
            if chave in data:
                valor = (data.get(chave) or "").strip()
                campos[chave] = valor[:limite] or None

        if "data_nascimento" in data:
            valor = (data.get("data_nascimento") or "").strip()
            if valor:
                try:
                    nascimento = datetime.strptime(valor[:10], "%Y-%m-%d").date()
                except ValueError:
                    raise BusinessRuleError("Data de nascimento inválida. Use o formato AAAA-MM-DD.", 400)
                if nascimento > datetime.now().date():
                    raise BusinessRuleError("A data de nascimento não pode estar no futuro.", 400)
                campos["data_nascimento"] = nascimento
            else:
                campos["data_nascimento"] = None

        if "foto" in data:
            foto = data.get("foto")
            if foto:
                if not re.match(r"^data:image/(png|jpe?g);base64,", str(foto)):
                    raise BusinessRuleError("A foto deve ser uma imagem JPG ou PNG.", 400)
                # Base64 ocupa ~4/3 do arquivo original: 2 MB -> ~2,8 MB de texto.
                if len(foto) > 2_800_000:
                    raise BusinessRuleError("A foto deve ter no máximo 2 MB.", 400)
            campos["foto"] = foto or None

        if "preferencias" in data:
            prefs = data.get("preferencias") or {}
            if not isinstance(prefs, dict):
                raise BusinessRuleError("Preferências inválidas.", 400)
            limpas = {k: prefs[k] for k in PREFERENCIAS_PADRAO if k in prefs}
            if limpas.get("tema") not in (None, "claro", "escuro", "sistema"):
                raise BusinessRuleError("Tema inválido.", 400)
            if limpas.get("formato_exportacao") not in (None, "CSV", "PDF", "XLSX"):
                raise BusinessRuleError("Formato de exportação inválido.", 400)
            if limpas.get("trimestre_padrao") not in (None, 1, 2, 3, 4):
                raise BusinessRuleError("Trimestre padrão inválido.", 400)
            atual = UsuarioRepository.find_by_id(user_id) or {}
            base = Usuario.from_row(atual).preferencias if atual else dict(PREFERENCIAS_PADRAO)
            base.update(limpas)
            campos["preferencias"] = json.dumps(base, ensure_ascii=False)

        updated = UsuarioRepository.update_user_profile(user_id, campos)
        if not updated:
            raise BusinessRuleError("Usuário não encontrado.", 404)
        return {
            "mensagem": "Perfil atualizado com sucesso.",
            "usuario": Usuario.from_row(updated).to_dict(),
        }

    @staticmethod
    def forgot_password(data: Dict[str, Any]) -> Dict[str, Any]:
        email = validate_email(data.get("email"))
        user_row = UsuarioRepository.find_by_email(email)

        if not user_row:
            return {
                "mensagem": "Se o e-mail estiver cadastrado, enviaremos um código de recuperação.",
                "email_enviado": True,
            }

        code = f"{secrets.randbelow(900000) + 100000}"
        code_hash = generate_password_hash(code, method="pbkdf2:sha256")
        expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=Config.RESET_CODE_EXPIRATION_MINUTES)
        UsuarioRepository.create_password_reset(user_row["id"], code_hash, expires_at)

        delivery = EmailService.send_password_recovery_email(
            to_email=user_row["email"],
            user_name=user_row["nome"],
            recovery_code=code,
        )

        response: Dict[str, Any] = {
            "mensagem": "Código de recuperação enviado para o e-mail informado.",
            "email_enviado": bool(delivery.get("delivered")),
            "provedor_email": delivery.get("provider"),
            "validade_minutos": Config.RESET_CODE_EXPIRATION_MINUTES,
        }
        if delivery.get("preview_code"):
            response["codigo_demonstracao"] = delivery["preview_code"]
        return response

    @staticmethod
    def reset_password(data: Dict[str, Any]) -> Dict[str, Any]:
        email = validate_email(data.get("email"))
        code = (data.get("codigo") or data.get("code") or "").strip()
        new_password = validate_password(data.get("nova_senha") or data.get("new_password"))

        if not code:
            raise BusinessRuleError("Informe o código de recuperação enviado por e-mail.", 400)

        user_row = UsuarioRepository.find_by_email(email)
        if not user_row:
            raise BusinessRuleError("Código de recuperação inválido ou expirado.", 400)

        reset_row = UsuarioRepository.find_latest_active_reset(user_row["id"])
        if not reset_row:
            raise BusinessRuleError("Nenhuma solicitação de recuperação ativa encontrada.", 400)

        expira_em = reset_row["expira_em"]
        if isinstance(expira_em, str):
            expira_em = datetime.fromisoformat(expira_em)
        if expira_em < datetime.now(timezone.utc).replace(tzinfo=None):
            raise BusinessRuleError("O código de recuperação expirou. Solicite um novo código.", 400)

        if not check_password_hash(reset_row["codigo_hash"], code):
            raise BusinessRuleError("Código de recuperação incorreto.", 400)

        new_hash = generate_password_hash(new_password, method="pbkdf2:sha256")
        UsuarioRepository.update_password(user_row["id"], new_hash)
        UsuarioRepository.mark_reset_used(reset_row["id"])
        UsuarioRepository.revoke_all_user_sessions(user_row["id"])

        return {"mensagem": "Senha redefinida com sucesso. Faça login com a nova senha."}
