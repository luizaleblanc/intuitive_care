import 'package:flutter/foundation.dart';

import '../models/explorar_model.dart';
import '../models/filtros_explorar.dart';
import '../repositories/analitico_repository.dart';
import '../services/api_exception.dart';

export '../models/filtros_explorar.dart';

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
      case ModoPeriodo.especificos:
        final sel = anosSelecionados;
        return (sel.firstOrNull, sel.lastOrNull);
      case ModoPeriodo.ultimos:
        if (maisRecente == null) return (null, null);
        final inicio = maisRecente - _filtros.ultimos + 1;
        return (anos.isEmpty ? inicio : (inicio < anos.first ? anos.first : inicio), maisRecente);
    }
  }

  /// Anos marcados no modo "Anos específicos" (o mais recente, se nenhum).
  List<int> get anosSelecionados {
    final validos = _filtros.anos.where(anosDisponiveis.contains).toList()..sort();
    if (validos.isNotEmpty || anosDisponiveis.isEmpty) return validos;
    return [anosDisponiveis.last];
  }

  Map<String, String> get consulta {
    final (ini, fim) = intervalo;
    final especificos = _filtros.modo == ModoPeriodo.especificos;
    return {
      'anos': especificos ? anosSelecionados.join(',') : '',
      'ano_inicio': especificos ? '' : ini?.toString() ?? '',
      'ano_fim': especificos ? '' : fim?.toString() ?? '',
      'trimestres': (_filtros.trimestres.toList()..sort()).join(','),
      'granularidade': _filtros.granularidade,
      'comparar': _filtros.comparar ? '1' : '',
      'uf': (_filtros.ufs.toList()..sort()).join(','),
      'modalidade': (_filtros.modalidades.toList()..sort()).join(','),
      'porte': (_filtros.portes.toList()..sort()).join(','),
      'faixa_despesa': (_filtros.faixas.toList()..sort()).join(','),
      'consolidacao': (_filtros.consolidacoes.toList()..sort()).join(','),
      'status': (_filtros.statuses.toList()..sort()).join(','),
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

  /// Consulta pontual usada pelo construtor de relatório personalizado (sem alterar a tela Explorar).
  Future<ExplorarModel> consultarRelatorio(Map<String, String> consulta) => _repository.explorar(consulta);

  /// Solicita à API a exportação binária robusta (XLSX com openpyxl ou CSV UTF-8 BOM) das bases ETL.
  Future<({Uint8List bytes, String? filename})> exportarRelatorioBytes(Map<String, dynamic> payload) =>
      _repository.exportarRelatorioBytes(payload);

  /// Solicita à API as tabelas estruturadas das bases ETL em JSON para composição de PDF.
  Future<Map<String, dynamic>> exportarRelatorioJson(Map<String, dynamic> payload) =>
      _repository.exportarRelatorioJson(payload);

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
