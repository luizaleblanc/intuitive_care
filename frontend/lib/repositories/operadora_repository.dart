import '../models/despesa_model.dart';
import '../models/operadora_model.dart';
import '../models/paginated_response.dart';
import '../services/operadora_service.dart';

/// Repositório intermediário para operações CRUD de operadoras.
class OperadoraRepository {
  final OperadoraService _service;

  OperadoraRepository(this._service);

  Future<PaginatedResponse<OperadoraModel>> listOperadoras({
    int page = 1,
    int limit = 10,
    String search = '',
    String uf = '',
  }) async {
    final json = await _service.fetchOperadoras(
      page: page,
      limit: limit,
      search: search,
      uf: uf,
    );
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

  Future<OperadoraModel> getOperadora(String identifier) async {
    final json = await _service.fetchOperadoraByIdentifier(identifier);
    return OperadoraModel.fromJson(json);
  }

  Future<List<DespesaModel>> getDespesasOperadora(String identifier) async {
    final list = await _service.fetchDespesasByOperadora(identifier);
    return list
        .map((item) => DespesaModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<OperadoraModel> createOperadora(OperadoraModel operadora) async {
    final json = await _service.createOperadora(operadora);
    return OperadoraModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<OperadoraModel> updateOperadora(String registroAns, OperadoraModel operadora) async {
    final json = await _service.updateOperadora(registroAns, operadora);
    return OperadoraModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<void> deleteOperadora(String registroAns, {bool force = false}) async {
    await _service.deleteOperadora(registroAns, force: force);
  }
}
