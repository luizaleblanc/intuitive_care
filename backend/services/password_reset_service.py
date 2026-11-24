import hashlib
import os
import secrets
from datetime import datetime, timedelta
from threading import Thread
from typing import Any, Callable, Dict, Optional

from werkzeug.security import generate_password_hash

from backend.config import Config
from backend.repositories.usuario_repository import UsuarioRepository
from backend.services.email_service import EmailService
from backend.services.jwt_tokens import utc_now
from backend.services.validators import BusinessRuleError, validate_email, validate_password

RESET_MAX_PEDIDOS = 3
RESET_JANELA_MIN = 15


def _sha256_hex(value: str, encoding: str = "utf-8") -> str:
    return hashlib.sha256(value.encode(encoding)).hexdigest()


class PasswordResetService:
    """Fluxo de solicitação, validação e consumo de tokens de redefinição de senha."""

    @staticmethod
    def _enviar_reset(
        email: str,
        nome: str,
        link: str,
        email_service: Any = EmailService,
    ) -> None:
        try:
            email_service.enviar_reset_senha(email, nome, link)
        except Exception as exc:  # A resposta ao cliente não pode revelar falhas por conta.
            print(f"[EMAIL][erro] Falha ao enviar redefinição de senha: {type(exc).__name__}", flush=True)

    @classmethod
    def esqueci_senha(
        cls,
        data: Dict[str, Any],
        *,
        thread_cls: Any = Thread,
        sender: Optional[Callable[[str, str, str], None]] = None,
    ) -> Dict[str, Any]:
        """Registra o pedido com limite por janela e dispara o link sem revelar contas existentes."""
        email = validate_email(data.get("email"))
        agora = utc_now()
        email_hash = _sha256_hex(email)
        if not UsuarioRepository.registrar_pedido_reset(
            email_hash, agora, agora - timedelta(minutes=RESET_JANELA_MIN), RESET_MAX_PEDIDOS
        ):
            raise BusinessRuleError("Muitas tentativas. Aguarde 15 minutos e tente novamente.", 429)

        user_row = UsuarioRepository.find_by_email(email)
        if user_row and bool(user_row.get("ativo", 1)):
            token = secrets.token_urlsafe(32)
            UsuarioRepository.criar_token_reset(
                user_row["id"],
                _sha256_hex(token, encoding="ascii"),
                agora + timedelta(minutes=Config.RESET_TOKEN_EXPIRA_MIN),
            )
            link = f"{Config.FRONTEND_URL}/#/redefinir-senha?token={token}"
            # Em segundo plano, para o tempo de resposta não denunciar contas existentes.
            destino = (user_row["email"], user_row["nome"], link)
            dispatch = sender or cls._enviar_reset
            if os.getenv("VERCEL"):
                # Na Vercel a função congela após responder: o envio precisa terminar antes.
                dispatch(*destino)
            else:
                thread_cls(target=dispatch, args=destino, daemon=True).start()

        return {"mensagem": "Se o e-mail estiver cadastrado, você receberá um link para redefinir a senha."}

    @staticmethod
    def _validar_token_reset(token: str, agora: datetime) -> Dict[str, Any]:
        registro = UsuarioRepository.buscar_token_reset(_sha256_hex(token)) if token else None
        if not registro:
            raise BusinessRuleError("Link de redefinição inválido.", 400)
        if registro.get("usado_em"):
            raise BusinessRuleError("Este link já foi utilizado. Solicite um novo.", 400)

        expira_em = registro["expira_em"]
        if isinstance(expira_em, str):
            expira_em = datetime.fromisoformat(expira_em)
        if expira_em < agora:
            raise BusinessRuleError("Este link expirou. Solicite um novo.", 400)
        return registro

    @classmethod
    def redefinir_senha(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        """Valida nova senha e token único, atualiza a senha e revoga sessões ativas."""
        token = (data.get("token") or "").strip()
        nova_senha = validate_password(data.get("nova_senha"))
        agora = utc_now()
        registro = cls._validar_token_reset(token, agora)

        if not UsuarioRepository.consumir_token_reset(registro["id"], agora):
            raise BusinessRuleError("Este link já foi utilizado. Solicite um novo.", 400)

        usuario_id = registro["usuario_id"]
        UsuarioRepository.update_password(usuario_id, generate_password_hash(nova_senha, method="pbkdf2:sha256"))
        UsuarioRepository.revoke_all_user_sessions(usuario_id)
        return {"mensagem": "Senha redefinida com sucesso. Faça login com a nova senha."}
