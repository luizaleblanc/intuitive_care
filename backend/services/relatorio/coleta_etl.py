"""Coleta e consolidação das bases ETL para geração dos relatórios."""
from collections import defaultdict
from datetime import datetime
from typing import Any, Dict, List, Sequence, Tuple

from backend.repositories.relatorio_repository import RelatorioRepository
from backend.services.explorar_service import FAIXAS_DESPESA, PORTES
from backend.services.relatorio.formatadores import (
    classificar_porte,
    fmt_cnpj,
    fmt_periodo,
    na_faixa,
    rotulo_anos,
    rotulo_trimestres,
)
from backend.services.relatorio.parametros import parse_params

FatoTupla = Tuple[int, int, str, float, float, float, float, float, int, int, bool]


def _filtrar_ops_elegiveis(cadastro: List[Dict[str, Any]], portes: Sequence[str]) -> Dict[str, Dict[str, Any]]:
    ops_map: Dict[str, Dict[str, Any]] = {}
    limites_porte = [PORTES[p] for p in portes] if portes else []
    for op_cad in cadastro:
        benef_cadop = int(op_cad.get("beneficiarios") or 0)
        if limites_porte and not (benef_cadop and any(na_faixa(float(benef_cadop), lim) for lim in limites_porte)):
            continue
        ops_map[op_cad["registro_ans"]] = op_cad
    return ops_map


def _coletar_fatos(
    demonstracoes_brutas: Sequence[Tuple[Any, ...]],
    ops_map: Dict[str, Dict[str, Any]],
    benef_mapa: Dict[Tuple[str, int, int], Tuple[int, int]],
    auditado_mapa: Dict[Tuple[int, int], bool],
    consolidacao: str,
) -> List[FatoTupla]:
    fatos: List[FatoTupla] = []
    fatos_append = fatos.append
    for raw in demonstracoes_brutas:
        reg = raw[2]
        if reg not in ops_map:
            continue
        ano = int(raw[0])
        tri = int(raw[1])
        aud = auditado_mapa.get((ano, tri), False)
        if consolidacao == "consolidado" and not aud:
            continue
        if consolidacao == "pendente" and aud:
            continue
        bmh, bod = benef_mapa.get((reg, ano, tri), (0, 0))
        fatos_append((
            ano, tri, reg,
            float(raw[3] or 0), float(raw[4] or 0), float(raw[5] or 0),
            float(raw[6] or 0), float(raw[7] or 0),
            bmh, bod, aud,
        ))
    # Ordenação estável por período decrescente e maior despesa
    fatos.sort(key=lambda t: (t[0], t[1], t[4]), reverse=True)
    return fatos


def _consolidar_por_operadora(
    fatos: List[FatoTupla],
    ops_map: Dict[str, Dict[str, Any]],
    faixas: Sequence[str],
) -> Tuple[Dict[str, Dict[str, Any]], List[FatoTupla]]:
    por_op: Dict[str, Dict[str, Any]] = {}
    for ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, _aud in fatos:
        op = por_op.get(reg)
        if op is None:
            cad_o = ops_map[reg]
            op = {
                "registro_ans": reg,
                "cnpj": fmt_cnpj(cad_o["cnpj"]),
                "razao_social": cad_o["razao_social"] or "",
                "nome_fantasia": cad_o["nome_fantasia"] or cad_o["razao_social"] or "",
                "modalidade": cad_o["modalidade"] or "Não informada",
                "uf": cad_o["uf"] or "",
                "cidade": cad_o["cidade"] or "",
                "status": cad_o["status"] or "",
                "porte": classificar_porte(int(cad_o.get("beneficiarios") or 0)),
                "trimestres": 0,
                "receitas": 0.0,
                "despesas": 0.0,
                "eventos_mh": 0.0,
                "comercializacao": 0.0,
                "administrativas": 0.0,
                "benef_mh": 0,
                "benef_odonto": 0,
                "_ultimo": (0, 0),
            }
            por_op[reg] = op
        op["trimestres"] += 1
        op["receitas"] += rec
        op["despesas"] += ev
        op["eventos_mh"] += ev_mh
        op["comercializacao"] += com
        op["administrativas"] += adm
        chave = (ano, tri)
        if chave >= op["_ultimo"]:
            op["_ultimo"] = chave
            op["benef_mh"] = bmh
            op["benef_odonto"] = bod

    if faixas:
        limites_faixa = [FAIXAS_DESPESA[f] for f in faixas]
        por_op = {
            k: v for k, v in por_op.items()
            if any(na_faixa(v["despesas"], lim) for lim in limites_faixa)
        }
        fatos = [t for t in fatos if t[2] in por_op]

    for op in por_op.values():
        op.pop("_ultimo", None)
        op["resultado"] = op["receitas"] - op["despesas"] - op["comercializacao"] - op["administrativas"]
        op["sinistralidade"] = (op["despesas"] / op["receitas"]) if op["receitas"] > 0 else None
        op["indice_combinado"] = (
            (op["despesas"] + op["comercializacao"] + op["administrativas"]) / op["receitas"]
            if op["receitas"] > 0
            else None
        )
        op["beneficiarios"] = op["benef_mh"] + op["benef_odonto"]
        op["ticket_medio"] = (op["eventos_mh"] / op["benef_mh"]) if op["benef_mh"] > 0 else None

    return por_op, fatos


