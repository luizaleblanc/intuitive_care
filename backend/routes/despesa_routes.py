from flask import Blueprint, jsonify, request

from backend.routes.decorators import admin_required, get_json_body, token_required
from backend.services.despesa_service import DespesaService

despesa_bp = Blueprint("despesas", __name__, url_prefix="/api/despesas")


@despesa_bp.route("", methods=["GET"])
@token_required
def list_despesas():
    try:
        page = int(request.args.get("page", 1))
        limit = int(request.args.get("limit", 20))
        ano = int(request.args["ano"]) if request.args.get("ano") else None
        trimestre = int(request.args["trimestre"]) if request.args.get("trimestre") else None
        semestre = int(request.args["semestre"]) if request.args.get("semestre") else None
    except ValueError:
        return jsonify({"erro": "Parâmetros numéricos inválidos na consulta de despesas."}), 400
    if semestre is not None and semestre not in (1, 2):
        return jsonify({"erro": "O semestre deve ser 1 ou 2."}), 400

    reg_ans = request.args.get("reg_ans", "")
    return (
        jsonify(
            DespesaService.listar(
                page=page,
                limit=limit,
                reg_ans=reg_ans,
                ano=ano,
                trimestre=trimestre,
                semestre=semestre,
            )
        ),
        200,
    )


@despesa_bp.route("/anos", methods=["GET"])
@token_required
def list_anos():
    return jsonify({"anos": DespesaService.anos_disponiveis()}), 200


@despesa_bp.route("/<int:despesa_id>", methods=["GET"])
@token_required
def get_despesa(despesa_id: int):
    return jsonify(DespesaService.obter_por_id(despesa_id)), 200


@despesa_bp.route("", methods=["POST"])
@token_required
@admin_required
def create_despesa():
    payload = get_json_body()
    result = DespesaService.criar(payload)
    return jsonify(result), 201


@despesa_bp.route("/<int:despesa_id>", methods=["PUT"])
@token_required
@admin_required
def update_despesa(despesa_id: int):
    payload = get_json_body()
    result = DespesaService.atualizar(despesa_id, payload)
    return jsonify(result), 200


@despesa_bp.route("/<int:despesa_id>", methods=["DELETE"])
@token_required
@admin_required
def delete_despesa(despesa_id: int):
    result = DespesaService.excluir(despesa_id)
    return jsonify(result), 200
