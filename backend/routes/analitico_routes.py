from flask import Blueprint, Response, g, jsonify, request

from backend.routes.decorators import get_json_body, permissao_required, token_required
from backend.services.analitico_service import AnaliticoService
from backend.services.explorar_service import ExplorarService
from backend.services.relatorio_service import RelatorioService
from backend.services.validators import BusinessRuleError

analitico_bp = Blueprint("analitico", __name__, url_prefix="/api")


def _int_list_arg(nome: str, alias: str = ""):
    bruto = request.args.get(nome) or (request.args.get(alias) if alias else None)
    if not bruto:
        return []
    itens = [v.strip() for v in bruto.split(",") if v.strip()]
    try:
        return [int(v) for v in itens]
    except ValueError:
        raise BusinessRuleError(f"Parâmetro '{nome}' deve ser numérico.", 400)


@analitico_bp.route("/painel", methods=["GET"])
@token_required
def painel():
    return (
        jsonify(
            AnaliticoService.painel(
                anos=_int_list_arg("anos", "ano"),
                trimestres=_int_list_arg("trimestres", "trimestre"),
                uf=request.args.get("uf", "").strip().upper(),
                modalidade=request.args.get("modalidade", "").strip(),
                escopo=request.args.get("escopo", "").strip().lower(),
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
                anos=_int_list_arg("anos", "ano"),
                trimestres=_int_list_arg("trimestres", "trimestre"),
                grupo=(request.args.get("grupos") or request.args.get("grupo") or "").strip(),
            )
        ),
        200,
    )


@analitico_bp.route("/contas/lotes/<int:ano>/<int:trimestre>/auditar", methods=["POST"])
@token_required
@permissao_required("lotes.auditar")
def auditar_lote(ano: int, trimestre: int):
    return jsonify(AnaliticoService.auditar_lote(ano, trimestre, g.current_user.nome)), 200


@analitico_bp.route("/explorar", methods=["GET"])
@token_required
@permissao_required("painel.ver")
def explorar():
    resultado = ExplorarService.explorar(request.args, ver_inativas=g.current_user.pode("operadoras.ver_inativas"))
    return jsonify(resultado), 200


@analitico_bp.route("/relatorios/exportar", methods=["POST"])
@token_required
@permissao_required("dados.exportar")
def exportar_relatorio():
    payload = get_json_body()
    formato = (payload.get("formato") or "XLSX").strip().upper()
    usuario = g.current_user.nome

    if formato == "XLSX":
        conteudo, nome = RelatorioService.gerar_xlsx(payload, usuario_nome=usuario)
        return Response(
            conteudo,
            status=200,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": f'attachment; filename="{nome}"',
                "Cache-Control": "no-store",
            },
        )

    if formato == "CSV":
        conteudo, nome = RelatorioService.gerar_csv(payload, usuario_nome=usuario)
        return Response(
            conteudo,
            status=200,
            mimetype="text/csv; charset=utf-8",
            headers={
                "Content-Disposition": f'attachment; filename="{nome}"',
                "Cache-Control": "no-store",
            },
        )

    if formato == "JSON":
        limite_raw = payload.get("limite_linhas_brutas", 120)
        try:
            limite_pdf = int(limite_raw) if limite_raw is not None else 120
        except (TypeError, ValueError):
            raise BusinessRuleError("Parâmetro 'limite_linhas_brutas' inválido.", 400)
        return (
            jsonify(
                RelatorioService.gerar_tabelas_estruturadas(
                    payload,
                    usuario_nome=usuario,
                    limite_linhas_brutas=max(1, min(limite_pdf, 500)),
                )
            ),
            200,
        )

    raise BusinessRuleError("Formato inválido. Use XLSX, CSV ou JSON.", 400)
