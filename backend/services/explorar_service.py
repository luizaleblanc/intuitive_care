"""Exploração analítica: período por anos, filtros por facetas reais e séries por métrica.

Métricas
- despesas: eventos indenizáveis líquidos (conta 41)
- receitas: contraprestações efetivas (conta 311)
- sinistralidade: despesas / receitas do conjunto (não é média de razões)
- beneficiarios: beneficiários médico-hospitalares no último trimestre do recorte
"""
from collections import defaultdict
from typing import Any, Dict, List, Optional, Tuple

from backend.repositories.explorar_repository import ExplorarRepository
from backend.services.validators import BusinessRuleError, VALID_UFS

PORTES = {
    # Classificação de porte da ANS por número de beneficiários.
    "pequeno": (0, 20_000),
    "medio": (20_000, 100_000),
    "grande": (100_000, None),
}
FAIXAS_DESPESA = {
    "ate_10mi": (0, 10e6),
    "10mi_100mi": (10e6, 100e6),
    "100mi_1bi": (100e6, 1e9),
    "acima_1bi": (1e9, None),
}
CONSOLIDACOES = ("", "consolidado", "pendente")
STATUS = ("", "Ativa", "Inativa")
GRANULARIDADES = ("ano", "trimestre")
LIMITE_LISTA = 2000


def _na_faixa(valor: float, faixa: Tuple[float, Optional[float]]) -> bool:
    minimo, maximo = faixa
    return valor >= minimo and (maximo is None or valor < maximo)


def _sin(despesas: float, receitas: float) -> Optional[float]:
    return round(despesas / receitas * 100, 2) if receitas > 0 else None


def _lista(valor: Optional[str]) -> List[str]:
    return [v.strip() for v in (valor or "").split(",") if v.strip()]


