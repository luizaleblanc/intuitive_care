from datetime import datetime, timezone
from typing import Any, Dict, Optional

from sqlalchemy import text

from backend.database.connection import get_connection


class UsuarioRepository:
    """Camada de persistência para usuários, sessões JWT e códigos de recuperação."""

    @staticmethod
    def find_by_email(email: str) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = (
                conn.execute(
                    text("SELECT * FROM usuarios WHERE LOWER(email) = LOWER(:email) LIMIT 1"),
                    {"email": email},
                )
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def find_by_id(user_id: int) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = (
                conn.execute(
                    text("SELECT * FROM usuarios WHERE id = :id LIMIT 1"),
                    {"id": user_id},
                )
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def create_user(nome: str, email: str, senha_hash: str, perfil: str = "COLABORADOR") -> Dict[str, Any]:
        with get_connection() as conn:
            result = conn.execute(
                text(
                    "INSERT INTO usuarios (nome, email, senha_hash, perfil, ativo) "
                    "VALUES (:nome, :email, :senha_hash, :perfil, 1)"
                ),
                {"nome": nome, "email": email.lower(), "senha_hash": senha_hash, "perfil": perfil},
            )
            user_id = result.lastrowid
            row = (
                conn.execute(text("SELECT * FROM usuarios WHERE id = :id"), {"id": user_id})
                .mappings()
                .first()
            )
            return dict(row)

    @staticmethod
    def update_user_profile(user_id: int, campos: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        permitidos = ["nome", "email", "cargo", "telefone", "data_nascimento", "foto", "preferencias"]
        sets = [f"{c} = :{c}" for c in permitidos if c in campos]
        with get_connection() as conn:
            if sets:
                params = {c: campos[c] for c in permitidos if c in campos}
                params["id"] = user_id
                conn.execute(text(f"UPDATE usuarios SET {', '.join(sets)} WHERE id = :id"), params)
            row = (
                conn.execute(text("SELECT * FROM usuarios WHERE id = :id"), {"id": user_id})
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def touch_ultimo_acesso(user_id: int) -> None:
        with get_connection() as conn:
            conn.execute(
                text("UPDATE usuarios SET ultimo_acesso = :agora WHERE id = :id"),
                {"agora": datetime.now(timezone.utc).replace(tzinfo=None), "id": user_id},
            )

    @staticmethod
    def update_password(user_id: int, senha_hash: str) -> None:
        with get_connection() as conn:
            conn.execute(
                text("UPDATE usuarios SET senha_hash = :senha_hash WHERE id = :id"),
                {"senha_hash": senha_hash, "id": user_id},
            )

    @staticmethod
    def save_session_token(usuario_id: int, token_jti: str, expira_em: datetime) -> None:
        with get_connection() as conn:
            conn.execute(
                text(
                    "INSERT INTO sessoes_tokens (usuario_id, token_jti, expira_em, revogado) "
                    "VALUES (:usuario_id, :token_jti, :expira_em, 0)"
                ),
                {"usuario_id": usuario_id, "token_jti": token_jti, "expira_em": expira_em},
            )

    @staticmethod
    def is_session_active(token_jti: str) -> bool:
        with get_connection() as conn:
            row = (
                conn.execute(
                    text(
                        "SELECT revogado, expira_em FROM sessoes_tokens "
                        "WHERE token_jti = :token_jti LIMIT 1"
                    ),
                    {"token_jti": token_jti},
                )
                .mappings()
                .first()
            )
            if not row:
                return False
            if bool(row["revogado"]):
                return False
            expira_em = row["expira_em"]
            if isinstance(expira_em, str):
                expira_em = datetime.fromisoformat(expira_em)
            return expira_em > datetime.now(timezone.utc).replace(tzinfo=None)

    @staticmethod
    def revoke_session_token(token_jti: str) -> bool:
        with get_connection() as conn:
            res = conn.execute(
                text("UPDATE sessoes_tokens SET revogado = 1 WHERE token_jti = :token_jti"),
                {"token_jti": token_jti},
            )
            return res.rowcount > 0

    @staticmethod
    def revoke_all_user_sessions(usuario_id: int) -> None:
        with get_connection() as conn:
            conn.execute(
                text("UPDATE sessoes_tokens SET revogado = 1 WHERE usuario_id = :usuario_id"),
                {"usuario_id": usuario_id},
            )

    @staticmethod
    def registrar_pedido_reset(email_hash: str, agora: datetime, limite_desde: datetime, maximo: int) -> bool:
        """Conta o pedido por e-mail (cadastrado ou não); retorna False se passou do limite."""
        with get_connection() as conn:
            conn.execute(text("DELETE FROM pedidos_reset_senha WHERE criado_em < :d"), {"d": limite_desde})
            total = conn.execute(
                text("SELECT COUNT(*) FROM pedidos_reset_senha WHERE email_hash = :h"), {"h": email_hash}
            ).scalar()
            if int(total or 0) >= maximo:
                return False
            conn.execute(
                text("INSERT INTO pedidos_reset_senha (email_hash, criado_em) VALUES (:h, :c)"),
                {"h": email_hash, "c": agora},
            )
            return True

    @staticmethod
    def criar_token_reset(usuario_id: int, token_hash: str, expira_em: datetime) -> None:
        """Cria o token e descarta os pendentes: só o link mais recente vale."""
        with get_connection() as conn:
            conn.execute(
                text("DELETE FROM tokens_reset_senha WHERE usuario_id = :u AND usado_em IS NULL"),
                {"u": usuario_id},
            )
            conn.execute(
                text(
                    "INSERT INTO tokens_reset_senha (usuario_id, token_hash, expira_em) "
                    "VALUES (:u, :h, :e)"
                ),
                {"u": usuario_id, "h": token_hash, "e": expira_em},
            )

    @staticmethod
    def buscar_token_reset(token_hash: str) -> Optional[Dict[str, Any]]:
        with get_connection() as conn:
            row = (
                conn.execute(text("SELECT * FROM tokens_reset_senha WHERE token_hash = :h"), {"h": token_hash})
                .mappings()
                .first()
            )
            return dict(row) if row else None

    @staticmethod
    def consumir_token_reset(token_id: int, agora: datetime) -> bool:
        """Marca o uso de forma atômica; em pedidos simultâneos, só um vence."""
        with get_connection() as conn:
            res = conn.execute(
                text("UPDATE tokens_reset_senha SET usado_em = :a WHERE id = :i AND usado_em IS NULL"),
                {"a": agora, "i": token_id},
            )
            return res.rowcount == 1
