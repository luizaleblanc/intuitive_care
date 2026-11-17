from typing import Any, Dict

from backend.models.operadora_model import Operadora
from backend.repositories.operadora_repository import OperadoraRepository
from backend.services.validators import (
    BusinessRuleError,
    only_digits,
    validate_cnpj,
    validate_email,
    validate_registro_ans,
    validate_uf,
)


class OperadoraService:
    """Regras de negócio centralizadas para gestão de operadoras de saúde (ANS)."""

    @staticmethod
    def listar(page: int = 1, limit: int = 10, search: str = "", uf: str = "") -> Dict[str, Any]:
        page = max(1, page)
        limit = min(max(1, limit), 100)
        rows, total = OperadoraRepository.list_paginated(page=page, limit=limit, search=search.strip(), uf=uf.strip())
        total_pages = max(1, (total + limit - 1) // limit)
        return {
            "data": [Operadora.from_row(row).to_dict() for row in rows],
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
        }

    @staticmethod
    def obter_por_identificador(identifier: str) -> Dict[str, Any]:
        clean = only_digits(identifier) or identifier.strip()
        row = OperadoraRepository.find_by_identifier(clean)
        if not row:
            raise BusinessRuleError("Operadora não encontrada.", 404)
        return Operadora.from_row(row).to_dict()

    @staticmethod
    def _sanitize_payload(data: Dict[str, Any], is_create: bool = True) -> Dict[str, Any]:
        payload: Dict[str, Any] = {}

        if is_create or "registro_ans" in data:
            payload["registro_ans"] = validate_registro_ans(data.get("registro_ans"))

        if is_create or "cnpj" in data:
            payload["cnpj"] = validate_cnpj(data.get("cnpj"))

        if is_create or "razao_social" in data:
            razao = (data.get("razao_social") or "").strip()
            if len(razao) < 3:
                raise BusinessRuleError("A Razão Social deve conter pelo menos 3 caracteres.", 400)
            payload["razao_social"] = razao.upper()

        if is_create or "uf" in data:
            payload["uf"] = validate_uf(data.get("uf"))

        if "email" in data and data.get("email"):
            payload["email"] = validate_email(data.get("email"))
        elif is_create:
            payload["email"] = None
        elif "email" in data:
            payload["email"] = None

        optional_fields = [
            "nome_fantasia",
            "modalidade",
            "logradouro",
            "numero",
            "complemento",
            "bairro",
            "cidade",
            "cep",
            "telefone",
            "representante",
            "cargo_representante",
        ]
        for field in optional_fields:
            if field in data:
                val = data.get(field)
                payload[field] = val.strip() if isinstance(val, str) and val.strip() else None
            elif is_create:
                payload[field] = None

        return payload

    @classmethod
    def criar(cls, data: Dict[str, Any]) -> Dict[str, Any]:
        payload = cls._sanitize_payload(data, is_create=True)

        if OperadoraRepository.find_by_identifier(payload["registro_ans"]):
            raise BusinessRuleError(
                f"Já existe uma operadora cadastrada com o Registro ANS {payload['registro_ans']}.",
                409,
            )
        if OperadoraRepository.find_by_cnpj(payload["cnpj"]):
            raise BusinessRuleError(
                f"Já existe uma operadora cadastrada com o CNPJ {payload['cnpj']}.",
                409,
            )

        created = OperadoraRepository.create(payload)
        return {
            "mensagem": "Operadora cadastrada com sucesso.",
            "data": Operadora.from_row(created).to_dict(),
        }

    @classmethod
    def atualizar(cls, identifier: str, data: Dict[str, Any]) -> Dict[str, Any]:
        clean = only_digits(identifier) or identifier.strip()
        existing = OperadoraRepository.find_by_identifier(clean)
        if not existing:
            raise BusinessRuleError("Operadora não encontrada para atualização.", 404)

        registro_ans = str(existing["registro_ans"])
        payload = cls._sanitize_payload(data, is_create=False)
        payload.pop("registro_ans", None)

        if "cnpj" in payload and payload["cnpj"] != existing["cnpj"]:
            cnpj_owner = OperadoraRepository.find_by_cnpj(payload["cnpj"])
            if cnpj_owner and str(cnpj_owner["registro_ans"]) != registro_ans:
                raise BusinessRuleError("O CNPJ informado já pertence a outra operadora.", 409)

        updated = OperadoraRepository.update(registro_ans, payload)
        if not updated:
            raise BusinessRuleError("Operadora não encontrada.", 404)

        return {
            "mensagem": "Operadora atualizada com sucesso.",
            "data": Operadora.from_row(updated).to_dict(),
        }

    @staticmethod
    def excluir(identifier: str, force: bool = False) -> Dict[str, Any]:
        clean = only_digits(identifier) or identifier.strip()
        existing = OperadoraRepository.find_by_identifier(clean)
        if not existing:
            raise BusinessRuleError("Operadora não encontrada para exclusão.", 404)

        registro_ans = str(existing["registro_ans"])
        linked_count = OperadoraRepository.count_linked_despesas(registro_ans)
        if linked_count > 0 and not force:
            raise BusinessRuleError(
                f"Não é possível excluir a operadora {registro_ans}: existem {linked_count} despesa(s) vinculada(s). "
                "Exclua as despesas antes ou confirme a exclusão em cascata.",
                409,
                details={"despesas_vinculadas": linked_count},
            )

        OperadoraRepository.delete(registro_ans, cascade_despesas=force)
        return {"mensagem": "Operadora excluída com sucesso."}
