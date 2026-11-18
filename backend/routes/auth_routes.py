from flask import Blueprint, g, jsonify

from backend.routes.decorators import get_json_body, token_required
from backend.services.auth_service import AuthService

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@auth_bp.route("/register", methods=["POST"])
def register():
    payload = get_json_body()
    result = AuthService.register(payload)
    return jsonify(result), 201


@auth_bp.route("/login", methods=["POST"])
def login():
    payload = get_json_body()
    result = AuthService.login(payload)
    return jsonify(result), 200


@auth_bp.route("/me", methods=["GET"])
@token_required
def me():
    return jsonify({"usuario": g.current_user.to_dict()}), 200


@auth_bp.route("/me", methods=["PUT"])
@token_required
def update_me():
    payload = get_json_body()
    result = AuthService.update_profile(g.current_user.id, payload)
    return jsonify(result), 200


@auth_bp.route("/logout", methods=["POST"])
@token_required
def logout():
    result = AuthService.logout(g.current_jti)
    return jsonify(result), 200


@auth_bp.route("/esqueci-senha", methods=["POST"])
def esqueci_senha():
    payload = get_json_body()
    result = AuthService.esqueci_senha(payload)
    return jsonify(result), 200


@auth_bp.route("/redefinir-senha", methods=["POST"])
def redefinir_senha():
    payload = get_json_body()
    result = AuthService.redefinir_senha(payload)
    return jsonify(result), 200
