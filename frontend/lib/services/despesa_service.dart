import '../models/despesa_model.dart';
import 'api_client.dart';

/// Serviço de comunicação HTTP para o CRUD de despesas na API Flask.
class DespesaService {
  final ApiClient _client;

  DespesaService(this._client);

  Future<Map<String, dynamic>> fetchDespesas({
    int page = 1,
    int limit = 20,
    String regAns = '',
    int? ano,
    int? trimestre,
  }) async {
    final res = await _client.get('/despesas', query: {
      'page': page.toString(),
      'limit': limit.toString(),
      if (regAns.isNotEmpty) 'reg_ans': regAns,
      if (ano != null) 'ano': ano.toString(),
      if (trimestre != null) 'trimestre': trimestre.toString(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> createDespesa(DespesaModel despesa) async {
    final res = await _client.post('/despesas', body: despesa.toJson());
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateDespesa(int id, DespesaModel despesa) async {
    final res = await _client.put('/despesas/$id', body: despesa.toJson());
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> deleteDespesa(int id) async {
    final res = await _client.delete('/despesas/$id');
    return Map<String, dynamic>.from(res as Map);
  }
}
