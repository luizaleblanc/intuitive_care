import 'dart:typed_data';

import 'api_client.dart';

/// Comunicação HTTP com /api/painel e /api/contas.
class AnaliticoService {
  final ApiClient _client;

  AnaliticoService(this._client);

  Future<Map<String, dynamic>> fetchPainel({
    int? ano,
    int? trimestre,
    String uf = '',
    String modalidade = '',
    Iterable<int>? anos,
    Iterable<int>? trimestres,
    Iterable<String>? ufs,
    Iterable<String>? modalidades,
  }) async {
    final anosList = anos?.toList() ?? (ano != null ? [ano] : <int>[]);
    final trisList = trimestres?.toList() ?? (trimestre != null ? [trimestre] : <int>[]);
    final ufsList = ufs?.where((u) => u.isNotEmpty).toList() ?? (uf.isNotEmpty ? [uf] : <String>[]);
    final modsList = modalidades?.where((m) => m.isNotEmpty).toList() ?? (modalidade.isNotEmpty ? [modalidade] : <String>[]);
    return Map<String, dynamic>.from(await _client.get('/painel', query: {
      'ano': anosList.join(','),
      'trimestre': trisList.join(','),
      'uf': ufsList.join(','),
      'modalidade': modsList.join(','),
    }) as Map);
  }

  Future<Map<String, dynamic>> fetchContas({
    int? ano,
    int? trimestre,
    String grupo = '',
    Iterable<int>? anos,
    Iterable<int>? trimestres,
    Iterable<String>? grupos,
  }) async {
    final anosList = anos?.toList() ?? (ano != null ? [ano] : <int>[]);
    final trisList = trimestres?.toList() ?? (trimestre != null ? [trimestre] : <int>[]);
    final gruposList = grupos?.where((g) => g.isNotEmpty).toList() ?? (grupo.isNotEmpty ? [grupo] : <String>[]);
    return Map<String, dynamic>.from(await _client.get('/contas', query: {
      'ano': anosList.join(','),
      'trimestre': trisList.join(','),
      'grupo': gruposList.join(','),
    }) as Map);
  }

  Future<Map<String, dynamic>> fetchExplorar(Map<String, String> consulta) async =>
      Map<String, dynamic>.from(await _client.get('/explorar', query: consulta) as Map);

  Future<Map<String, dynamic>> auditarLote(int ano, int trimestre) async =>
      Map<String, dynamic>.from(await _client.post('/contas/lotes/$ano/$trimestre/auditar') as Map);

  Future<({Uint8List bytes, String? filename})> exportarRelatorioBytes(Map<String, dynamic> payload) =>
      _client.postBytes('/relatorios/exportar', body: payload);

  Future<Map<String, dynamic>> exportarRelatorioJson(Map<String, dynamic> payload) async =>
      Map<String, dynamic>.from(
        await _client.post(
          '/relatorios/exportar',
          body: {...payload, 'formato': 'JSON'},
          timeout: const Duration(seconds: 60),
        ) as Map,
      );
}