class ExplorarService:
    @staticmethod
    def explorar(args: Dict[str, Any], ver_inativas: bool) -> Dict[str, Any]:
        anos = ExplorarRepository.anos_disponiveis()
        if not anos:
            raise BusinessRuleError("Ainda não há demonstrações carregadas. Rode o ETL.", 404)

        def ano_arg(nome: str, padrao: int) -> int:
            valor = args.get(nome)
            if not valor:
                return padrao
            try:
                return int(valor)
            except (TypeError, ValueError):
                raise BusinessRuleError(f"Parâmetro '{nome}' deve ser um ano.", 400)

        especificos = _lista(args.get("anos"))
        if especificos:
            try:
                selecionados = sorted({int(a) for a in especificos})
            except ValueError:
                raise BusinessRuleError("Parâmetro 'anos' deve conter anos separados por vírgula.", 400)
            if any(a not in anos for a in selecionados):
                raise BusinessRuleError("Há ano selecionado sem dados carregados.", 400)
        else:
            ano_fim = ano_arg("ano_fim", anos[-1])
            ano_inicio = ano_arg("ano_inicio", ano_fim)
            if ano_inicio > ano_fim:
                raise BusinessRuleError("O ano inicial não pode ser maior que o final.", 400)
            selecionados = list(range(ano_inicio, ano_fim + 1))
        ano_inicio, ano_fim = selecionados[0], selecionados[-1]

        trimestres_raw = _lista(args.get("trimestres") or args.get("trimestre"))
        trimestres_sel: List[int] = []
        if trimestres_raw:
            try:
                trimestres_sel = sorted({int(t) for t in trimestres_raw})
            except ValueError:
                raise BusinessRuleError("Parâmetro 'trimestres' deve conter valores entre 1 e 4.", 400)
            if any(t not in (1, 2, 3, 4) for t in trimestres_sel):
                raise BusinessRuleError("Trimestre inválido. Use valores entre 1 e 4.", 400)

        granularidade = args.get("granularidade") or "trimestre"
        statuses = _lista(args.get("status"))
        portes = _lista(args.get("porte"))
        faixas = _lista(args.get("faixa_despesa"))
        consolidacoes = _lista(args.get("consolidacao"))
        ufs = [u.upper() for u in _lista(args.get("uf"))]
        modalidades = _lista(args.get("modalidade"))
        for valores, validos, nome in (
            ([granularidade], GRANULARIDADES, "granularidade"),
            (statuses, STATUS[1:], "status"),
            (portes, PORTES, "porte"),
            (faixas, FAIXAS_DESPESA, "faixa_despesa"),
            (consolidacoes, CONSOLIDACOES[1:], "consolidacao"),
        ):
            if any(v not in validos for v in valores):
                raise BusinessRuleError(f"Valor inválido para '{nome}'.", 400)
        # Marcar todas as opções de consolidação equivale a não filtrar.
        consolidacao = consolidacoes[0] if len(consolidacoes) == 1 else ""
        if any(u not in VALID_UFS for u in ufs):
            raise BusinessRuleError("UF inválida no filtro.", 400)
        if not ver_inativas:
            statuses = ["Ativa"]  # Regra de perfil: só quem tem operadoras.ver_inativas vê inativas.

        comparar = str(args.get("comparar", "")).lower() in ("1", "true", "sim")
        filtros = dict(ufs=ufs, modalidades=modalidades, status=statuses, consolidacao=consolidacao,
                       portes=portes, faixas=faixas, trimestres=trimestres_sel)
        atual = ExplorarService._calcular(selecionados, granularidade, filtros)

        anterior = None
        if comparar:
            # Mesmo desenho de anos, deslocado pela amplitude da seleção (ex.: 2025+2026 -> 2023+2024).
            n = ano_fim - ano_inicio + 1
            anteriores = [a - n for a in selecionados]
            if all(a in anos for a in anteriores):
                calculado = ExplorarService._calcular(anteriores, granularidade, filtros)
                anterior = {"anos": anteriores, "ano_inicio": anteriores[0], "ano_fim": anteriores[-1],
                            "kpis": calculado["kpis"], "serie": calculado["serie"]}
            else:
                anterior = {"anos": anteriores, "ano_inicio": anteriores[0], "ano_fim": anteriores[-1], "kpis": None,
                            "serie": [], "aviso": "Não há dados para o período anterior equivalente."}

        trimestres = ExplorarRepository.trimestres_por_ano()
        return {
            "periodo": {"ano_inicio": ano_inicio, "ano_fim": ano_fim, "anos": selecionados,
                        "trimestres": trimestres_sel, "granularidade": granularidade},
            "anos_disponiveis": anos,
            "anos_parciais": [a for a in anos if trimestres.get(a, 0) < 4],
            "facetas": {
                **ExplorarRepository.facetas(),
                "portes": list(PORTES),
                "faixas_despesa": list(FAIXAS_DESPESA),
                "consolidacao": ["consolidado", "pendente"],
                "status": ["Ativa", "Inativa"] if ver_inativas else ["Ativa"],
            },
            **atual,
            "comparativo": anterior,
        }

    @staticmethod
    def _calcular(anos: List[int], granularidade: str, f: Dict[str, Any]) -> Dict[str, Any]:
        linhas = ExplorarRepository.linhas(
            anos, f["ufs"], f["modalidades"], f["status"], f["consolidacao"], f.get("trimestres", ())
        )

        if f["portes"]:
            limites = [PORTES[p] for p in f["portes"]]
            linhas = [r for r in linhas
                      if r["beneficiarios"] and any(_na_faixa(float(r["beneficiarios"]), l) for l in limites)]

        por_operadora: Dict[str, Dict[str, Any]] = {}
        for r in linhas:
            op = por_operadora.setdefault(r["reg_ans"], {
                "registro_ans": r["reg_ans"],
                "nome": r["nome_fantasia"] or r["razao_social"],
                "razao_social": r["razao_social"],
                "uf": r["uf"],
                "modalidade": r["modalidade"] or "Não informada",
                "status": r["status"],
                "despesas": 0.0,
                "receitas": 0.0,
                "beneficiarios": 0,
                "_ultimo": (0, 0),
            })
            op["despesas"] += float(r["eventos"] or 0)
            op["receitas"] += float(r["contraprestacoes"] or 0)
            chave = (int(r["ano"]), int(r["trimestre"]))
            if chave >= op["_ultimo"]:
                op["_ultimo"] = chave
                op["beneficiarios"] = int(r["benef"] or 0)

        if f["faixas"]:
            limites = [FAIXAS_DESPESA[x] for x in f["faixas"]]
            por_operadora = {k: v for k, v in por_operadora.items()
                             if any(_na_faixa(v["despesas"], l) for l in limites)}
            linhas = [r for r in linhas if r["reg_ans"] in por_operadora]

        # Série temporal
        buckets: Dict[Tuple[int, int], Dict[str, float]] = defaultdict(lambda: {"despesas": 0.0, "receitas": 0.0})
        benef_trimestre: Dict[Tuple[int, int], int] = defaultdict(int)
        for r in linhas:
            ano, tri = int(r["ano"]), int(r["trimestre"])
            chave = (ano, 0) if granularidade == "ano" else (ano, tri)
            buckets[chave]["despesas"] += float(r["eventos"] or 0)
            buckets[chave]["receitas"] += float(r["contraprestacoes"] or 0)
            benef_trimestre[(ano, tri)] += int(r["benef"] or 0)

        def benef_do_bucket(ano: int, tri: int) -> int:
            if tri:
                return benef_trimestre.get((ano, tri), 0)
            ultimos = [t for (a, t) in benef_trimestre if a == ano]
            return benef_trimestre.get((ano, max(ultimos)), 0) if ultimos else 0

        serie = [
            {
                "ano": ano,
                "trimestre": tri or None,
                "despesas": round(v["despesas"], 2),
                "receitas": round(v["receitas"], 2),
                "sinistralidade": _sin(v["despesas"], v["receitas"]),
                "beneficiarios": benef_do_bucket(ano, tri),
            }
            for (ano, tri), v in sorted(buckets.items())
        ]

        # Distribuição por modalidade
        mods: Dict[str, Dict[str, float]] = defaultdict(lambda: {"despesas": 0.0, "receitas": 0.0, "beneficiarios": 0.0, "operadoras": 0})
        for op in por_operadora.values():
            m = mods[op["modalidade"]]
            m["despesas"] += op["despesas"]
            m["receitas"] += op["receitas"]
            m["beneficiarios"] += op["beneficiarios"]
            m["operadoras"] += 1
        por_modalidade = sorted(
            (
                {"modalidade": nome, "despesas": round(v["despesas"], 2), "receitas": round(v["receitas"], 2),
                 "sinistralidade": _sin(v["despesas"], v["receitas"]), "beneficiarios": int(v["beneficiarios"]),
                 "operadoras": int(v["operadoras"])}
                for nome, v in mods.items()
            ),
            key=lambda m: m["despesas"],
            reverse=True,
        )

        operadoras = sorted(por_operadora.values(), key=lambda o: o["despesas"], reverse=True)
        for op in operadoras:
            op.pop("_ultimo", None)
            op["despesas"] = round(op["despesas"], 2)
            op["receitas"] = round(op["receitas"], 2)
            op["sinistralidade"] = _sin(op["despesas"], op["receitas"])

        total_desp = sum(o["despesas"] for o in operadoras)
        total_rec = sum(o["receitas"] for o in operadoras)
        ultimo_tri = max(benef_trimestre) if benef_trimestre else None
        return {
            "kpis": {
                "despesas": round(total_desp, 2),
                "receitas": round(total_rec, 2),
                "sinistralidade": _sin(total_desp, total_rec),
                "beneficiarios": benef_trimestre.get(ultimo_tri, 0) if ultimo_tri else 0,
                "operadoras": len(operadoras),
            },
            "serie": serie,
            "por_modalidade": por_modalidade,
            "operadoras": operadoras[:LIMITE_LISTA],
            "total_operadoras": len(operadoras),
        }
