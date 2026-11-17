from flask import Blueprint, jsonify, request

from backend.routes.decorators import get_json_body, token_required
from backend.services.despesa_service import DespesaService
from backend.services.operadora_service import OperadoraService

operadora_bp = Blueprint("operadoras", __name__, url_prefix="/api/operadoras")


@operadora_bp.route("", methods=["GET"])
@token_required
def list_operadoras():
    try:
        page = int(request.args.get("page", 1))
        limit = int(request.args.get("limit", 10))
    except ValueError:
        return jsonify({"erro": "Parâmetros 'page' e 'limit' devem ser numéricos."}), 400

    search = request.args.get("search", "")
    uf = request.args.get("uf", "")
    return jsonify(OperadoraService.listar(page=page, limit=limit, search=search, uf=uf)), 200


@operadora_bp.route("/<identifier>", methods=["GET"])
@token_required
def get_operadora(identifier: str):
    return jsonify(OperadoraService.obter_por_identificador(identifier)), 200


@operadora_bp.route("/<identifier>/despesas", methods=["GET"])
@token_required
def get_operadora_despesas(identifier: str):
    return jsonify(DespesaService.listar_por_operadora(identifier)), 200


@operadora_bp.route("", methods=["POST"])
@token_required
def create_operadora():
    payload = get_json_body()
    result = OperadoraService.criar(payload)
    return jsonify(result), 201


@operadora_bp.route("/<identifier>", methods=["PUT"])
@token_required
def update_operadora(identifier: str):
    payload = get_json_body()
    result = OperadoraService.atualizar(identifier, payload)
    return jsonify(result), 200


@operadora_bp.route("/<identifier>", methods=["DELETE"])
@token_required
def delete_operadora(identifier: str):
    force = request.args.get("force", "false").lower() == "true"
    result = OperadoraService.excluir(identifier, force=force)
    return jsonify(result), 200
