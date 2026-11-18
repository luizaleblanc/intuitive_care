from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

from backend.repositories.analitico_repository import AnaliticoRepository
from backend.services.validators import BusinessRuleError

Periodo = Tuple[int, int]

GRUPOS_CONTAS = {
    "41": "Eventos indenizáveis",
    "43": "Despesas de comercialização",
    "46": "Despesas administrativas",
    "31": "Receitas de contraprestações",
}

FORMAS_PAGAMENTO = {
    "41111": "Por procedimento",
    "41121": "Capitation",
    "41131": "Orçamento global",
    "41141": "Pacote",
    "41151": "Rateio de recursos próprios",
    "41161": "Rede indireta",
    "41171": "Reembolso",
    "41181": "Sistema Único de Saúde (SUS)",
    "41191": "Outras formas",
}


def _p(periodo: Periodo) -> Dict[str, int]:
    return {"ano": periodo[0], "trimestre": periodo[1]}


def _anterior(periodo: Periodo) -> Periodo:
    ano, tri = periodo
    return (ano, tri - 1) if tri > 1 else (ano - 1, 4)


def _iso(valor: Any) -> Optional[str]:
    if isinstance(valor, (date, datetime)):
        return valor.isoformat()
    return str(valor) if valor else None


def _resolver_periodo(ano: Optional[int], trimestre: Optional[int]) -> Tuple[Periodo, List[Periodo]]:
    periodos = AnaliticoRepository.periodos()
    if not periodos:
        raise BusinessRuleError("Nenhuma demonstração contábil carregada. Execute o ETL.", 404)
    if ano is None and trimestre is None:
        return periodos[0], periodos
    candidatos = [p for p in periodos if (ano is None or p[0] == ano) and (trimestre is None or p[1] == trimestre)]
    if not candidatos:
        raise BusinessRuleError("Não há dados da ANS para o período selecionado.", 404)
    return candidatos[0], periodos


