from flask import Blueprint, Response, g, jsonify, request

from backend.routes.decorators import permissao_required, get_json_body, token_required
from backend.services.despesa_service import DespesaService
from backend.services.operadora_service import OperadoraService

operadora_bp = Blueprint("operadoras", __name__, url_prefix="/api/operadoras")


def _is_admin() -> bool:
    """Só quem pode ver inativas recebe a visão completa da base de operadoras."""
    return g.current_user.pode("operadoras.ver_inativas")


@operadora_bp.route("", methods=["GET"])
@token_required
def list_operadoras():
    try:
        page = int(request.args.get("page", 1))
        limit = int(request.args.get("limit", 10))
    except ValueError:
        return jsonify({"erro": "Parâmetros 'page' e 'limit' devem ser numéricos."}), 400

    return (
        jsonify(
            OperadoraService.listar(
                page=page,
                limit=limit,
                search=request.args.get("search", ""),
                uf=request.args.get("uf", ""),
                modalidade=request.args.get("modalidade", ""),
                status=request.args.get("status", ""),
                is_admin=_is_admin(),
            )
        ),
        200,
    )


@operadora_bp.route("/resumo", methods=["GET"])
@token_required
def resumo_operadoras():
    return jsonify(OperadoraService.resumo(is_admin=_is_admin())), 200


@operadora_bp.route("/exportar.csv", methods=["GET"])
@token_required
@permissao_required("dados.exportar")
def exportar_operadoras():
    conteudo = OperadoraService.exportar_csv(
        search=request.args.get("search", ""),
        uf=request.args.get("uf", ""),
        modalidade=request.args.get("modalidade", ""),
        is_admin=_is_admin(),
    )
    return Response(
        conteudo,
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=operadoras_ans.csv"},
    )


@operadora_bp.route("/<identifier>", methods=["GET"])
@token_required
def get_operadora(identifier: str):
    return jsonify(OperadoraService.obter_por_identificador(identifier, is_admin=_is_admin())), 200


@operadora_bp.route("/<identifier>/despesas", methods=["GET"])
@token_required
def get_operadora_despesas(identifier: str):
    OperadoraService.obter_por_identificador(identifier, is_admin=_is_admin())
    return jsonify(DespesaService.listar_por_operadora(identifier)), 200


@operadora_bp.route("", methods=["POST"])
@token_required
@permissao_required("operadoras.criar")
def create_operadora():
    result = OperadoraService.criar(get_json_body())
    return jsonify(result), 201


@operadora_bp.route("/<identifier>", methods=["PUT"])
@token_required
@permissao_required("operadoras.editar")
def update_operadora(identifier: str):
    result = OperadoraService.atualizar(identifier, get_json_body())
    return jsonify(result), 200


@operadora_bp.route("/<identifier>/status", methods=["PATCH"])
@token_required
@permissao_required("operadoras.alterar_status")
def update_status_operadora(identifier: str):
    payload = get_json_body()
    return jsonify(OperadoraService.alterar_status(identifier, (payload.get("status") or "").strip())), 200


@operadora_bp.route("/<identifier>", methods=["DELETE"])
@token_required
@permissao_required("operadoras.excluir")
def delete_operadora(identifier: str):
    force = request.args.get("force", "false").lower() == "true"
    result = OperadoraService.excluir(identifier, force=force)
    return jsonify(result), 200
