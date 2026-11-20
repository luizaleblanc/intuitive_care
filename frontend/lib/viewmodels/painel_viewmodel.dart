import 'package:flutter/foundation.dart';

import '../models/analitico_model.dart';
import '../repositories/analitico_repository.dart';
import '../services/api_client.dart';

/// Estado do Painel Geral. Filtros de período em dois campos com múltipla escolha: Ano(s) + Trimestre(s).
class PainelViewModel extends ChangeNotifier {
  final AnaliticoRepository _repository;

  PainelViewModel(this._repository);

  PainelModel? _painel;
  bool _isLoading = false;
  String? _error;
  Set<int> _anos = {};
  Set<int> _trimestres = {};
  Set<String> _ufs = {};
  Set<String> _modalidades = {};
  bool _preferenciasAplicadas = false;

  PainelModel? get painel => _painel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<int> get anos => _anos.isNotEmpty
      ? _anos
      : (_painel != null ? _painel!.periodosSelecionados.map((p) => p.ano).toSet() : const {});
  Set<int> get trimestres => _trimestres.isNotEmpty
      ? _trimestres
      : (_painel != null ? _painel!.periodosSelecionados.map((p) => p.trimestre).toSet() : const {});
  Set<String> get ufs => _ufs;
  Set<String> get modalidades => _modalidades;
  int? get ano => anos.isEmpty ? _painel?.periodo.ano : (anos.toList()..sort()).last;
  int? get trimestre => trimestres.isEmpty ? _painel?.periodo.trimestre : (trimestres.toList()..sort()).last;
  String get uf => (_ufs.toList()..sort()).join(',');
  String get modalidade => (_modalidades.toList()..sort()).join(',');

  /// Anos com dados carregados (do banco).
  List<int> get anosDisponiveis =>
      (_painel?.periodos.map((p) => p.ano).toSet().toList() ?? <int>[])..sort((a, b) => b.compareTo(a));

  /// Trimestres disponíveis para um ano específico.
  List<int> trimestresDoAno(int? ano) =>
      (_painel?.periodos.where((p) => p.ano == ano).map((p) => p.trimestre).toSet().toList() ?? <int>[])..sort();

  /// Trimestres disponíveis para o conjunto de anos selecionados.
  List<int> trimestresDosAnos(Set<int> selecionados) {
    if (selecionados.isEmpty) {
      return (_painel?.periodos.map((p) => p.trimestre).toSet().toList() ?? <int>[])..sort();
    }
    return (_painel?.periodos.where((p) => selecionados.contains(p.ano)).map((p) => p.trimestre).toSet().toList() ??
        <int>[])
      ..sort();
  }

  /// Aplica UF e trimestre padrão das preferências do usuário (apenas uma vez por sessão).
  void aplicarPreferencias({String? ufPadrao, int? trimestrePadrao}) {
    if (_preferenciasAplicadas) return;
    _preferenciasAplicadas = true;
    _ufs = (ufPadrao ?? '').isEmpty ? {} : {ufPadrao!};
    _trimestres = trimestrePadrao == null ? {} : {trimestrePadrao};
  }

  void reset() {
    _painel = null;
    _anos = {};
    _trimestres = {};
    _ufs = {};
    _modalidades = {};
    _preferenciasAplicadas = false;
    _error = null;
  }

  Future<void> carregar({
    int? ano,
    int? trimestre,
    String? uf,
    String? modalidade,
    Set<int>? anos,
    Set<int>? trimestres,
    Set<String>? ufs,
    Set<String>? modalidades,
  }) async {
    if (anos != null) {
      _anos = Set<int>.from(anos);
      final tris = trimestresDosAnos(_anos);
      if (tris.isNotEmpty) {
        final validos = _trimestres.where(tris.contains).toSet();
        _trimestres = validos.isNotEmpty ? validos : {tris.last};
      }
    } else if (ano != null) {
      _anos = {ano};
      final tris = trimestresDoAno(ano);
      final atual = trimestre != null ? {trimestre} : _trimestres;
      if (tris.isNotEmpty && !atual.any(tris.contains)) _trimestres = {tris.last};
    }
    if (trimestres != null) {
      _trimestres = Set<int>.from(trimestres);
    } else if (trimestre != null) {
      _trimestres = {trimestre};
    }
    if (ufs != null) {
      _ufs = Set<String>.from(ufs);
    } else if (uf != null) {
      _ufs = uf.isEmpty ? {} : uf.split(',').where((e) => e.isNotEmpty).toSet();
    }
    if (modalidades != null) {
      _modalidades = Set<String>.from(modalidades);
    } else if (modalidade != null) {
      _modalidades = modalidade.isEmpty ? {} : modalidade.split(',').where((e) => e.isNotEmpty).toSet();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _painel = await _repository.painel(
        anos: _anos.toList()..sort(),
        trimestres: _trimestres.toList()..sort(),
        ufs: _ufs.toList()..sort(),
        modalidades: _modalidades.toList()..sort(),
      );
      _anos = _painel!.periodosSelecionados.map((p) => p.ano).toSet();
      _trimestres = _painel!.periodosSelecionados.map((p) => p.trimestre).toSet();
    } on ApiException catch (e) {
      // Trimestre padrão sem dados para o ano: recai no período mais recente disponível.
      if (e.statusCode == 404 && (_anos.isNotEmpty || _trimestres.isNotEmpty) && _painel == null) {
        _anos = {};
        _trimestres = {};
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
