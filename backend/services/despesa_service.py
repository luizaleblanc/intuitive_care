from typing import Any, Dict, List, Optional

from backend.models.despesa_model import Despesa
from backend.repositories.despesa_repository import DespesaRepository
from backend.repositories.operadora_repository import OperadoraRepository
from backend.services.validators import (
    BusinessRuleError,
    only_digits,
    validate_ano,
    validate_registro_ans,
    validate_trimestre,
    validate_valor_despesa,
)


class DespesaService:
    """Regras de negócio centralizadas para lançamentos de despesas assistenciais."""

    @staticmethod
    def anos_disponiveis():
        return DespesaRepository.anos_disponiveis()

    @staticmethod
    def listar(
        page: int = 1,
        limit: int = 20,
        reg_ans: str = "",
        ano: Optional[int] = None,
        trimestre: Optional[int] = None,
        semestre: Optional[int] = None,
    ) -> Dict[str, Any]:
        page = max(1, page)
        limit = min(max(1, limit), 100)
        clean_reg = only_digits(reg_ans) if reg_ans else ""

        rows, total = DespesaRepository.list_paginated(
            page=page,
            limit=limit,
            reg_ans=clean_reg,
            ano=ano,
            trimestre=trimestre,
            semestre=semestre,
        )
        total_pages = max(1, (total + limit - 1) // limit)
        return {
            "data": [Despesa.from_row(row).to_dict() for row in rows],
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
        }

    @staticmethod
    def listar_por_operadora(identifier: str) -> List[Dict[str, Any]]:
        clean = only_digits(identifier) or identifier.strip()
        op = OperadoraRepository.find_by_identifier(clean)
        if not op:
            raise BusinessRuleError("Operadora não encontrada.", 404)
        rows = DespesaRepository.list_by_operadora(str(op["registro_ans"]))
        return [Despesa.from_row(row).to_dict() for row in rows]

    @staticmethod
    def obter_por_id(despesa_id: int) -> Dict[str, Any]:
        row = DespesaRepository.find_by_id(despesa_id)
        if not row:
            raise BusinessRuleError("Lançamento de despesa não encontrado.", 404)
        return Despesa.from_row(row).to_dict()

    @staticmethod
    def criar(data: Dict[str, Any]) -> Dict[str, Any]:
        reg_ans = validate_registro_ans(data.get("reg_ans") or data.get("registro_ans"))
        op = OperadoraRepository.find_by_identifier(reg_ans)
        if not op:
            raise BusinessRuleError(
                f"Operadora com Registro ANS {reg_ans} não encontrada. Cadastre a operadora primeiro.",
                404,
            )

        ano = validate_ano(data.get("ano"))
        trimestre = validate_trimestre(data.get("trimestre"))
        valor = validate_valor_despesa(data.get("valor_despesa"))
        categoria = (data.get("categoria") or "Despesa Assistencial").strip() or "Despesa Assistencial"
        descricao = (data.get("descricao") or "").strip() or None

        created = DespesaRepository.create(
            {
                "reg_ans": str(op["registro_ans"]),
                "ano": ano,
                "trimestre": trimestre,
                "valor_despesa": valor,
                "categoria": categoria,
                "descricao": descricao,
            }
        )
        return {
            "mensagem": "Despesa lançada com sucesso.",
            "data": Despesa.from_row(created).to_dict(),
        }

    @staticmethod
    def atualizar(despesa_id: int, data: Dict[str, Any]) -> Dict[str, Any]:
        existing = DespesaRepository.find_by_id(despesa_id)
        if not existing:
            raise BusinessRuleError("Despesa não encontrada para atualização.", 404)

        payload: Dict[str, Any] = {}
        if "reg_ans" in data or "registro_ans" in data:
            reg_ans = validate_registro_ans(data.get("reg_ans") or data.get("registro_ans"))
            op = OperadoraRepository.find_by_identifier(reg_ans)
            if not op:
                raise BusinessRuleError(f"Operadora {reg_ans} não encontrada.", 404)
            payload["reg_ans"] = str(op["registro_ans"])

        if "ano" in data:
            payload["ano"] = validate_ano(data.get("ano"))
        if "trimestre" in data:
            payload["trimestre"] = validate_trimestre(data.get("trimestre"))
        if "valor_despesa" in data:
            payload["valor_despesa"] = validate_valor_despesa(data.get("valor_despesa"))
        if "categoria" in data:
            payload["categoria"] = (data.get("categoria") or "Despesa Assistencial").strip() or "Despesa Assistencial"
        if "descricao" in data:
            desc = data.get("descricao")
            payload["descricao"] = desc.strip() if isinstance(desc, str) and desc.strip() else None

        updated = DespesaRepository.update(despesa_id, payload)
        if not updated:
            raise BusinessRuleError("Despesa não encontrada.", 404)

        return {
            "mensagem": "Despesa atualizada com sucesso.",
            "data": Despesa.from_row(updated).to_dict(),
        }

    @staticmethod
    def excluir(despesa_id: int) -> Dict[str, Any]:
        deleted = DespesaRepository.delete(despesa_id)
        if not deleted:
            raise BusinessRuleError("Despesa não encontrada para exclusão.", 404)
        return {"mensagem": "Despesa excluída com sucesso."}
