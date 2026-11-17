import 'package:flutter/foundation.dart';

import '../models/estatistica_model.dart';
import '../repositories/estatistica_repository.dart';
import '../services/api_client.dart';

/// ViewModel responsável pelos indicadores do painel principal (Dashboard).
class DashboardViewModel extends ChangeNotifier {
  final EstatisticaRepository _repository;

  EstatisticaDashboardModel? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardViewModel(this._repository);

  EstatisticaDashboardModel? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stats = await _repository.getDashboard();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Erro ao carregar estatísticas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
