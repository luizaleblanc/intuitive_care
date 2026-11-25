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
  Set<String> _modalidades = {};
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  List<OperadoraModel> get items => _items;
  OperadorasResumo get resumo => _resumo;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get search => _search;
  Set<String> get modalidades => _modalidades;
  String get modalidade => (_modalidades.toList()..sort()).join(',');
  int get page => _page;
  int get totalPages => _totalPages;
  int get total => _total;

  void reset() {
    _items = [];
    _resumo = const OperadorasResumo();
    _search = '';
    _modalidades = {};
    _page = 1;
    _error = null;
  }

  /// Carrega apenas os metadados de filtro (UFs e modalidades) sem consultar a tabela paginada.
  Future<void> carregarResumo() async {
    if (_resumo.ufs.isNotEmpty) return;
    try {
      _resumo = await _repository.resumo();
      notifyListeners();
    } on ApiException {
      // Filtros do painel permanecem funcionais mesmo sem o resumo auxiliar.
    }
  }

  Future<void> carregar({
    String? search,
    String? modalidade,
    Set<String>? modalidades,
    int? page,
    bool resumo = false,
  }) async {
    if (search != null) {
      _search = search;
      _page = 1;
    }
    if (modalidades != null) {
      _modalidades = Set<String>.from(modalidades);
      _page = 1;
    } else if (modalidade != null) {
      _modalidades = modalidade.isEmpty ? {} : modalidade.split(',').where((e) => e.isNotEmpty).toSet();
      _page = 1;
    }
    if (page != null) _page = page;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final futures = await Future.wait([
        _repository.listOperadoras(page: _page, search: _search, modalidade: this.modalidade),
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

  Future<List<List<String>>> exportar() => _repository.exportar(search: _search, modalidade: modalidade);

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
