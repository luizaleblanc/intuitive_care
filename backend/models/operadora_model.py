from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Dict, Optional

STATUS_VALIDOS = ("Ativa", "Em análise", "Inativa")


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
    status: str = "Ativa"
    beneficiarios: int = 0
    data_descredenciamento: Optional[Any] = None
    total_despesas: Optional[float] = None
    despesa_trimestre: Optional[float] = None

    @classmethod
    def from_row(cls, row: Dict[str, Any]) -> "Operadora":
        total = row.get("total_despesas")
        tri = row.get("despesa_trimestre")
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
            status=row.get("status") or "Ativa",
            beneficiarios=int(row.get("beneficiarios") or 0),
            data_descredenciamento=row.get("data_descredenciamento"),
            total_despesas=float(total) if total is not None else None,
            despesa_trimestre=float(tri) if tri is not None else None,
        )

    def to_dict(self) -> Dict[str, Any]:
        desc = self.data_descredenciamento
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
            "status": self.status,
            "beneficiarios": self.beneficiarios,
            "data_descredenciamento": desc.isoformat() if isinstance(desc, (date, datetime)) else desc,
        }
        if self.total_despesas is not None:
            payload["total_despesas"] = self.total_despesas
        if self.despesa_trimestre is not None:
            payload["despesa_trimestre"] = self.despesa_trimestre
        return payload
