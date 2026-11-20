from flask import Flask, jsonify
from flask_cors import CORS

from backend.config import Config
from backend.database.init_db import initialize_database
from backend.routes.analitico_routes import analitico_bp
from backend.routes.auth_routes import auth_bp
from backend.routes.despesa_routes import despesa_bp
from backend.routes.estatistica_routes import estatistica_bp
from backend.routes.health_routes import health_bp
from backend.routes.operadora_routes import operadora_bp
from backend.services.validators import BusinessRuleError


def create_app(init_db: bool = True, seed_db: bool = True) -> Flask:
    """Application Factory da API REST Flask do Intuitive Care."""
    app = Flask(__name__)
    app.config["JSON_SORT_KEYS"] = False
    CORS(app, resources={r"/api/*": {"origins": "*"}}, expose_headers=["Content-Disposition"])

    app.register_blueprint(health_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(operadora_bp)
    app.register_blueprint(despesa_bp)
    app.register_blueprint(estatistica_bp)
    app.register_blueprint(analitico_bp)

    @app.errorhandler(BusinessRuleError)
    def handle_business_error(err: BusinessRuleError):
        body = {"erro": err.message}
        if err.details:
            body["detalhes"] = err.details
        return jsonify(body), err.status_code

    @app.errorhandler(404)
    def handle_not_found(_err):
        return jsonify({"erro": "Recurso ou rota não encontrada na API."}), 404

    @app.errorhandler(405)
    def handle_method_not_allowed(_err):
        return jsonify({"erro": "Método HTTP não permitido para esta rota."}), 405

    @app.errorhandler(Exception)
    def handle_unexpected_error(err: Exception):
        if Config.APP_ENV == "production":
            print(f"[ERRO] {type(err).__name__}", flush=True)
            return jsonify({"erro": "Erro interno do servidor."}), 500
        return jsonify({"erro": f"Erro interno do servidor: {str(err)}"}), 500

    if init_db:
        try:
            initialize_database(seed=seed_db)
        except Exception as exc:
            print(f"[AVISO] Inicialização automática do banco adiada: {exc}")

    return app


if __name__ == "__main__":
    application = create_app(init_db=True, seed_db=True)
    application.run(debug=Config.DEBUG, host="0.0.0.0", port=5000)
