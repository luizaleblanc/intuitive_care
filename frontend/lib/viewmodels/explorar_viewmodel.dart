import 'package:flutter/foundation.dart';

import '../models/explorar_model.dart';
import '../repositories/analitico_repository.dart';
import '../services/api_client.dart';

enum ModoPeriodo { ano, intervalo, ultimos }

/// Filtros da exploração. Todos são enviados à API; o resultado vem sempre do banco.
class FiltrosExplorar {
  final ModoPeriodo modo;
  final int? anoInicio;
  final int? anoFim;
  final int ultimos;
  final bool comparar;
  final String granularidade;
  final Set<String> ufs;
  final Set<String> modalidades;
  final String porte;
  final String faixaDespesa;
  final String consolidacao;
  final String status;

  const FiltrosExplorar({
    this.modo = ModoPeriodo.ano,
    this.anoInicio,
    this.anoFim,
    this.ultimos = 3,
    this.comparar = false,
    this.granularidade = 'trimestre',
    this.ufs = const {},
    this.modalidades = const {},
    this.porte = '',
    this.faixaDespesa = '',
    this.consolidacao = '',
    this.status = '',
  });

  FiltrosExplorar copyWith({
    ModoPeriodo? modo,
    int? Function()? anoInicio,
    int? Function()? anoFim,
    int? ultimos,
    bool? comparar,
    String? granularidade,
    Set<String>? ufs,
    Set<String>? modalidades,
    String? porte,
    String? faixaDespesa,
    String? consolidacao,
    String? status,
  }) =>
      FiltrosExplorar(
        modo: modo ?? this.modo,
        anoInicio: anoInicio != null ? anoInicio() : this.anoInicio,
        anoFim: anoFim != null ? anoFim() : this.anoFim,
        ultimos: ultimos ?? this.ultimos,
        comparar: comparar ?? this.comparar,
        granularidade: granularidade ?? this.granularidade,
        ufs: ufs ?? this.ufs,
        modalidades: modalidades ?? this.modalidades,
        porte: porte ?? this.porte,
        faixaDespesa: faixaDespesa ?? this.faixaDespesa,
        consolidacao: consolidacao ?? this.consolidacao,
        status: status ?? this.status,
      );

  /// Quantidade de filtros avançados ativos (exibida no botão "Filtros").
  int get avancadosAtivos =>
      (ufs.isNotEmpty ? 1 : 0) +
      (modalidades.isNotEmpty ? 1 : 0) +
      (porte.isNotEmpty ? 1 : 0) +
      (faixaDespesa.isNotEmpty ? 1 : 0) +
      (consolidacao.isNotEmpty ? 1 : 0) +
      (status.isNotEmpty ? 1 : 0);

  FiltrosExplorar semAvancados() => FiltrosExplorar(
      modo: modo, anoInicio: anoInicio, anoFim: anoFim, ultimos: ultimos, comparar: comparar, granularidade: granularidade);
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

class ExplorarViewModel extends ChangeNotifier {
  final AnaliticoRepository _repository;
  ExplorarViewModel(this._repository);

  ExplorarModel? _dados;
  FiltrosExplorar _filtros = const FiltrosExplorar();
  List<GraficoConfig> _graficos = List.of(GraficoConfig.padrao);
  bool _isLoading = false;
  String? _error;
  int _requisicao = 0;

  ExplorarModel? get dados => _dados;
  FiltrosExplorar get filtros => _filtros;
  List<GraficoConfig> get graficos => List.unmodifiable(_graficos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<int> get anosDisponiveis => _dados?.anosDisponiveis ?? const [];

  /// Intervalo efetivo (ano inicial, ano final) a partir do modo escolhido.
  (int?, int?) get intervalo {
    final anos = anosDisponiveis;
    final maisRecente = anos.isEmpty ? null : anos.last;
    switch (_filtros.modo) {
      case ModoPeriodo.ano:
        final a = _filtros.anoFim ?? maisRecente;
        return (a, a);
      case ModoPeriodo.intervalo:
        return (_filtros.anoInicio ?? anos.firstOrNull, _filtros.anoFim ?? maisRecente);
      case ModoPeriodo.ultimos:
        if (maisRecente == null) return (null, null);
        final inicio = maisRecente - _filtros.ultimos + 1;
        return (anos.isEmpty ? inicio : (inicio < anos.first ? anos.first : inicio), maisRecente);
    }
  }

  Map<String, String> get consulta {
    final (ini, fim) = intervalo;
    return {
      'ano_inicio': ini?.toString() ?? '',
      'ano_fim': fim?.toString() ?? '',
      'granularidade': _filtros.granularidade,
      'comparar': _filtros.comparar ? '1' : '',
      'uf': (_filtros.ufs.toList()..sort()).join(','),
      'modalidade': (_filtros.modalidades.toList()..sort()).join(','),
      'porte': _filtros.porte,
      'faixa_despesa': _filtros.faixaDespesa,
      'consolidacao': _filtros.consolidacao,
      'status': _filtros.status,
    };
  }

  Future<void> carregar() async {
    final id = ++_requisicao;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final dados = await _repository.explorar(consulta);
      if (id != _requisicao) return; // Resposta de um filtro antigo: descarta.
      _dados = dados;
    } on ApiException catch (e) {
      if (id == _requisicao) _error = e.message;
    } finally {
      if (id == _requisicao) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> aplicar(FiltrosExplorar novos) async {
    // Intervalo invertido é corrigido na hora, antes de consultar.
    if (novos.modo == ModoPeriodo.intervalo &&
        novos.anoInicio != null &&
        novos.anoFim != null &&
        novos.anoInicio! > novos.anoFim!) {
      novos = novos.copyWith(anoInicio: () => novos.anoFim, anoFim: () => novos.anoInicio);
    }
    _filtros = novos;
    await carregar();
  }

  // ---------------------------------------------------------------- gráficos
  void definirGraficos(List<GraficoConfig>? salvos) {
    if (salvos == null || salvos.isEmpty) return;
    _graficos = List.of(salvos.take(8));
    notifyListeners();
  }

  bool adicionarGrafico(GraficoConfig g) {
    if (_graficos.length >= 8) return false;
    _graficos.add(g);
    notifyListeners();
    return true;
  }

  void substituirGrafico(int i, GraficoConfig g) {
    _graficos[i] = g;
    notifyListeners();
  }

  void removerGrafico(int i) {
    _graficos.removeAt(i);
    notifyListeners();
  }

  void moverGrafico(int de, int para) {
    if (para < 0 || para >= _graficos.length) return;
    final g = _graficos.removeAt(de);
    _graficos.insert(para, g);
    notifyListeners();
  }

  void restaurarGraficos() {
    _graficos = List.of(GraficoConfig.padrao);
    notifyListeners();
  }

  List<Map<String, String>> get graficosJson => [for (final g in _graficos) g.toJson()];
}
