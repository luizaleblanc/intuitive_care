from flask import Blueprint, g, jsonify, request

from backend.routes.decorators import admin_required, token_required
from backend.services.analitico_service import AnaliticoService
from backend.services.validators import BusinessRuleError

analitico_bp = Blueprint("analitico", __name__, url_prefix="/api")


def _int_arg(nome: str):
    valor = request.args.get(nome)
    if not valor:
        return None
    try:
        return int(valor)
    except ValueError:
        raise BusinessRuleError(f"Parâmetro '{nome}' deve ser numérico.", 400)


@analitico_bp.route("/painel", methods=["GET"])
@token_required
def painel():
    return (
        jsonify(
            AnaliticoService.painel(
                ano=_int_arg("ano"),
                trimestre=_int_arg("trimestre"),
                uf=request.args.get("uf", "").strip().upper(),
                modalidade=request.args.get("modalidade", "").strip(),
            )
        ),
        200,
    )


@analitico_bp.route("/contas", methods=["GET"])
@token_required
def contas():
    return (
        jsonify(
            AnaliticoService.contas(
                ano=_int_arg("ano"),
                trimestre=_int_arg("trimestre"),
                grupo=request.args.get("grupo", "").strip(),
            )
        ),
        200,
    )


@analitico_bp.route("/contas/lotes/<int:ano>/<int:trimestre>/auditar", methods=["POST"])
@token_required
@admin_required
def auditar_lote(ano: int, trimestre: int):
    return jsonify(AnaliticoService.auditar_lote(ano, trimestre, g.current_user.nome)), 200