def _construir_serie(fatos: List[FatoTupla], granularidade: str) -> Tuple[List[Dict[str, Any]], Dict[Tuple[int, int], List[int]]]:
    buckets: Dict[Tuple[int, int], Dict[str, Any]] = defaultdict(
        lambda: {
            "ops": set(),
            "receitas": 0.0,
            "despesas": 0.0,
            "eventos_mh": 0.0,
            "comercializacao": 0.0,
            "administrativas": 0.0,
        }
    )
    benef_tri: Dict[Tuple[int, int], List[int]] = defaultdict(lambda: [0, 0])
    for ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, _aud in fatos:
        chave = (ano, 0) if granularidade == "ano" else (ano, tri)
        b = buckets[chave]
        b["ops"].add(reg)
        b["receitas"] += rec
        b["despesas"] += ev
        b["eventos_mh"] += ev_mh
        b["comercializacao"] += com
        b["administrativas"] += adm
        bt = benef_tri[(ano, tri)]
        bt[0] += bmh
        bt[1] += bod

    def _benef_bucket(ano: int, tri: int) -> Tuple[int, int]:
        if tri:
            v = benef_tri.get((ano, tri), [0, 0])
            return v[0], v[1]
        tris_ano = [t for (a, t) in benef_tri if a == ano]
        if not tris_ano:
            return 0, 0
        v = benef_tri[(ano, max(tris_ano))]
        return v[0], v[1]

    serie: List[Dict[str, Any]] = []
    for (ano, tri), b in sorted(buckets.items()):
        bmh, bod = _benef_bucket(ano, tri)
        serie.append(
            {
                "periodo": fmt_periodo(ano, tri or None),
                "ano": ano,
                "trimestre": tri or None,
                "operadoras": len(b["ops"]),
                "receitas": round(b["receitas"], 2),
                "despesas": round(b["despesas"], 2),
                "eventos_mh": round(b["eventos_mh"], 2),
                "comercializacao": round(b["comercializacao"], 2),
                "administrativas": round(b["administrativas"], 2),
                "resultado": round(b["receitas"] - b["despesas"] - b["comercializacao"] - b["administrativas"], 2),
                "sinistralidade": (b["despesas"] / b["receitas"]) if b["receitas"] > 0 else None,
                "indice_combinado": (
                    (b["despesas"] + b["comercializacao"] + b["administrativas"]) / b["receitas"]
                    if b["receitas"] > 0
                    else None
                ),
                "benef_mh": bmh,
                "benef_odonto": bod,
                "benef_total": bmh + bod,
                "ticket_medio": (b["eventos_mh"] / bmh) if bmh > 0 else None,
            }
        )
    return serie, benef_tri


