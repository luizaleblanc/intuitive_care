from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass
class Operadora:
    """Representação de domínio de uma operadora de saúde registrada na ANS."""

    registro_ans: str
    cnpj: str
    razao_social: str
    uf: str
    nome_fantasia: Optional[str] = None
    modalidade: Optional[str] = None
    logradouro: Optional[str] = None
    numero: Optional[str] = None
    complemento: Optional[str] = None
    bairro: Optional[str] = None
    cidade: Optional[str] = None
    cep: Optional[str] = None
    telefone: Optional[str] = None
    email: Optional[str] = None
    representante: Optional[str] = None
    cargo_representante: Optional[str] = None
    total_despesas: Optional[float] = None

    @classmethod
    def from_row(cls, row: Dict[str, Any]) -> "Operadora":
        total = row.get("total_despesas")
        return cls(
            registro_ans=str(row["registro_ans"]),
            cnpj=str(row["cnpj"]),
            razao_social=row["razao_social"],
            uf=row["uf"],
            nome_fantasia=row.get("nome_fantasia"),
            modalidade=row.get("modalidade"),
            logradouro=row.get("logradouro"),
            numero=row.get("numero"),
            complemento=row.get("complemento"),
            bairro=row.get("bairro"),
            cidade=row.get("cidade"),
            cep=row.get("cep"),
            telefone=row.get("telefone"),
            email=row.get("email"),
            representante=row.get("representante"),
            cargo_representante=row.get("cargo_representante"),
            total_despesas=float(total) if total is not None else None,
        )

    def to_dict(self) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "registro_ans": self.registro_ans,
            "reg_ans": self.registro_ans,
            "cnpj": self.cnpj,
            "razao_social": self.razao_social,
            "nome_fantasia": self.nome_fantasia,
            "modalidade": self.modalidade,
            "logradouro": self.logradouro,
            "numero": self.numero,
            "complemento": self.complemento,
            "bairro": self.bairro,
            "cidade": self.cidade,
            "uf": self.uf,
            "cep": self.cep,
            "telefone": self.telefone,
            "email": self.email,
            "representante": self.representante,
            "cargo_representante": self.cargo_representante,
        }
        if self.total_despesas is not None:
            payload["total_despesas"] = self.total_despesas
        return payload
