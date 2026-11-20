import '../models/analitico_model.dart';
import '../models/explorar_model.dart';
import '../services/analitico_service.dart';

/// Intermedia ViewModels e o serviço HTTP dos indicadores analíticos.
class AnaliticoRepository {
  final AnaliticoService _service;

  AnaliticoRepository(this._service);

  Future<PainelModel> painel({
    int? ano,
    int? trimestre,
    String uf = '',
    String modalidade = '',
    Iterable<int>? anos,
    Iterable<int>? trimestres,
    Iterable<String>? ufs,
    Iterable<String>? modalidades,
  }) async =>
      PainelModel.fromJson(await _service.fetchPainel(
        ano: ano,
        trimestre: trimestre,
        uf: uf,
        modalidade: modalidade,
        anos: anos,
        trimestres: trimestres,
        ufs: ufs,
        modalidades: modalidades,
      ));

  Future<ContasModel> contas({
    int? ano,
    int? trimestre,
    String grupo = '',
    Iterable<int>? anos,
    Iterable<int>? trimestres,
    Iterable<String>? grupos,
  }) async =>
      ContasModel.fromJson(await _service.fetchContas(
        ano: ano,
        trimestre: trimestre,
        grupo: grupo,
        anos: anos,
        trimestres: trimestres,
        grupos: grupos,
      ));

  Future<ExplorarModel> explorar(Map<String, String> consulta) async =>
      ExplorarModel.fromJson(await _service.fetchExplorar(consulta));

  Future<String> auditarLote(int ano, int trimestre) async =>
      ((await _service.auditarLote(ano, trimestre))['mensagem'] ?? 'Lote auditado').toString();
}
