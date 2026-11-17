from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Optional


@dataclass
class Usuario:
    """Representação de domínio do usuário autenticado/cadastrado."""

    id: Optional[int]
    nome: str
    email: str
    perfil: str = "ANALISTA"
    ativo: bool = True
    criado_em: Optional[datetime] = None

    @classmethod
    def from_row(cls, row: Dict[str, Any]) -> "Usuario":
        return cls(
            id=row.get("id"),
            nome=row["nome"],
            email=row["email"],
            perfil=row.get("perfil", "ANALISTA"),
            ativo=bool(row.get("ativo", 1)),
            criado_em=row.get("criado_em"),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "nome": self.nome,
            "email": self.email,
            "perfil": self.perfil,
            "ativo": self.ativo,
            "criado_em": self.criado_em.isoformat() if hasattr(self.criado_em, "isoformat") else self.criado_em,
        }
