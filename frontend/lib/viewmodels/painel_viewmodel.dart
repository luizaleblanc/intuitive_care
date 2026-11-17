import 'package:flutter/foundation.dart';

import '../models/analitico_model.dart';
import '../repositories/analitico_repository.dart';
import '../services/api_client.dart';

/// Estado do Painel Geral. Filtros de período sempre em dois campos: Ano + Trimestre.
class PainelViewModel extends ChangeNotifier {
  final AnaliticoRepository _repository;

  PainelViewModel(this._repository);

  PainelModel? _painel;
  bool _isLoading = false;
  String? _error;
  int? _ano;
  int? _trimestre;
  String _uf = '';
  String _modalidade = '';
  bool _preferenciasAplicadas = false;

  PainelModel? get painel => _painel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get ano => _ano ?? _painel?.periodo.ano;
  int? get trimestre => _trimestre ?? _painel?.periodo.trimestre;
  String get uf => _uf;
  String get modalidade => _modalidade;

  /// Anos com dados carregados (do banco).
  List<int> get anosDisponiveis =>
      (_painel?.periodos.map((p) => p.ano).toSet().toList() ?? <int>[])..sort((a, b) => b.compareTo(a));

  /// Trimestres disponíveis para o ano selecionado.
  List<int> trimestresDoAno(int? ano) =>
      (_painel?.periodos.where((p) => p.ano == ano).map((p) => p.trimestre).toList() ?? <int>[])..sort();

  /// Aplica UF e trimestre padrão das preferências do usuário (apenas uma vez por sessão).
  void aplicarPreferencias({String? ufPadrao, int? trimestrePadrao}) {
    if (_preferenciasAplicadas) return;
    _preferenciasAplicadas = true;
    _uf = ufPadrao ?? '';
    _trimestre = trimestrePadrao;
  }

  void reset() {
    _painel = null;
    _ano = null;
    _trimestre = null;
    _uf = '';
    _modalidade = '';
    _preferenciasAplicadas = false;
    _error = null;
  }

  Future<void> carregar({int? ano, int? trimestre, String? uf, String? modalidade}) async {
    if (ano != null) {
      _ano = ano;
      final tris = trimestresDoAno(ano);
      if (tris.isNotEmpty && !tris.contains(_trimestre ?? trimestre)) _trimestre = tris.last;
    }
    if (trimestre != null) _trimestre = trimestre;
    if (uf != null) _uf = uf;
    if (modalidade != null) _modalidade = modalidade;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _painel = await _repository.painel(ano: _ano, trimestre: _trimestre, uf: _uf, modalidade: _modalidade);
      _ano = _painel!.periodo.ano;
      _trimestre = _painel!.periodo.trimestre;
    } on ApiException catch (e) {
      // Trimestre padrão sem dados para o ano: recai no período mais recente disponível.
      if (e.statusCode == 404 && (_ano != null || _trimestre != null) && _painel == null) {
        _ano = null;
        _trimestre = null;
        _isLoading = false;
        return carregar();
      }
      _error = e.message;
    } catch (e) {
      _error = 'Erro ao carregar o painel: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
