import '../models/estatistica_model.dart';
import '../services/estatistica_service.dart';

/// Repositório para indicadores consolidados do painel principal.
class EstatisticaRepository {
  final EstatisticaService _service;

  EstatisticaRepository(this._service);

  Future<EstatisticaDashboardModel> getDashboard() async {
    final json = await _service.fetchDashboardStats();
    return EstatisticaDashboardModel.fromJson(json);
  }
}
