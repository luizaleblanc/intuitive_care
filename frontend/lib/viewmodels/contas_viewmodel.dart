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
  int? _ano;
  int? _trimestre;
  String _grupo = '';

  ContasModel? get contas => _contas;
  bool get isLoading => _isLoading;
  bool get isAuditing => _isAuditing;
  String? get error => _error;
  int? get ano => _ano ?? _contas?.periodo.ano;
  int? get trimestre => _trimestre ?? _contas?.periodo.trimestre;
  String get grupo => _grupo;

  List<int> get anosDisponiveis =>
      (_contas?.periodos.map((p) => p.ano).toSet().toList() ?? <int>[])..sort((a, b) => b.compareTo(a));

  List<int> trimestresDoAno(int? ano) =>
      (_contas?.periodos.where((p) => p.ano == ano).map((p) => p.trimestre).toList() ?? <int>[])..sort();

  void reset() {
    _contas = null;
    _ano = null;
    _trimestre = null;
    _grupo = '';
    _error = null;
  }

  Future<void> carregar({int? ano, int? trimestre, String? grupo}) async {
    if (ano != null) {
      _ano = ano;
      final tris = trimestresDoAno(ano);
      if (tris.isNotEmpty && !tris.contains(_trimestre)) _trimestre = tris.last;
    }
    if (trimestre != null) _trimestre = trimestre;
    if (grupo != null) _grupo = grupo;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _contas = await _repository.contas(ano: _ano, trimestre: _trimestre, grupo: _grupo);
      _ano = _contas!.periodo.ano;
      _trimestre = _contas!.periodo.trimestre;
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
    if (c == null) return null;
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
