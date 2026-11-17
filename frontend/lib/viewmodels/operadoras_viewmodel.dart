import 'package:flutter/foundation.dart';

import '../models/operadora_model.dart';
import '../repositories/operadora_repository.dart';
import '../services/api_client.dart';

/// Estado da tela Operadoras ANS (lista paginada, resumo e ações do Administrador).
class OperadorasViewModel extends ChangeNotifier {
  final OperadoraRepository _repository;

  OperadorasViewModel(this._repository);

  List<OperadoraModel> _items = [];
  OperadorasResumo _resumo = const OperadorasResumo();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _search = '';
  String _modalidade = '';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  List<OperadoraModel> get items => _items;
  OperadorasResumo get resumo => _resumo;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get search => _search;
  String get modalidade => _modalidade;
  int get page => _page;
  int get totalPages => _totalPages;
  int get total => _total;

  void reset() {
    _items = [];
    _resumo = const OperadorasResumo();
    _search = '';
    _modalidade = '';
    _page = 1;
    _error = null;
  }

  Future<void> carregar({String? search, String? modalidade, int? page, bool resumo = false}) async {
    if (search != null) {
      _search = search;
      _page = 1;
    }
    if (modalidade != null) {
      _modalidade = modalidade;
      _page = 1;
    }
    if (page != null) _page = page;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final futures = await Future.wait([
        _repository.listOperadoras(page: _page, search: _search, modalidade: _modalidade),
        if (resumo || _resumo.modalidades.isEmpty) _repository.resumo(),
      ]);
      final lista = futures[0] as dynamic;
      _items = List<OperadoraModel>.from(lista.data as List);
      _total = lista.total as int;
      _totalPages = lista.totalPages as int;
      if (futures.length > 1) _resumo = futures[1] as OperadorasResumo;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erro ao carregar operadoras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OperadoraModel?> salvar(OperadoraModel original, Map<String, dynamic> campos) =>
      _executar(() => _repository.updateOperadora(original.registroAns, campos));

  Future<OperadoraModel?> criar(OperadoraModel nova) => _executar(() => _repository.createOperadora(nova));

  Future<OperadoraModel?> alterarStatus(OperadoraModel op, String status) =>
      _executar(() => _repository.updateStatus(op.registroAns, status));

  Future<List<List<String>>> exportar() => _repository.exportar(search: _search, modalidade: _modalidade);

  Future<OperadoraModel?> _executar(Future<OperadoraModel> Function() acao) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final result = await acao();
      await carregar(resumo: true);
      return result;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
