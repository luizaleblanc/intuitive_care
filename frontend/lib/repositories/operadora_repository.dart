import '../models/operadora_model.dart';
import '../models/paginated_response.dart';
import '../services/operadora_service.dart';

/// Intermedia ViewModels e o serviço HTTP de operadoras.
class OperadoraRepository {
  final OperadoraService _service;

  OperadoraRepository(this._service);

  Future<PaginatedResponse<OperadoraModel>> listOperadoras({
    int page = 1,
    int limit = 15,
    String search = '',
    String modalidade = '',
  }) async {
    final json = await _service.fetchOperadoras(page: page, limit: limit, search: search, modalidade: modalidade);
    final items = (json['data'] as List<dynamic>? ?? [])
        .map((item) => OperadoraModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return PaginatedResponse<OperadoraModel>(
      data: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? page,
      limit: (json['limit'] as num?)?.toInt() ?? limit,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<OperadorasResumo> resumo() async => OperadorasResumo.fromJson(await _service.fetchResumo());

  /// Linhas do CSV gerado pela API (cabeçalho na primeira linha).
  Future<List<List<String>>> exportar({String search = '', String modalidade = ''}) async {
    final texto = (await _service.exportarCsv(search: search, modalidade: modalidade)).replaceFirst('﻿', '');
    return texto
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.split(';'))
        .toList();
  }

  Future<OperadoraModel> createOperadora(OperadoraModel operadora) async {
    final json = await _service.createOperadora(operadora);
    return OperadoraModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<OperadoraModel> updateOperadora(String registroAns, Map<String, dynamic> campos) async {
    final json = await _service.updateOperadora(registroAns, campos);
    return OperadoraModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<OperadoraModel> updateStatus(String registroAns, String status) async {
    final json = await _service.updateStatus(registroAns, status);
    return OperadoraModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }
}
