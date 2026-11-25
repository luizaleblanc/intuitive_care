import json
import re
import uuid
from datetime import datetime
from threading import Thread
from typing import Any, Dict, Optional

from werkzeug.security import check_password_hash, generate_password_hash

from backend.models.usuario_model import PREFERENCIAS_PADRAO, Usuario
from backend.repositories.usuario_repository import UsuarioRepository
from backend.services.email_service import EmailService
from backend.services.jwt_tokens import _create_jwt, token_expiration, verify_token
from backend.services.password_reset_service import PasswordResetService
from backend.services.validators import BusinessRuleError, validar_graficos, validate_email, validate_password


def _parse_data_nascimento(raw_value: Any):
    valor = (raw_value or "").strip()
    if not valor:
        return None
    nascimento = None
    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            nascimento = datetime.strptime(valor[:10], fmt).date()
            break
        except ValueError:
            continue
    if nascimento is None:
        raise BusinessRuleError("Data de nascimento inválida. Use o formato AAAA-MM-DD.", 400)
    if nascimento > datetime.now().date():
        raise BusinessRuleError("A data de nascimento não pode estar no futuro.", 400)
    return nascimento


def _validar_foto_perfil(foto: Any) -> Optional[str]:
    if not foto:
        return None
    if not re.match(r"^data:image/(png|jpe?g|webp);base64,", str(foto)):
        raise BusinessRuleError("A foto deve ser uma imagem JPG, PNG ou WebP.", 400)
    # Base64 ocupa ~4/3 do arquivo original: 2 MB -> ~2,8 MB de texto.
    if len(foto) > 2_800_000:
        raise BusinessRuleError("A foto deve ter no máximo 2 MB.", 400)
    return foto


def _preparar_preferencias(user_id: int, raw_prefs: Any) -> str:
    prefs = raw_prefs or {}
    if not isinstance(prefs, dict):
        raise BusinessRuleError("Preferências inválidas.", 400)
    atual = UsuarioRepository.find_by_id(user_id) or {}
    usuario_atual = Usuario.from_row(atual) if atual else None
    limpas = {k: prefs[k] for k in PREFERENCIAS_PADRAO if k in prefs}
    if usuario_atual and not usuario_atual.is_admin:
        for chave_admin in ("formato_exportacao", "resumo_semanal", "alerta_novos_dados"):
            limpas.pop(chave_admin, None)
    if limpas.get("tema") not in (None, "claro", "escuro"):
        raise BusinessRuleError("Tema inválido.", 400)
    if limpas.get("formato_exportacao") not in (None, "CSV", "PDF", "XLSX"):
        raise BusinessRuleError("Formato de exportação inválido.", 400)
    if limpas.get("trimestre_padrao") not in (None, 1, 2, 3, 4):
        raise BusinessRuleError("Trimestre padrão inválido.", 400)
    if "graficos_explorar" in limpas:
        limpas["graficos_explorar"] = validar_graficos(limpas["graficos_explorar"])
    base = usuario_atual.preferencias if usuario_atual else dict(PREFERENCIAS_PADRAO)
    base.update(limpas)
    return json.dumps(base, ensure_ascii=False)


class AuthService:
    """Regras de negócio de autenticação, controle de sessão e recuperação de senha."""

    @staticmethod
    def _create_jwt(user: Usuario, jti: str, expires_at: datetime) -> str:
        return _create_jwt(user, jti, expires_at)

    @staticmethod
    def verify_token(token: str) -> Dict[str, Any]:
        return verify_token(token)

    @classmethod
    def _emitir_sessao(cls, user: Usuario, mensagem: str) -> Dict[str, Any]:
        jti = uuid.uuid4().hex
        expires_at = token_expiration()
        UsuarioRepository.save_session_token(user.id, jti, expires_at)  # type: ignore[arg-type]
        token = cls._create_jwt(user, jti, expires_at)
        return {
            "mensagem": mensagem,
            "token": token,
            "expira_em": expires_at.isoformat() + "Z",
            "usuario": user.to_dict(),
        }

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
        user_row = UsuarioRepository.create_user(nome=nome, email=email, senha_hash=senha_hash, perfil="COLABORADOR")
        cargo = (data.get("cargo") or "").strip()[:120]
        if cargo:
            user_row = UsuarioRepository.update_user_profile(user_row["id"], {"cargo": cargo}) or user_row
        user = Usuario.from_row(user_row)
        return cls._emitir_sessao(user, "Usuário cadastrado com sucesso.")

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

        user_row["ultimo_acesso"] = UsuarioRepository.touch_ultimo_acesso(user_row["id"])
        user = Usuario.from_row(user_row)
        return cls._emitir_sessao(user, "Autenticação realizada com sucesso.")

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
            campos["data_nascimento"] = _parse_data_nascimento(data.get("data_nascimento"))

        if "foto" in data:
            campos["foto"] = _validar_foto_perfil(data.get("foto"))

        if "preferencias" in data:
            campos["preferencias"] = _preparar_preferencias(user_id, data.get("preferencias"))

        updated = UsuarioRepository.update_user_profile(user_id, campos)
        if not updated:
            raise BusinessRuleError("Usuário não encontrado.", 404)
        return {
            "mensagem": "Perfil atualizado com sucesso.",
            "usuario": Usuario.from_row(updated).to_dict(),
        }

    @staticmethod
    def _enviar_reset(email: str, nome: str, link: str) -> None:
        PasswordResetService._enviar_reset(email, nome, link, email_service=EmailService)

    @classmethod
    def esqueci_senha(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        # Thread e EmailService são resolvidos no namespace deste módulo para preservar mocks.
        return PasswordResetService.esqueci_senha(data, thread_cls=Thread, sender=cls._enviar_reset)

    @staticmethod
    def redefinir_senha(data: Dict[str, Any]) -> Dict[str, Any]:
        return PasswordResetService.redefinir_senha(data)
