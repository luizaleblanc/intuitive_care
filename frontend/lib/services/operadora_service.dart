import '../models/operadora_model.dart';
import 'api_client.dart';

/// Comunicação HTTP com /api/operadoras.
class OperadoraService {
  final ApiClient _client;

  OperadoraService(this._client);

  Future<Map<String, dynamic>> fetchOperadoras({
    int page = 1,
    int limit = 15,
    String search = '',
    String uf = '',
    String modalidade = '',
  }) async {
    final res = await _client.get('/operadoras', query: {
      'page': page.toString(),
      'limit': limit.toString(),
      'search': search,
      'uf': uf,
      'modalidade': modalidade,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> fetchResumo() async =>
      Map<String, dynamic>.from(await _client.get('/operadoras/resumo') as Map);

  Future<String> exportarCsv({String search = '', String modalidade = ''}) =>
      _client.getText('/operadoras/exportar.csv', query: {'search': search, 'modalidade': modalidade});

  Future<Map<String, dynamic>> createOperadora(OperadoraModel operadora) async =>
      Map<String, dynamic>.from(await _client.post('/operadoras', body: operadora.toJson()) as Map);

  Future<Map<String, dynamic>> updateOperadora(String registroAns, Map<String, dynamic> campos) async =>
      Map<String, dynamic>.from(await _client.put('/operadoras/$registroAns', body: campos) as Map);

  Future<Map<String, dynamic>> updateStatus(String registroAns, String status) async =>
      Map<String, dynamic>.from(await _client.patch('/operadoras/$registroAns/status', body: {'status': status}) as Map);
}
