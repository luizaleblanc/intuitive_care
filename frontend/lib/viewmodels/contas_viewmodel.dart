import 'package:flutter/foundation.dart';

import '../models/analitico_model.dart';
import '../repositories/analitico_repository.dart';
import '../services/api_client.dart';

/// Estado da tela Despesas Contábeis (plano de contas ANS do setor).
class ContasViewModel extends ChangeNotifier {
  final AnaliticoRepository _repository;

  ContasViewModel(this._repository);

  ContasModel? _contas;
  bool _isLoading = false;
  bool _isAuditing = false;
  String? _error;
  Set<int> _anos = {};
  Set<int> _trimestres = {};
  Set<String> _grupos = {};

  ContasModel? get contas => _contas;
  bool get isLoading => _isLoading;
  bool get isAuditing => _isAuditing;
  String? get error => _error;
  Set<int> get anos => _anos.isNotEmpty
      ? _anos
      : (_contas != null ? _contas!.periodosSelecionados.map((p) => p.ano).toSet() : const {});
  Set<int> get trimestres => _trimestres.isNotEmpty
      ? _trimestres
      : (_contas != null ? _contas!.periodosSelecionados.map((p) => p.trimestre).toSet() : const {});
  Set<String> get grupos => _grupos;
  bool get podeAuditar => (_contas?.periodosSelecionados.length ?? 0) == 1;
  int? get ano => anos.isEmpty ? _contas?.periodo.ano : (anos.toList()..sort()).last;
  int? get trimestre => trimestres.isEmpty ? _contas?.periodo.trimestre : (trimestres.toList()..sort()).last;
  String get grupo => (_grupos.toList()..sort()).join(',');

  List<int> get anosDisponiveis =>
      (_contas?.periodos.map((p) => p.ano).toSet().toList() ?? <int>[])..sort((a, b) => b.compareTo(a));

  List<int> trimestresDoAno(int? ano) =>
      (_contas?.periodos.where((p) => p.ano == ano).map((p) => p.trimestre).toSet().toList() ?? <int>[])..sort();

  List<int> trimestresDosAnos(Set<int> selecionados) {
    if (selecionados.isEmpty) {
      return (_contas?.periodos.map((p) => p.trimestre).toSet().toList() ?? <int>[])..sort();
    }
    return (_contas?.periodos.where((p) => selecionados.contains(p.ano)).map((p) => p.trimestre).toSet().toList() ??
        <int>[])
      ..sort();
  }

  void reset() {
    _contas = null;
    _anos = {};
    _trimestres = {};
    _grupos = {};
    _error = null;
  }

  Future<void> carregar({
    int? ano,
    int? trimestre,
    String? grupo,
    Set<int>? anos,
    Set<int>? trimestres,
    Set<String>? grupos,
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
      if (tris.isNotEmpty && !_trimestres.any(tris.contains)) _trimestres = {tris.last};
    }
    if (trimestres != null) {
      _trimestres = Set<int>.from(trimestres);
    } else if (trimestre != null) {
      _trimestres = {trimestre};
    }
    if (grupos != null) {
      _grupos = Set<String>.from(grupos);
    } else if (grupo != null) {
      _grupos = grupo.isEmpty ? {} : grupo.split(',').where((e) => e.isNotEmpty).toSet();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _contas = await _repository.contas(
        anos: _anos.toList()..sort(),
        trimestres: _trimestres.toList()..sort(),
        grupos: _grupos.toList()..sort(),
      );
      _anos = _contas!.periodosSelecionados.map((p) => p.ano).toSet();
      _trimestres = _contas!.periodosSelecionados.map((p) => p.trimestre).toSet();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erro ao carregar o plano de contas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> auditarLote() async {
    final c = _contas;
    if (c == null || !podeAuditar) return null;
    _isAuditing = true;
    notifyListeners();
    try {
      final msg = await _repository.auditarLote(c.periodo.ano, c.periodo.trimestre);
      await carregar();
      return msg;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } finally {
      _isAuditing = false;
      notifyListeners();
    }
  }
}
