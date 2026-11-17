import 'package:flutter/foundation.dart';

import '../models/despesa_model.dart';
import '../repositories/despesa_repository.dart';
import '../services/api_client.dart';

/// ViewModel responsável pelo gerenciamento de estado e CRUD de Despesas.
class DespesaViewModel extends ChangeNotifier {
  final DespesaRepository _repository;

  List<DespesaModel> _despesas = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  String _regAnsFilter = '';
  int? _anoFilter;
  int? _trimestreFilter;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;

  DespesaViewModel(this._repository);

  List<DespesaModel> get despesas => _despesas;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String get regAnsFilter => _regAnsFilter;
  int? get anoFilter => _anoFilter;
  int? get trimestreFilter => _trimestreFilter;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRecords => _totalRecords;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadDespesas({
    int? page,
    String? regAns,
    int? ano,
    int? trimestre,
    bool clearFilters = false,
  }) async {
    if (clearFilters) {
      _regAnsFilter = '';
      _anoFilter = null;
      _trimestreFilter = null;
      _currentPage = 1;
    } else {
      if (page != null) _currentPage = page;
      if (regAns != null) {
        _regAnsFilter = regAns;
        _currentPage = page ?? 1;
      }
      if (ano != null) {
        _anoFilter = ano == 0 ? null : ano;
        _currentPage = page ?? 1;
      }
      if (trimestre != null) {
        _trimestreFilter = trimestre == 0 ? null : trimestre;
        _currentPage = page ?? 1;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.listDespesas(
        page: _currentPage,
        limit: 15,
        regAns: _regAnsFilter,
        ano: _anoFilter,
        trimestre: _trimestreFilter,
      );
      _despesas = result.data;
      _totalRecords = result.total;
      _currentPage = result.page;
      _totalPages = result.totalPages;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Erro ao carregar despesas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDespesa(DespesaModel despesa) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createDespesa(despesa);
      await loadDespesas(page: 1);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao lançar despesa: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateDespesa(int id, DespesaModel despesa) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateDespesa(id, despesa);
      await loadDespesas(page: _currentPage);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar despesa: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDespesa(int id) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteDespesa(id);
      await loadDespesas(page: _currentPage);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao excluir despesa: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
