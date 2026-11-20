import json
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Dict, Optional

from backend.models.permissoes import PERFIS, permissoes_do_perfil, tem_permissao

PERFIS_VALIDOS = tuple(PERFIS)

PREFERENCIAS_PADRAO: Dict[str, Any] = {
    "idioma": "pt-BR",
    "formato_data": "DD/MM/AAAA",
    "formato_exportacao": "CSV",
    "uf_padrao": None,
    "trimestre_padrao": 4,
    "tema": "claro",
    "resumo_semanal": True,
    "alerta_novos_dados": True,
    "graficos_explorar": None,
}


def _iso(valor: Any) -> Optional[str]:
    if valor is None:
        return None
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    return str(valor)


@dataclass
class Usuario:
    """Representação de domínio do usuário autenticado/cadastrado."""

    id: Optional[int]
    nome: str
    email: str
    perfil: str = "COLABORADOR"
    ativo: bool = True
    criado_em: Optional[Any] = None
    cargo: Optional[str] = None
    telefone: Optional[str] = None
    data_nascimento: Optional[Any] = None
    foto: Optional[str] = None
    ultimo_acesso: Optional[Any] = None
    preferencias: Dict[str, Any] = field(default_factory=lambda: dict(PREFERENCIAS_PADRAO))

    @property
    def is_admin(self) -> bool:
        return self.perfil == "ADMIN"

    def pode(self, permissao: str) -> bool:
        return tem_permissao(self.perfil, permissao)

    @classmethod
    def from_row(cls, row: Dict[str, Any]) -> "Usuario":
        prefs = dict(PREFERENCIAS_PADRAO)
        bruto = row.get("preferencias")
        if bruto:
            try:
                prefs.update(json.loads(bruto))
            except (TypeError, ValueError):
                pass
        prefs["tema"] = "escuro" if prefs.get("tema") == "escuro" else "claro"
        perfil = row.get("perfil") or "COLABORADOR"
        return cls(
            id=row.get("id"),
            nome=row["nome"],
            email=row["email"],
            perfil=perfil if perfil in PERFIS_VALIDOS else "COLABORADOR",
            ativo=bool(row.get("ativo", 1)),
            criado_em=row.get("criado_em"),
            cargo=row.get("cargo"),
            telefone=row.get("telefone"),
            data_nascimento=row.get("data_nascimento"),
            foto=row.get("foto"),
            ultimo_acesso=row.get("ultimo_acesso"),
            preferencias=prefs,
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "nome": self.nome,
            "email": self.email,
            "perfil": self.perfil,
            "ativo": self.ativo,
            "cargo": self.cargo,
            "telefone": self.telefone,
            "data_nascimento": _iso(self.data_nascimento),
            "foto": self.foto,
            "criado_em": _iso(self.criado_em),
            "membro_desde": _iso(self.criado_em),
            "ultimo_acesso": _iso(self.ultimo_acesso),
            "preferencias": self.preferencias,
            "permissoes": sorted(permissoes_do_perfil(self.perfil)),
        }
