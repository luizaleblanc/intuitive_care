import 'package:flutter/foundation.dart';

import '../models/despesa_model.dart';
import '../models/operadora_model.dart';
import '../repositories/operadora_repository.dart';
import '../services/api_client.dart';

/// ViewModel responsável pelo gerenciamento de estado e CRUD de Operadoras.
class OperadoraViewModel extends ChangeNotifier {
  final OperadoraRepository _repository;

  List<OperadoraModel> _operadoras = [];
  OperadoraModel? _selectedOperadora;
  List<DespesaModel> _selectedDespesas = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _ufFilter = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;

  OperadoraViewModel(this._repository);

  List<OperadoraModel> get operadoras => _operadoras;
  OperadoraModel? get selectedOperadora => _selectedOperadora;
  List<DespesaModel> get selectedDespesas => _selectedDespesas;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get ufFilter => _ufFilter;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRecords => _totalRecords;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadOperadoras({int? page, String? search, String? uf}) async {
    if (page != null) _currentPage = page;
    if (search != null) {
      _searchQuery = search;
      _currentPage = page ?? 1;
    }
    if (uf != null) {
      _ufFilter = uf;
      _currentPage = page ?? 1;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.listOperadoras(
        page: _currentPage,
        limit: 8,
        search: _searchQuery,
        uf: _ufFilter,
      );
      _operadoras = result.data;
      _totalRecords = result.total;
      _currentPage = result.page;
      _totalPages = result.totalPages;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Erro ao carregar operadoras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOperadoraDetail(String identifier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final op = await _repository.getOperadora(identifier);
      final despesas = await _repository.getDespesasOperadora(op.registroAns);
      _selectedOperadora = op;
      _selectedDespesas = despesas;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Erro ao carregar detalhes da operadora: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createOperadora(OperadoraModel operadora) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createOperadora(operadora);
      await loadOperadoras(page: 1);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao cadastrar operadora: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateOperadora(String registroAns, OperadoraModel operadora) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateOperadora(registroAns, operadora);
      _selectedOperadora = updated;
      await loadOperadoras(page: _currentPage);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar operadora: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<({bool success, bool requiresForce, String? message})> deleteOperadora(
    String registroAns, {
    bool force = false,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteOperadora(registroAns, force: force);
      await loadOperadoras(page: 1);
      return (success: true, requiresForce: false, message: 'Operadora excluída com sucesso.');
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return (
        success: false,
        requiresForce: e.statusCode == 409,
        message: e.message,
      );
    } catch (e) {
      _errorMessage = 'Erro ao excluir operadora: $e';
      return (success: false, requiresForce: false, message: _errorMessage);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