def _agrupar_por_campo(por_op: Dict[str, Dict[str, Any]], campo: str) -> List[Dict[str, Any]]:
    acc: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {
            "operadoras": 0,
            "receitas": 0.0,
            "despesas": 0.0,
            "eventos_mh": 0.0,
            "comercializacao": 0.0,
            "administrativas": 0.0,
            "benef_mh": 0,
            "benef_odonto": 0,
        }
    )
    for op in por_op.values():
        g = acc[op[campo] or "Não informada"]
        g["operadoras"] += 1
        g["receitas"] += op["receitas"]
        g["despesas"] += op["despesas"]
        g["eventos_mh"] += op["eventos_mh"]
        g["comercializacao"] += op["comercializacao"]
        g["administrativas"] += op["administrativas"]
        g["benef_mh"] += op["benef_mh"]
        g["benef_odonto"] += op["benef_odonto"]
    total_desp_g = sum(v["despesas"] for v in acc.values()) or 1.0
    saida = []
    for chave, v in sorted(acc.items(), key=lambda item: item[1]["despesas"], reverse=True):
        saida.append(
            {
                campo: chave,
                "operadoras": v["operadoras"],
                "receitas": round(v["receitas"], 2),
                "despesas": round(v["despesas"], 2),
                "eventos_mh": round(v["eventos_mh"], 2),
                "comercializacao": round(v["comercializacao"], 2),
                "administrativas": round(v["administrativas"], 2),
                "resultado": round(v["receitas"] - v["despesas"] - v["comercializacao"] - v["administrativas"], 2),
                "sinistralidade": (v["despesas"] / v["receitas"]) if v["receitas"] > 0 else None,
                "participacao": v["despesas"] / total_desp_g,
                "benef_mh": v["benef_mh"],
                "benef_odonto": v["benef_odonto"],
                "ticket_medio": (v["eventos_mh"] / v["benef_mh"]) if v["benef_mh"] > 0 else None,
            }
        )
    return saida


