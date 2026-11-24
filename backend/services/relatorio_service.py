"""Geração robusta de planilhas (XLSX com openpyxl), CSV e relatórios estruturados a partir das bases ETL da ANS.

Bases consultadas diretamente no banco:
- demonstracoes_operadora (contraprestações, eventos, eventos_mh, comercialização, administrativas)
- beneficiarios_trimestre (médico-hospitalar e odontológico por trimestre)
- operadoras (CADOP ativas e canceladas, CNPJ, cidade, UF, modalidade, representante)
- contas_setor (plano de contas ANS consolidado do setor)
- lotes_etl (rastreabilidade e status de auditoria dos lotes extraídos)
- despesas (lançamentos assistenciais consolidados)
"""
from io import BytesIO
from typing import Any, Dict, Optional, Tuple

from openpyxl import Workbook

from backend.services.relatorio.abas.agrupamentos import escrever_aba_modalidades, escrever_aba_ufs
from backend.services.relatorio.abas.base_e_contas import (
    escrever_aba_base_demonstracoes,
    escrever_aba_contas_setor,
)
from backend.services.relatorio.abas.lotes_e_cadastro import escrever_aba_cadastro, escrever_aba_lotes
from backend.services.relatorio.abas.operadoras import escrever_aba_operadoras
from backend.services.relatorio.abas.resumo_e_evolucao import escrever_aba_evolucao, escrever_aba_resumo
from backend.services.relatorio.coleta_etl import coletar_dados
from backend.services.relatorio.constantes import (
    FMT_INT,
    FMT_MOEDA,
    FMT_PCT,
    FORMATOS_VALIDOS,
    ORDENS_VALIDAS,
    SECOES_PADRAO,
    SECOES_VALIDAS,
    STREAM_THRESHOLD_PADRAO,
)
from backend.services.relatorio.estilos_ooxml import StyleRegistry, aplicar_stream_patches, criar_estilos
from backend.services.relatorio.formatadores import fmt_data
from backend.services.relatorio.formatos_texto import formatar_tabelas_estruturadas, gerar_csv_de_tabelas
from backend.services.relatorio.parametros import parse_params

# Mantido no módulo para compatibilidade com testes que sobrescrevem o limite via patch.object.
_STREAM_THRESHOLD = STREAM_THRESHOLD_PADRAO
_Estilos = criar_estilos
_StyleRegistry = StyleRegistry

__all__ = [
    "SECOES_VALIDAS",
    "SECOES_PADRAO",
    "ORDENS_VALIDAS",
    "FORMATOS_VALIDOS",
    "FMT_MOEDA",
    "FMT_PCT",
    "FMT_INT",
    "RelatorioService",
]


class RelatorioService:
    """Orquestra consultas ETL e exportação em XLSX (openpyxl), CSV ou JSON estruturado."""

    @classmethod
    def _parse_params(cls, payload: Dict[str, Any]) -> Dict[str, Any]:
        return parse_params(payload)

    @classmethod
    def coletar_dados(
        cls, payload: Dict[str, Any], usuario_nome: str = "", *, _tuplas_fato: bool = False
    ) -> Dict[str, Any]:
        return coletar_dados(payload, usuario_nome=usuario_nome, _tuplas_fato=_tuplas_fato)

    @classmethod
    def gerar_xlsx(cls, payload: Dict[str, Any], usuario_nome: str = "") -> Tuple[bytes, str]:
        dados = cls.coletar_dados(payload, usuario_nome=usuario_nome, _tuplas_fato=True)
        cfg = dados["cfg"]
        st = criar_estilos()
        wb = Workbook()
        wb.remove(wb.active)
        reg = StyleRegistry(wb)
        # Mapa nome_da_aba -> (ultima_col_letra, ultima_linha, bytes_xml_rows)
        stream_patches: Dict[str, Tuple[str, int, bytes]] = {}
        threshold = _STREAM_THRESHOLD

        fmt_data_padrao = cfg["formato_data"]
        gerado_txt = fmt_data(dados["gerado_em"], formato=fmt_data_padrao, hora=True)
        subtitulo = f"{dados['recorte']} · Gerado em {gerado_txt}" + (
            f" por {usuario_nome}" if usuario_nome else ""
        )

        secoes = cfg["secoes"]
        if "resumo" in secoes:
            escrever_aba_resumo(wb, dados, subtitulo, st)
        if "evolucao" in secoes:
            escrever_aba_evolucao(wb, dados, subtitulo, st)
        if "modalidades" in secoes:
            escrever_aba_modalidades(wb, dados, subtitulo, st)
        if "ufs" in secoes:
            escrever_aba_ufs(wb, dados, subtitulo, st)
        if "operadoras" in secoes:
            escrever_aba_operadoras(wb, dados, subtitulo, st, reg, stream_patches, stream_threshold=threshold)
        if "contas_setor" in secoes:
            escrever_aba_contas_setor(wb, dados, subtitulo, st, reg, stream_patches, stream_threshold=threshold)
        if "base_demonstracoes" in secoes:
            escrever_aba_base_demonstracoes(wb, dados, subtitulo, st, reg, stream_patches, stream_threshold=threshold)
        if "lotes_cadastro" in secoes:
            escrever_aba_lotes(wb, dados, subtitulo, st, fmt_data_padrao)
            escrever_aba_cadastro(wb, dados, subtitulo, st, fmt_data_padrao, reg, stream_patches, stream_threshold=threshold)

        reg.cleanup()
        if not wb.sheetnames:
            escrever_aba_resumo(wb, dados, subtitulo, st)

        buf = BytesIO()
        wb.save(buf)
        conteudo = aplicar_stream_patches(buf.getvalue(), stream_patches) if stream_patches else buf.getvalue()

        anos = cfg["anos"]
        sufixo = str(anos[0]) if len(anos) == 1 else f"{anos[0]}_{anos[-1]}"
        return conteudo, f"relatorio_etl_ans_{sufixo}.xlsx"

    @classmethod
    def gerar_tabelas_estruturadas(
        cls, payload: Dict[str, Any], usuario_nome: str = "", limite_linhas_brutas: Optional[int] = None
    ) -> Dict[str, Any]:
        """Monta tabelas padronizadas para CSV multi-seção e geração de PDF."""
        dados = cls.coletar_dados(payload, usuario_nome=usuario_nome)
        return formatar_tabelas_estruturadas(dados, limite_linhas_brutas=limite_linhas_brutas)

    @classmethod
    def gerar_csv(cls, payload: Dict[str, Any], usuario_nome: str = "") -> Tuple[bytes, str]:
        estruturado = cls.gerar_tabelas_estruturadas(payload, usuario_nome=usuario_nome)
        return gerar_csv_de_tabelas(estruturado)
