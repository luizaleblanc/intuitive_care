import 'api_client.dart';

/// Serviço de comunicação HTTP para indicadores analíticos do dashboard.
class EstatisticaService {
  final ApiClient _client;

  EstatisticaService(this._client);

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final res = await _client.get('/estatisticas');
    return Map<String, dynamic>.from(res as Map);
  }
}