def _materializar_base_demo(fatos: List[FatoTupla], ops_map: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [
        {
            "ano": ano,
            "trimestre": tri,
            "reg_ans": reg,
            "cnpj": ops_map[reg]["cnpj"],
            "razao_social": ops_map[reg]["razao_social"],
            "nome_fantasia": ops_map[reg]["nome_fantasia"],
            "modalidade": ops_map[reg]["modalidade"],
            "uf": ops_map[reg]["uf"],
            "cidade": ops_map[reg]["cidade"],
            "status": ops_map[reg]["status"],
            "contraprestacoes": rec,
            "eventos": ev,
            "eventos_mh": ev_mh,
            "comercializacao": com,
            "administrativas": adm,
            "benef_mh": bmh,
            "benef_odonto": bod,
            "auditado": aud,
        }
        for (ano, tri, reg, rec, ev, ev_mh, com, adm, bmh, bod, aud) in fatos
    ]


def _montar_recorte(cfg: Dict[str, Any], total_operadoras: int, total_fatos: int) -> str:
    filtros_txt = []
    if cfg["ufs"]:
        filtros_txt.append(f"UF: {', '.join(cfg['ufs'])}")
    if cfg["modalidades"]:
        filtros_txt.append(f"Modalidade: {', '.join(cfg['modalidades'])}")
    if cfg["statuses"]:
        filtros_txt.append(f"Status: {', '.join(cfg['statuses'])}")
    if cfg["portes"]:
        filtros_txt.append(f"Porte: {', '.join(cfg['portes'])}")
    if cfg["consolidacao"]:
        filtros_txt.append(f"Consolidação: {cfg['consolidacao']}")
    return " · ".join(
        [
            f"Período {rotulo_anos(cfg['anos'])} ({rotulo_trimestres(cfg['trimestres'])})",
            *filtros_txt,
            f"{total_operadoras} operadoras · {total_fatos} registros contábeis ETL",
        ]
    )


def coletar_dados(
    payload: Dict[str, Any], usuario_nome: str = "", *, _tuplas_fato: bool = False
) -> Dict[str, Any]:
    cfg = parse_params(payload)
    pacote = RelatorioRepository.carregar_pacote_etl(
        anos=cfg["anos"],
        trimestres=cfg["trimestres"],
        ufs=cfg["ufs"],
        modalidades=cfg["modalidades"],
        statuses=cfg["statuses"],
        incluir_contas="contas_setor" in cfg["secoes"],
    )
    cadastro_completo = pacote["operadoras"]
    lotes = pacote["lotes_etl"]
    auditado_mapa = {(int(l["ano"]), int(l["trimestre"])): bool(l.get("auditado")) for l in lotes}

    ops_map = _filtrar_ops_elegiveis(cadastro_completo, cfg["portes"])
    fatos = _coletar_fatos(
        pacote["demonstracoes_brutas"], ops_map, pacote["beneficiarios_mapa"], auditado_mapa, cfg["consolidacao"]
    )
    por_op, fatos = _consolidar_por_operadora(fatos, ops_map, cfg["faixas"])
    serie, benef_tri = _construir_serie(fatos, cfg["granularidade"])

    por_modalidade = _agrupar_por_campo(por_op, "modalidade")
    por_uf = _agrupar_por_campo(por_op, "uf")

    chave_ordem = cfg["ordenar_por"]
    operadoras = sorted(
        por_op.values(),
        key=lambda o: (o.get(chave_ordem) is not None, float(o.get(chave_ordem) or 0.0)),
        reverse=True,
    )
    total_operadoras = len(operadoras)
    if cfg["limite_operadoras"] is not None:
        operadoras = operadoras[: cfg["limite_operadoras"]]

    tot_rec = sum(o["receitas"] for o in por_op.values())
    tot_desp = sum(o["despesas"] for o in por_op.values())
    tot_mh = sum(o["eventos_mh"] for o in por_op.values())
    tot_com = sum(o["comercializacao"] for o in por_op.values())
    tot_adm = sum(o["administrativas"] for o in por_op.values())
    ultimo_tri = max(benef_tri) if benef_tri else None
    tot_bmh = benef_tri[ultimo_tri][0] if ultimo_tri else 0
    tot_bod = benef_tri[ultimo_tri][1] if ultimo_tri else 0

    contas = pacote["contas_setor"]
    cadastro = cadastro_completo if "lotes_cadastro" in cfg["secoes"] else []
    despesas_resumo = pacote["despesas_resumo"]

    # Base fato materializada em dicts apenas quando necessário (XLSX usa tuplas direto sem overhead)
    base_demo_dicts = (
        _materializar_base_demo(fatos, ops_map)
        if ("base_demonstracoes" in cfg["secoes"] and not _tuplas_fato)
        else []
    )
    recorte = _montar_recorte(cfg, total_operadoras, len(fatos))

    return {
        "cfg": cfg,
        "usuario": usuario_nome,
        "gerado_em": datetime.now(),
        "recorte": recorte,
        "kpis": {
            "operadoras": total_operadoras,
            "registros_demonstracoes": len(fatos),
            "receitas": round(tot_rec, 2),
            "despesas": round(tot_desp, 2),
            "eventos_mh": round(tot_mh, 2),
            "comercializacao": round(tot_com, 2),
            "administrativas": round(tot_adm, 2),
            "resultado": round(tot_rec - tot_desp - tot_com - tot_adm, 2),
            "sinistralidade": (tot_desp / tot_rec) if tot_rec > 0 else None,
            "indice_combinado": ((tot_desp + tot_com + tot_adm) / tot_rec) if tot_rec > 0 else None,
            "benef_mh": tot_bmh,
            "benef_odonto": tot_bod,
            "benef_total": tot_bmh + tot_bod,
            "ticket_medio": (tot_mh / tot_bmh) if tot_bmh > 0 else None,
            "lotes_total": len(lotes),
            "lotes_auditados": sum(1 for l in lotes if bool(l.get("auditado"))),
            "registros_extraidos_ans": sum(int(l.get("registros_extraidos") or 0) for l in lotes),
            "despesas_lancamentos": despesas_resumo["total_registros"],
        },
        "serie": serie,
        "por_modalidade": por_modalidade,
        "por_uf": por_uf,
        "operadoras": operadoras,
        "base_demonstracoes": base_demo_dicts,
        "_fatos_tuplas": fatos if "base_demonstracoes" in cfg["secoes"] else [],
        "_ops_map": ops_map,
        "contas_setor": contas,
        "lotes_etl": lotes,
        "cadastro_operadoras": cadastro,
    }
