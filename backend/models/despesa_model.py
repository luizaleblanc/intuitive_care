from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass
class Despesa:
    """Representação de domínio de um lançamento de despesa assistencial ANS."""

    id: Optional[int]
    reg_ans: str
    ano: int
    trimestre: int
    valor_despesa: float
    categoria: str = "Despesa Assistencial"
    descricao: Optional[str] = None
    razao_social: Optional[str] = None
    uf: Optional[str] = None
    faixa_porte: Optional[str] = None

    @classmethod
    def from_row(cls, row: Dict[str, Any]) -> "Despesa":
        valor = float(row["valor_despesa"])
        return cls(
            id=row.get("id"),
            reg_ans=str(row["reg_ans"]),
            ano=int(row["ano"]),
            trimestre=int(row["trimestre"]),
            valor_despesa=valor,
            categoria=row.get("categoria") or "Despesa Assistencial",
            descricao=row.get("descricao"),
            razao_social=row.get("razao_social"),
            uf=row.get("uf"),
            faixa_porte=cls.classificar_porte(valor),
        )

    @staticmethod
    def classificar_porte(valor: float) -> str:
        """Classificação de porte financeiro calculada no backend."""
        if valor >= 150_000_000:
            return "Grande Porte"
        if valor >= 50_000_000:
            return "Médio Porte"
        return "Pequeno Porte"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "reg_ans": self.reg_ans,
            "ano": self.ano,
            "trimestre": self.trimestre,
            "valor_despesa": self.valor_despesa,
            "categoria": self.categoria,
            "descricao": self.descricao,
            "razao_social": self.razao_social,
            "uf": self.uf,
            "faixa_porte": self.faixa_porte or self.classificar_porte(self.valor_despesa),
        }
