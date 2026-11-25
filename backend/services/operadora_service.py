from typing import Any, Dict

from backend.database.cache import invalidar_cache
from backend.models.operadora_model import STATUS_VALIDOS, Operadora
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
    def listar(
        page: int = 1,
        limit: int = 10,
        search: str = "",
        uf: str = "",
        modalidade: str = "",
        status: str = "",
        is_admin: bool = False,
    ) -> Dict[str, Any]:
        page = max(1, page)
        limit = min(max(1, limit), 100)
        # Regra do MVP: operadoras inativas só aparecem para o Administrador.
        if not is_admin and status:
            filtrados = [s.strip() for s in status.split(",") if s.strip() and s.strip() != "Inativa"]
            status = ",".join(filtrados) if filtrados else "__nenhum__"
        rows, total = OperadoraRepository.list_paginated(
            page=page,
            limit=limit,
            search=search.strip(),
            uf=uf.strip(),
            modalidade=modalidade.strip(),
            status=status.strip(),
            incluir_inativas=is_admin,
        )
        total_pages = max(1, (total + limit - 1) // limit)
        return {
            "data": [Operadora.from_row(row).to_dict() for row in rows],
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
        }

    @staticmethod
    def resumo(is_admin: bool = False) -> Dict[str, Any]:
        return OperadoraRepository.resumo(incluir_inativas=is_admin)

    @staticmethod
    def exportar_csv(search: str = "", uf: str = "", modalidade: str = "", is_admin: bool = False) -> str:
        import csv
        import io

        rows = OperadoraRepository.list_all(
            search=search.strip(), uf=uf.strip(), modalidade=modalidade.strip(), incluir_inativas=is_admin
        )
        buffer = io.StringIO()
        writer = csv.writer(buffer, delimiter=";")
        writer.writerow(["Registro ANS", "CNPJ", "Razão Social", "Nome Fantasia", "Modalidade", "UF",
                         "Beneficiários", "Despesa do trimestre (R$)", "Status"])
        for r in rows:
            op = Operadora.from_row(r)
            writer.writerow([
                op.registro_ans, op.cnpj, op.razao_social, op.nome_fantasia or "", op.modalidade or "", op.uf,
                op.beneficiarios, f"{(op.despesa_trimestre or 0):.2f}".replace(".", ","), op.status,
            ])
        return "\ufeff" + buffer.getvalue()

    @staticmethod
    def obter_por_identificador(identifier: str, is_admin: bool = True) -> Dict[str, Any]:
        clean = only_digits(identifier) or identifier.strip()
        row = OperadoraRepository.find_by_identifier(clean)
        if not row or (not is_admin and row.get("status") == "Inativa"):
            raise BusinessRuleError("Operadora não encontrada.", 404)
        return Operadora.from_row(row).to_dict()

    @staticmethod
    def alterar_status(identifier: str, status: str) -> Dict[str, Any]:
        if status not in STATUS_VALIDOS:
            raise BusinessRuleError(f"Status inválido. Use: {', '.join(STATUS_VALIDOS)}.", 400)
        clean = only_digits(identifier) or identifier.strip()
        existing = OperadoraRepository.find_by_identifier(clean)
        if not existing:
            raise BusinessRuleError("Operadora não encontrada.", 404)
        from datetime import date

        campos: Dict[str, Any] = {"status": status}
        campos["data_descredenciamento"] = date.today() if status == "Inativa" else None
        updated = OperadoraRepository.update(str(existing["registro_ans"]), campos)
        invalidar_cache("operadoras:", "explorar:", "analitico:")
        verbo = "inativada" if status == "Inativa" else ("reativada" if status == "Ativa" else "colocada em análise")
        return {"mensagem": f"Operadora {verbo} com sucesso.", "data": Operadora.from_row(updated).to_dict()}

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

        if "beneficiarios" in data:
            try:
                benef = int(data.get("beneficiarios") or 0)
            except (TypeError, ValueError):
                raise BusinessRuleError("Beneficiários deve ser um número inteiro.", 400)
            if benef < 0:
                raise BusinessRuleError("Beneficiários não pode ser negativo.", 400)
            payload["beneficiarios"] = benef

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
        invalidar_cache("operadoras:", "explorar:", "analitico:")
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
        invalidar_cache("operadoras:", "explorar:", "analitico:")

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
        invalidar_cache("operadoras:", "explorar:", "analitico:")
        return {"mensagem": "Operadora excluída com sucesso."}
