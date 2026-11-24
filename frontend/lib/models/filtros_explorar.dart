enum ModoPeriodo { ano, intervalo, ultimos, especificos }

/// Filtros da exploração. Todos são enviados à API; o resultado vem sempre do banco.
class FiltrosExplorar {
  final ModoPeriodo modo;
  final int? anoInicio;
  final int? anoFim;
  final int ultimos;

  /// Anos escolhidos um a um no modo "Anos específicos".
  final Set<int> anos;

  /// Trimestres selecionados (vazio = todos os trimestres disponíveis).
  final Set<int> trimestres;
  final bool comparar;
  final String granularidade;
  final Set<String> ufs;
  final Set<String> modalidades;
  final Set<String> portes;
  final Set<String> faixas;
  final Set<String> consolidacoes;
  final Set<String> statuses;

  const FiltrosExplorar({
    this.modo = ModoPeriodo.ano,
    this.anoInicio,
    this.anoFim,
    this.ultimos = 3,
    this.anos = const {},
    this.trimestres = const {},
    this.comparar = false,
    this.granularidade = 'trimestre',
    this.ufs = const {},
    this.modalidades = const {},
    this.portes = const {},
    this.faixas = const {},
    this.consolidacoes = const {},
    this.statuses = const {},
  });

  FiltrosExplorar copyWith({
    ModoPeriodo? modo,
    int? Function()? anoInicio,
    int? Function()? anoFim,
    int? ultimos,
    Set<int>? anos,
    Set<int>? trimestres,
    bool? comparar,
    String? granularidade,
    Set<String>? ufs,
    Set<String>? modalidades,
    Set<String>? portes,
    Set<String>? faixas,
    Set<String>? consolidacoes,
    Set<String>? statuses,
  }) =>
      FiltrosExplorar(
        modo: modo ?? this.modo,
        anoInicio: anoInicio != null ? anoInicio() : this.anoInicio,
        anoFim: anoFim != null ? anoFim() : this.anoFim,
        ultimos: ultimos ?? this.ultimos,
        anos: anos ?? this.anos,
        trimestres: trimestres ?? this.trimestres,
        comparar: comparar ?? this.comparar,
        granularidade: granularidade ?? this.granularidade,
        ufs: ufs ?? this.ufs,
        modalidades: modalidades ?? this.modalidades,
        portes: portes ?? this.portes,
        faixas: faixas ?? this.faixas,
        consolidacoes: consolidacoes ?? this.consolidacoes,
        statuses: statuses ?? this.statuses,
      );

  /// Quantidade de filtros avançados ativos (exibida no botão "Filtros").
  int get avancadosAtivos =>
      (ufs.isNotEmpty ? 1 : 0) +
      (modalidades.isNotEmpty ? 1 : 0) +
      (portes.isNotEmpty ? 1 : 0) +
      (faixas.isNotEmpty ? 1 : 0) +
      (consolidacoes.isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0);

  FiltrosExplorar semAvancados() => FiltrosExplorar(
      modo: modo,
      anoInicio: anoInicio,
      anoFim: anoFim,
      ultimos: ultimos,
      anos: anos,
      trimestres: trimestres,
      comparar: comparar,
      granularidade: granularidade);
}

const rotulosPorte = {'pequeno': 'Pequeno porte', 'medio': 'Médio porte', 'grande': 'Grande porte'};
const descricoesPorte = {
  'pequeno': 'Até 20 mil beneficiários',
  'medio': '20 mil a 100 mil beneficiários',
  'grande': 'Mais de 100 mil beneficiários',
};
const rotulosFaixa = {
  'ate_10mi': 'Até R\$ 10 mi',
  '10mi_100mi': 'R\$ 10 mi a 100 mi',
  '100mi_1bi': 'R\$ 100 mi a 1 bi',
  'acima_1bi': 'Acima de R\$ 1 bi',
};
const rotulosConsolidacao = {'consolidado': 'Lote auditado', 'pendente': 'Auditoria pendente'};
