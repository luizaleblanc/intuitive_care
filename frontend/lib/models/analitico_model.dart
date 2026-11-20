double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class Periodo {
  final int ano;
  final int trimestre;
  const Periodo(this.ano, this.trimestre);

  factory Periodo.fromJson(Map<String, dynamic> j) => Periodo(_i(j['ano']), _i(j['trimestre']));

  @override
  bool operator ==(Object other) => other is Periodo && other.ano == ano && other.trimestre == trimestre;

  @override
  int get hashCode => Object.hash(ano, trimestre);
}

class SerieTrimestral {
  final int ano;
  final int trimestre;
  final double valor;
  const SerieTrimestral(this.ano, this.trimestre, this.valor);

  factory SerieTrimestral.fromJson(Map<String, dynamic> j) =>
      SerieTrimestral(_i(j['ano']), _i(j['trimestre']), _d(j['valor']) ?? 0);
}

class ModalidadeFatia {
  final String modalidade;
  final double valor;
  final double pct;
  const ModalidadeFatia(this.modalidade, this.valor, this.pct);
}

class RankingItem {
  final String registroAns;
  final String nome;
  final String uf;
  final double valor;
  const RankingItem(this.registroAns, this.nome, this.uf, this.valor);
}

/// Resposta de GET /api/painel (visões Administrador e Colaborador).
class PainelModel {
  final Periodo periodo;
  final List<Periodo> periodos;
  final List<Periodo> periodosSelecionados;

  // Administrador
  final double totalDespesas;
  final double? totalDespesasAnterior;
  final int registrosExtraidos;
  final int? registrosExtraidosAnterior;
  final int operadorasAtivas;
  final int operadorasComDemonstracao;
  final List<SerieTrimestral> serieAdmin;
  final List<ModalidadeFatia> modalidades;

  // Colaborador
  final double despesasMh;
  final double? despesasMhAnterior;
  final double? sinistralidade;
  final double? sinistralidadeAnterior;
  final int beneficiarios;
  final int? beneficiariosAnterior;
  final double? ticketMedio;
  final double? ticketMedioAnterior;
  final List<RankingItem> ranking;
  final List<SerieTrimestral> serieColaborador;

  const PainelModel({
    required this.periodo,
    required this.periodos,
    this.periodosSelecionados = const [],
    required this.totalDespesas,
    this.totalDespesasAnterior,
    required this.registrosExtraidos,
    this.registrosExtraidosAnterior,
    required this.operadorasAtivas,
    required this.operadorasComDemonstracao,
    required this.serieAdmin,
    required this.modalidades,
    required this.despesasMh,
    this.despesasMhAnterior,
    this.sinistralidade,
    this.sinistralidadeAnterior,
    required this.beneficiarios,
    this.beneficiariosAnterior,
    this.ticketMedio,
    this.ticketMedioAnterior,
    required this.ranking,
    required this.serieColaborador,
  });

  factory PainelModel.fromJson(Map<String, dynamic> j) {
    final a = Map<String, dynamic>.from(j['admin'] as Map);
    final c = Map<String, dynamic>.from(j['colaborador'] as Map);
    final periodo = Periodo.fromJson(Map<String, dynamic>.from(j['periodo'] as Map));
    final selecionados = _list(j['periodos_selecionados']).map(Periodo.fromJson).toList();
    return PainelModel(
      periodo: periodo,
      periodos: _list(j['periodos']).map(Periodo.fromJson).toList(),
      periodosSelecionados: selecionados.isEmpty ? [periodo] : selecionados,
      totalDespesas: _d(a['total_despesas']) ?? 0,
      totalDespesasAnterior: _d(a['total_despesas_anterior']),
      registrosExtraidos: _i(a['registros_extraidos']),
      registrosExtraidosAnterior: (a['registros_extraidos_anterior'] as num?)?.toInt(),
      operadorasAtivas: _i(a['operadoras_ativas']),
      operadorasComDemonstracao: _i(a['operadoras_com_demonstracao']),
      serieAdmin: _list(a['serie']).map(SerieTrimestral.fromJson).toList(),
      modalidades: _list(a['modalidades'])
          .map((m) => ModalidadeFatia(m['modalidade'].toString(), _d(m['valor']) ?? 0, _d(m['pct']) ?? 0))
          .toList(),
      despesasMh: _d(c['despesas_mh']) ?? 0,
      despesasMhAnterior: _d(c['despesas_mh_anterior']),
      sinistralidade: _d(c['sinistralidade']),
      sinistralidadeAnterior: _d(c['sinistralidade_anterior']),
      beneficiarios: _i(c['beneficiarios']),
      beneficiariosAnterior: (c['beneficiarios_anterior'] as num?)?.toInt(),
      ticketMedio: _d(c['ticket_medio']),
      ticketMedioAnterior: _d(c['ticket_medio_anterior']),
      ranking: _list(c['ranking'])
          .map((r) => RankingItem(
                r['registro_ans'].toString(),
                ((r['nome_fantasia'] as String?)?.trim().isNotEmpty == true ? r['nome_fantasia'] : r['razao_social'])
                    .toString(),
                (r['uf'] ?? '').toString(),
                _d(r['valor']) ?? 0,
              ))
          .toList(),
      serieColaborador: _list(c['serie']).map(SerieTrimestral.fromJson).toList(),
    );
  }
}

