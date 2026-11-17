import '../models/operadora_model.dart';
import 'api_client.dart';

/// Serviço de comunicação HTTP para o CRUD de operadoras na API Flask.
class OperadoraService {
  final ApiClient _client;

  OperadoraService(this._client);

  Future<Map<String, dynamic>> fetchOperadoras({
    int page = 1,
    int limit = 10,
    String search = '',
    String uf = '',
  }) async {
    final res = await _client.get('/operadoras', query: {
      'page': page.toString(),
      'limit': limit.toString(),
      'search': search,
      'uf': uf,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> fetchOperadoraByIdentifier(String identifier) async {
    final res = await _client.get('/operadoras/$identifier');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<dynamic>> fetchDespesasByOperadora(String identifier) async {
    final res = await _client.get('/operadoras/$identifier/despesas');
    return List<dynamic>.from(res as List);
  }

  Future<Map<String, dynamic>> createOperadora(OperadoraModel operadora) async {
    final res = await _client.post('/operadoras', body: operadora.toJson());
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateOperadora(String registroAns, OperadoraModel operadora) async {
    final res = await _client.put('/operadoras/$registroAns', body: operadora.toJson());
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> deleteOperadora(String registroAns, {bool force = false}) async {
    final res = await _client.delete(
      '/operadoras/$registroAns',
      query: force ? {'force': 'true'} : null,
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
