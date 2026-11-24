"""Validação e normalização dos parâmetros recebidos pelo endpoint de exportação."""
from typing import Any, Dict, Optional

from backend.repositories.relatorio_repository import RelatorioRepository
from backend.services.explorar_service import CONSOLIDACOES, FAIXAS_DESPESA, GRANULARIDADES, PORTES, STATUS
from backend.services.relatorio.constantes import FORMATOS_VALIDOS, ORDENS_VALIDAS, SECOES_PADRAO, SECOES_VALIDAS
from backend.services.relatorio.formatadores import norm_lista_int, norm_lista_str
from backend.services.validators import BusinessRuleError, VALID_UFS


def parse_params(payload: Dict[str, Any]) -> Dict[str, Any]:
    anos_disp = RelatorioRepository.anos_disponiveis()
    if not anos_disp:
        raise BusinessRuleError("Ainda não há demonstrações carregadas. Execute o ETL.", 404)

    anos = norm_lista_int(payload.get("anos"), "anos")
    if not anos:
        anos = [anos_disp[-1]]
    elif any(a not in anos_disp for a in anos):
        raise BusinessRuleError("Há ano selecionado sem dados carregados no ETL.", 400)

    trimestres = norm_lista_int(payload.get("trimestres"), "trimestres")
    if any(t not in (1, 2, 3, 4) for t in trimestres):
        raise BusinessRuleError("Trimestre inválido. Use valores entre 1 e 4.", 400)

    granularidade = (payload.get("granularidade") or "ano").strip().lower()
    if granularidade not in GRANULARIDADES:
        raise BusinessRuleError("Granularidade inválida. Use 'ano' ou 'trimestre'.", 400)

    ufs = [u.upper() for u in norm_lista_str(payload.get("ufs") or payload.get("uf"))]
    if any(u not in VALID_UFS for u in ufs):
        raise BusinessRuleError("UF inválida no filtro do relatório.", 400)

    modalidades = norm_lista_str(payload.get("modalidades") or payload.get("modalidade"))
    statuses = norm_lista_str(payload.get("statuses") or payload.get("status"))
    portes = norm_lista_str(payload.get("portes") or payload.get("porte"))
    faixas = norm_lista_str(payload.get("faixas") or payload.get("faixa_despesa"))
    consolidacoes = norm_lista_str(payload.get("consolidacoes") or payload.get("consolidacao"))

    for valores, validos, nome in (
        (statuses, STATUS[1:], "status"),
        (portes, PORTES, "porte"),
        (faixas, FAIXAS_DESPESA, "faixa_despesa"),
        (consolidacoes, CONSOLIDACOES[1:], "consolidacao"),
    ):
        if any(v not in validos for v in valores):
            raise BusinessRuleError(f"Valor inválido para '{nome}'.", 400)
    consolidacao = consolidacoes[0] if len(consolidacoes) == 1 else ""

    secoes = norm_lista_str(payload.get("secoes")) or list(SECOES_PADRAO)
    if any(s not in SECOES_VALIDAS for s in secoes):
        raise BusinessRuleError("Seção de relatório inválida.", 400)
    # Mantém ordem canônica das abas
    secoes = [s for s in SECOES_VALIDAS if s in secoes]

    ordenar_por = (payload.get("ordenar_por") or "despesas").strip().lower()
    if ordenar_por not in ORDENS_VALIDAS:
        raise BusinessRuleError("Critério de ordenação inválido.", 400)

    limite_raw = payload.get("limite_operadoras")
    limite: Optional[int] = None
    if limite_raw not in (None, "", 0, "0"):
        try:
            limite = int(limite_raw)
            if limite <= 0:
                limite = None
        except (TypeError, ValueError):
            raise BusinessRuleError("Parâmetro 'limite_operadoras' inválido.", 400)

    formato = (payload.get("formato") or "XLSX").strip().upper()
    if formato not in FORMATOS_VALIDOS:
        raise BusinessRuleError("Formato inválido. Use XLSX, CSV ou JSON.", 400)

    formato_data = (payload.get("formato_data") or "DD/MM/AAAA").strip()
    if formato_data not in ("DD/MM/AAAA", "AAAA-MM-DD"):
        formato_data = "DD/MM/AAAA"

    return {
        "anos": anos,
        "trimestres": trimestres,
        "granularidade": granularidade,
        "ufs": ufs,
        "modalidades": modalidades,
        "statuses": statuses,
        "portes": portes,
        "faixas": faixas,
        "consolidacao": consolidacao,
        "secoes": secoes,
        "ordenar_por": ordenar_por,
        "limite_operadoras": limite,
        "formato": formato,
        "formato_data": formato_data,
    }