class ContaLinha {
  final String codigo;
  final String descricao;
  final String grupo;
  final int nivel;
  final double valorAtual;
  final double? valorAnterior;
  const ContaLinha(this.codigo, this.descricao, this.grupo, this.nivel, this.valorAtual, this.valorAnterior);
}

class ComposicaoItem {
  final String forma;
  final double valor;
  final double pct;
  const ComposicaoItem(this.forma, this.valor, this.pct);
}

class Destaque {
  final String codigo;
  final String descricao;
  final double variacao;
  const Destaque(this.codigo, this.descricao, this.variacao);
}

class LoteInfo {
  final int registrosExtraidos;
  final int operadoras;
  final bool auditado;
  final String? auditadoPor;
  final DateTime? auditadoEm;
  const LoteInfo({
    this.registrosExtraidos = 0,
    this.operadoras = 0,
    this.auditado = false,
    this.auditadoPor,
    this.auditadoEm,
  });
}

/// Resposta de GET /api/contas (plano de contas do setor).
class ContasModel {
  final Periodo periodo;
  final Periodo periodoAnterior;
  final List<Periodo> periodos;
  final List<Periodo> periodosSelecionados;
  final List<(String, String)> grupos;
  final Map<String, (double, double?)> kpis;
  final List<ContaLinha> contas;
  final List<ComposicaoItem> composicao;
  final List<Destaque> destaques;
  final LoteInfo lote;

  const ContasModel({
    required this.periodo,
    required this.periodoAnterior,
    required this.periodos,
    this.periodosSelecionados = const [],
    required this.grupos,
    required this.kpis,
    required this.contas,
    required this.composicao,
    required this.destaques,
    required this.lote,
  });

  factory ContasModel.fromJson(Map<String, dynamic> j) {
    final kpis = <String, (double, double?)>{};
    (j['kpis'] as Map).forEach((k, v) {
      final m = Map<String, dynamic>.from(v as Map);
      kpis[k.toString()] = (_d(m['valor_atual']) ?? 0, _d(m['valor_anterior']));
    });
    final l = Map<String, dynamic>.from(j['lote'] as Map);
    final periodo = Periodo.fromJson(Map<String, dynamic>.from(j['periodo'] as Map));
    final selecionados = _list(j['periodos_selecionados']).map(Periodo.fromJson).toList();
    return ContasModel(
      periodo: periodo,
      periodoAnterior: Periodo.fromJson(Map<String, dynamic>.from(j['periodo_anterior'] as Map)),
      periodos: _list(j['periodos']).map(Periodo.fromJson).toList(),
      periodosSelecionados: selecionados.isEmpty ? [periodo] : selecionados,
      grupos: _list(j['grupos']).map((g) => (g['codigo'].toString(), g['nome'].toString())).toList(),
      kpis: kpis,
      contas: _list(j['contas'])
          .map((c) => ContaLinha(c['codigo'].toString(), c['descricao'].toString(), c['grupo'].toString(),
              _i(c['nivel']), _d(c['valor_atual']) ?? 0, _d(c['valor_anterior'])))
          .toList(),
      composicao: _list(j['composicao'])
          .map((c) => ComposicaoItem(c['forma'].toString(), _d(c['valor']) ?? 0, _d(c['pct']) ?? 0))
          .toList(),
      destaques: _list(j['destaques'])
          .map((d) => Destaque(d['codigo'].toString(), d['descricao'].toString(), _d(d['variacao']) ?? 0))
          .toList(),
      lote: LoteInfo(
        registrosExtraidos: _i(l['registros_extraidos']),
        operadoras: _i(l['operadoras']),
        auditado: l['auditado'] == true,
        auditadoPor: l['auditado_por']?.toString(),
        auditadoEm: l['auditado_em'] == null ? null : DateTime.tryParse(l['auditado_em'].toString()),
      ),
    );
  }
}
