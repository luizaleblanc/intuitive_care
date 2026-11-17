from flask import Blueprint, jsonify

from backend.routes.decorators import token_required
from backend.services.estatistica_service import EstatisticaService

estatistica_bp = Blueprint("estatisticas", __name__, url_prefix="/api/estatisticas")


@estatistica_bp.route("", methods=["GET"])
@token_required
def get_estatisticas():
    return jsonify(EstatisticaService.obter_dashboard()), 200
