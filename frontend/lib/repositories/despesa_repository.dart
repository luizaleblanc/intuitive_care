import '../models/despesa_model.dart';
import '../models/paginated_response.dart';
import '../services/despesa_service.dart';

/// Repositório intermediário para operações CRUD de despesas.
class DespesaRepository {
  final DespesaService _service;

  DespesaRepository(this._service);

  Future<PaginatedResponse<DespesaModel>> listDespesas({
    int page = 1,
    int limit = 20,
    String regAns = '',
    int? ano,
    int? trimestre,
  }) async {
    final json = await _service.fetchDespesas(
      page: page,
      limit: limit,
      regAns: regAns,
      ano: ano,
      trimestre: trimestre,
    );
    final items = (json['data'] as List<dynamic>? ?? [])
        .map((item) => DespesaModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    return PaginatedResponse<DespesaModel>(
      data: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? page,
      limit: (json['limit'] as num?)?.toInt() ?? limit,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<DespesaModel> createDespesa(DespesaModel despesa) async {
    final json = await _service.createDespesa(despesa);
    return DespesaModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<DespesaModel> updateDespesa(int id, DespesaModel despesa) async {
    final json = await _service.updateDespesa(id, despesa);
    return DespesaModel.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<void> deleteDespesa(int id) async {
    await _service.deleteDespesa(id);
  }
}
