"""Fonte única das regras de acesso por perfil.

A API consulta este módulo para liberar ou bloquear cada ação, e `init_db` grava o mesmo
conteúdo nas tabelas `perfis_acesso` e `permissoes_perfil` para consulta no banco.
Para mudar uma regra, altere apenas este arquivo.
"""
from typing import Dict, FrozenSet, Tuple

PERFIS: Dict[str, Tuple[str, str]] = {
    "ADMIN": ("Administrador", "Consulta, exporta e altera os dados da plataforma."),
    "COLABORADOR": ("Colaborador", "Somente consulta. Não exporta nem altera dados, exceto o próprio perfil."),
}

# código -> (descrição, perfis autorizados)
PERMISSOES: Dict[str, Tuple[str, Tuple[str, ...]]] = {
    "painel.ver": ("Ver o painel e seus indicadores", ("ADMIN", "COLABORADOR")),
    "operadoras.ver": ("Listar e consultar operadoras ativas", ("ADMIN", "COLABORADOR")),
    "despesas.ver": ("Consultar despesas e contas do setor", ("ADMIN", "COLABORADOR")),
    "dados.exportar": ("Exportar dados em CSV, PDF ou XLSX", ("ADMIN",)),
    "perfil.editar_proprio": ("Editar os próprios dados, foto e preferências", ("ADMIN", "COLABORADOR")),
    "operadoras.ver_inativas": ("Ver operadoras inativas", ("ADMIN",)),
    "operadoras.criar": ("Cadastrar operadora", ("ADMIN",)),
    "operadoras.editar": ("Editar dados de operadora", ("ADMIN",)),
    "operadoras.alterar_status": ("Inativar ou reativar operadora", ("ADMIN",)),
    "operadoras.excluir": ("Excluir operadora", ("ADMIN",)),
    "despesas.criar": ("Lançar despesa", ("ADMIN",)),
    "despesas.editar": ("Editar despesa", ("ADMIN",)),
    "despesas.excluir": ("Excluir despesa", ("ADMIN",)),
    "lotes.auditar": ("Marcar lote de demonstrações contábeis como auditado", ("ADMIN",)),
}

PERFIL_PADRAO = "COLABORADOR"


def permissoes_do_perfil(perfil: str) -> FrozenSet[str]:
    return frozenset(codigo for codigo, (_, perfis) in PERMISSOES.items() if perfil in perfis)


def tem_permissao(perfil: str, permissao: str) -> bool:
    if permissao not in PERMISSOES:
        raise KeyError(f"Permissão desconhecida: {permissao}")
    return perfil in PERMISSOES[permissao][1]
