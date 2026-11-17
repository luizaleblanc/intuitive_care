/// Modelos para indicadores agregados do dashboard analítico.
class UfEstatistica {
  final String uf;
  final double total;
  final int qtdOperadoras;

  const UfEstatistica({
    required this.uf,
    required this.total,
    required this.qtdOperadoras,
  });

  factory UfEstatistica.fromJson(Map<String, dynamic> json) {
    return UfEstatistica(
      uf: (json['uf'] ?? '').toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      qtdOperadoras: (json['qtd_operadoras'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrimestreEstatistica {
  final int ano;
  final int trimestre;
  final String periodo;
  final double total;

  const TrimestreEstatistica({
    required this.ano,
    required this.trimestre,
    required this.periodo,
    required this.total,
  });

  factory TrimestreEstatistica.fromJson(Map<String, dynamic> json) {
    return TrimestreEstatistica(
      ano: (json['ano'] as num?)?.toInt() ?? 0,
      trimestre: (json['trimestre'] as num?)?.toInt() ?? 1,
      periodo: (json['periodo'] ?? '').toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopOperadoraEstatistica {
  final String registroAns;
  final String razaoSocial;
  final String uf;
  final double total;

  const TopOperadoraEstatistica({
    required this.registroAns,
    required this.razaoSocial,
    required this.uf,
    required this.total,
  });

  factory TopOperadoraEstatistica.fromJson(Map<String, dynamic> json) {
    return TopOperadoraEstatistica(
      registroAns: (json['registro_ans'] ?? '').toString(),
      razaoSocial: (json['razao_social'] ?? '').toString(),
      uf: (json['uf'] ?? '').toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EstatisticaDashboardModel {
  final double totalGeral;
  final double mediaDespesa;
  final int totalLancamentos;
  final int totalOperadoras;
  final double crescimentoPeriodoPct;
  final List<UfEstatistica> topUfs;
  final List<TrimestreEstatistica> serieTrimestral;
  final List<TopOperadoraEstatistica> topOperadoras;

  const EstatisticaDashboardModel({
    required this.totalGeral,
    required this.mediaDespesa,
    required this.totalLancamentos,
    required this.totalOperadoras,
    required this.crescimentoPeriodoPct,
    required this.topUfs,
    required this.serieTrimestral,
    required this.topOperadoras,
  });

  factory EstatisticaDashboardModel.fromJson(Map<String, dynamic> json) {
    return EstatisticaDashboardModel(
      totalGeral: (json['total_geral'] as num?)?.toDouble() ?? 0.0,
      mediaDespesa: (json['media_despesa'] as num?)?.toDouble() ?? 0.0,
      totalLancamentos: (json['total_lancamentos'] as num?)?.toInt() ?? 0,
      totalOperadoras: (json['total_operadoras'] as num?)?.toInt() ?? 0,
      crescimentoPeriodoPct: (json['crescimento_periodo_pct'] as num?)?.toDouble() ?? 0.0,
      topUfs: (json['top_ufs'] as List<dynamic>? ?? [])
          .map((e) => UfEstatistica.fromJson(e as Map<String, dynamic>))
          .toList(),
      serieTrimestral: (json['serie_trimestral'] as List<dynamic>? ?? [])
          .map((e) => TrimestreEstatistica.fromJson(e as Map<String, dynamic>))
          .toList(),
      topOperadoras: (json['top_operadoras'] as List<dynamic>? ?? [])
          .map((e) => TopOperadoraEstatistica.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
