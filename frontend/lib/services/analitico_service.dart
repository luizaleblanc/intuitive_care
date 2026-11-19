import 'api_client.dart';

/// Comunicação HTTP com /api/painel e /api/contas.
class AnaliticoService {
  final ApiClient _client;

  AnaliticoService(this._client);

  Future<Map<String, dynamic>> fetchPainel({int? ano, int? trimestre, String uf = '', String modalidade = ''}) async =>
      Map<String, dynamic>.from(await _client.get('/painel', query: {
        'ano': ano?.toString() ?? '',
        'trimestre': trimestre?.toString() ?? '',
        'uf': uf,
        'modalidade': modalidade,
      }) as Map);

  Future<Map<String, dynamic>> fetchContas({int? ano, int? trimestre, String grupo = ''}) async =>
      Map<String, dynamic>.from(await _client.get('/contas', query: {
        'ano': ano?.toString() ?? '',
        'trimestre': trimestre?.toString() ?? '',
        'grupo': grupo,
      }) as Map);

  Future<Map<String, dynamic>> fetchExplorar(Map<String, String> consulta) async =>
      Map<String, dynamic>.from(await _client.get('/explorar', query: consulta) as Map);

  Future<Map<String, dynamic>> auditarLote(int ano, int trimestre) async =>
      Map<String, dynamic>.from(await _client.post('/contas/lotes/$ano/$trimestre/auditar') as Map);
}