class AnaliticoService:
    """Indicadores do Painel e do plano de contas calculados a partir dos dados reais da ANS."""

    @staticmethod
    def painel(ano: Optional[int], trimestre: Optional[int], uf: str = "", modalidade: str = "") -> Dict[str, Any]:
        periodo, periodos = _resolver_periodo(ano, trimestre)
        anterior = _anterior(periodo)
        repo = AnaliticoRepository

        # ---------------- visão Administrador (setor inteiro)
        atual = repo.totais_periodo(periodo)
        ant = repo.totais_periodo(anterior)
        lote = repo.lote(periodo) or {}
        lote_ant = repo.lote(anterior) or {}
        modalidades = repo.por_modalidade(periodo)
        total_mod = sum(m["valor"] for m in modalidades) or 1
        admin = {
            "total_despesas": atual["eventos"],
            "total_despesas_anterior": ant["eventos"] or None,
            "registros_extraidos": int(lote.get("registros_extraidos") or 0),
            "registros_extraidos_anterior": int(lote_ant.get("registros_extraidos") or 0) or None,
            "operadoras_ativas": repo.operadoras_ativas(),
            "operadoras_com_demonstracao": int(atual["operadoras"]),
            "serie": repo.serie("eventos", ate=periodo),
            "modalidades": [
                {**m, "pct": round(m["valor"] / total_mod * 100, 1)} for m in modalidades
            ],
        }

        # ---------------- visão Colaborador (filtros UF / modalidade)
        c_atual = repo.totais_periodo(periodo, uf, modalidade)
        c_ant = repo.totais_periodo(anterior, uf, modalidade)
        sin = repo.sinistralidade_media(periodo, uf, modalidade)
        sin_ant = repo.sinistralidade_media(anterior, uf, modalidade)
        base_benef = repo.beneficiarios_com_despesa(periodo, uf, modalidade)
        base_benef_ant = repo.beneficiarios_com_despesa(anterior, uf, modalidade)
        colaborador = {
            "despesas_mh": c_atual["eventos_mh"],
            "despesas_mh_anterior": c_ant["eventos_mh"] or None,
            "sinistralidade": sin,
            "sinistralidade_anterior": sin_ant,
            "beneficiarios": repo.beneficiarios(periodo, uf, modalidade),
            "beneficiarios_anterior": repo.beneficiarios(anterior, uf, modalidade) or None,
            "ticket_medio": (c_atual["eventos_mh"] / base_benef) if base_benef else None,
            "ticket_medio_anterior": (c_ant["eventos_mh"] / base_benef_ant) if base_benef_ant else None,
            "ranking": repo.ranking(periodo, uf, modalidade),
            "serie": repo.serie("eventos_mh", ate=periodo, uf=uf, modalidade=modalidade),
        }

        return {
            "periodo": _p(periodo),
            "periodo_anterior": _p(anterior),
            "periodos": [_p(p) for p in periodos],
            "admin": admin,
            "colaborador": colaborador,
        }

    @staticmethod
    def contas(ano: Optional[int], trimestre: Optional[int], grupo: str = "") -> Dict[str, Any]:
        periodo, periodos = _resolver_periodo(ano, trimestre)
        anterior = _anterior(periodo)
        if grupo and grupo not in GRUPOS_CONTAS:
            raise BusinessRuleError("Grupo de contas inválido.", 400)
        prefixos = [grupo] if grupo else list(GRUPOS_CONTAS)

        repo = AnaliticoRepository
        atuais = repo.contas(periodo, prefixos)
        anteriores = repo.contas(anterior, prefixos)

        linhas = []
        for codigo, conta in atuais.items():
            ant = anteriores.get(codigo)
            linhas.append(
                {
                    "codigo": codigo,
                    "descricao": conta["descricao"],
                    "grupo": GRUPOS_CONTAS[codigo[:2]],
                    "nivel": int(conta["nivel"]),
                    "valor_atual": conta["valor"],
                    "valor_anterior": ant["valor"] if ant else None,
                }
            )

        kpi_atual = repo.contas(periodo, ["41", "43", "46"], max_nivel=0)
        kpi_ant = repo.contas(anterior, ["41", "43", "46"], max_nivel=0)
        kpis = {
            c: {
                "valor_atual": kpi_atual.get(c, {}).get("valor", 0.0),
                "valor_anterior": kpi_ant.get(c, {}).get("valor") if c in kpi_ant else None,
            }
            for c in ("41", "46", "43")
        }

        comp = repo.composicao_mh(periodo)
        total_comp = sum(v for v in comp.values() if v > 0) or 1
        composicao = sorted(
            (
                {"codigo": c, "forma": FORMAS_PAGAMENTO[c], "valor": v, "pct": round(v / total_comp * 100, 1)}
                for c, v in comp.items()
                if v > 0
            ),
            key=lambda x: -x["valor"],
        )

        destaques = []
        variaveis = [
            l for l in linhas
            if l["nivel"] <= 2 and l["valor_anterior"] and abs(l["valor_anterior"]) > 1e8
        ]
        variaveis.sort(key=lambda l: -abs((l["valor_atual"] - l["valor_anterior"]) / abs(l["valor_anterior"])))
        for l in variaveis:
            # Evita repetir conta-pai e subconta com o mesmo movimento (ex.: 312 e 3121).
            if any(l["codigo"].startswith(d["codigo"]) or d["codigo"].startswith(l["codigo"]) for d in destaques):
                continue
            var = (l["valor_atual"] - l["valor_anterior"]) / abs(l["valor_anterior"]) * 100
            destaques.append({"codigo": l["codigo"], "descricao": l["descricao"], "variacao": round(var, 1)})
            if len(destaques) == 3:
                break

        lote = repo.lote(periodo) or {}
        return {
            "periodo": _p(periodo),
            "periodo_anterior": _p(anterior),
            "periodos": [_p(p) for p in periodos],
            "grupos": [{"codigo": k, "nome": v} for k, v in GRUPOS_CONTAS.items()],
            "kpis": kpis,
            "contas": linhas,
            "composicao": composicao,
            "destaques": destaques,
            "lote": {
                "registros_extraidos": int(lote.get("registros_extraidos") or 0),
                "operadoras": int(lote.get("operadoras") or 0),
                "carregado_em": _iso(lote.get("carregado_em")),
                "auditado": bool(lote.get("auditado")),
                "auditado_por": lote.get("auditado_por"),
                "auditado_em": _iso(lote.get("auditado_em")),
            },
        }

    @staticmethod
    def auditar_lote(ano: int, trimestre: int, usuario: str) -> Dict[str, Any]:
        if not AnaliticoRepository.auditar_lote((ano, trimestre), usuario):
            raise BusinessRuleError("Lote não encontrado para o período informado.", 404)
        return {"mensagem": f"Lote do {trimestre}º trimestre de {ano} marcado como auditado."}
