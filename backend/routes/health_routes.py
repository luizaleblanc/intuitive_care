from flask import Blueprint, jsonify

from backend.database.connection import check_database_health

health_bp = Blueprint("health", __name__, url_prefix="/api")


@health_bp.route("/health", methods=["GET"])
def health_check():
    db_ok = check_database_health()
    status_code = 200 if db_ok else 503
    return (
        jsonify(
            {
                "status": "ok" if db_ok else "degraded",
                "servico": "Intuitive Care API (Flask)",
                "banco_dados": "conectado" if db_ok else "indisponivel",
            }
        ),
        status_code,
    )
