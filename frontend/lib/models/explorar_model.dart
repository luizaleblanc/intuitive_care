/// Métricas cruzáveis na exploração. Os códigos são os mesmos da API (/api/explorar).
enum Metrica {
  despesas('despesas', 'Despesas assistenciais', 'Eventos indenizáveis líquidos'),
  receitas('receitas', 'Receitas', 'Contraprestações efetivas'),
  sinistralidade('sinistralidade', 'Sinistralidade', 'Despesas ÷ receitas'),
  beneficiarios('beneficiarios', 'Beneficiários', 'Médico-hospitalares, último trimestre');

  final String codigo;
  final String nome;
  final String descricao;
  const Metrica(this.codigo, this.nome, this.descricao);

  static Metrica? porCodigo(String? c) => Metrica.values.where((m) => m.codigo == c).firstOrNull;
}

/// Tipos de gráfico do Design System.
enum TipoGrafico {
  pillBar('pill_bar', 'Barras verticais (pílula)', 'Comparação anual ou trimestral'),
  donutSage('donut_sage', 'Rosca / distribuição', 'Participação por modalidade'),
  trendArea('trend_area', 'Linha / área de evolução', 'Série histórica'),
  horizontalRanking('horizontal_ranking', 'Ranking horizontal', 'Top operadoras do recorte');

  final String codigo;
  final String nome;
  final String usoIdeal;
  const TipoGrafico(this.codigo, this.nome, this.usoIdeal);

  static TipoGrafico? porCodigo(String? c) => TipoGrafico.values.where((t) => t.codigo == c).firstOrNull;
}

class GraficoConfig {
  final TipoGrafico tipo;
  final Metrica metrica;
  const GraficoConfig(this.tipo, this.metrica);

  Map<String, String> toJson() => {'tipo': tipo.codigo, 'metrica': metrica.codigo};

  static GraficoConfig? fromJson(dynamic j) {
    if (j is! Map) return null;
    final t = TipoGrafico.porCodigo(j['tipo']?.toString());
    final m = Metrica.porCodigo(j['metrica']?.toString());
    return t == null || m == null ? null : GraficoConfig(t, m);
  }

  @override
  bool operator ==(Object other) => other is GraficoConfig && other.tipo == tipo && other.metrica == metrica;

  @override
  int get hashCode => Object.hash(tipo, metrica);

  static const padrao = [
    GraficoConfig(TipoGrafico.pillBar, Metrica.despesas),
    GraficoConfig(TipoGrafico.donutSage, Metrica.despesas),
    GraficoConfig(TipoGrafico.trendArea, Metrica.sinistralidade),
    GraficoConfig(TipoGrafico.horizontalRanking, Metrica.despesas),
  ];
}

double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

/// Valores das quatro métricas para um ponto (período, modalidade ou operadora).
class Valores {
  final double despesas;
  final double receitas;
  final double? sinistralidade;
  final double beneficiarios;

  const Valores({this.despesas = 0, this.receitas = 0, this.sinistralidade, this.beneficiarios = 0});

  factory Valores.fromJson(Map<String, dynamic> j) => Valores(
        despesas: _num(j['despesas']) ?? 0,
        receitas: _num(j['receitas']) ?? 0,
        sinistralidade: _num(j['sinistralidade']),
        beneficiarios: _num(j['beneficiarios']) ?? 0,
      );

  double? de(Metrica m) => switch (m) {
        Metrica.despesas => despesas,
        Metrica.receitas => receitas,
        Metrica.sinistralidade => sinistralidade,
        Metrica.beneficiarios => beneficiarios,
      };
}

class PontoSerie {
  final int ano;
  final int? trimestre;
  final Valores valores;
  const PontoSerie(this.ano, this.trimestre, this.valores);

  factory PontoSerie.fromJson(Map<String, dynamic> j) =>
      PontoSerie((j['ano'] as num).toInt(), (j['trimestre'] as num?)?.toInt(), Valores.fromJson(j));
}

class ModalidadeExplorar {
  final String modalidade;
  final int operadoras;
  final Valores valores;
  const ModalidadeExplorar(this.modalidade, this.operadoras, this.valores);

  factory ModalidadeExplorar.fromJson(Map<String, dynamic> j) => ModalidadeExplorar(
      (j['modalidade'] ?? 'Não informada').toString(), (j['operadoras'] as num? ?? 0).toInt(), Valores.fromJson(j));
}

class OperadoraExplorar {
  final String registroAns;
  final String nome;
  final String? uf;
  final String modalidade;
  final String? status;
  final Valores valores;

  const OperadoraExplorar(this.registroAns, this.nome, this.uf, this.modalidade, this.status, this.valores);

  factory OperadoraExplorar.fromJson(Map<String, dynamic> j) => OperadoraExplorar(
        j['registro_ans'].toString(),
        (j['nome'] ?? j['razao_social'] ?? '').toString(),
        j['uf']?.toString(),
        (j['modalidade'] ?? 'Não informada').toString(),
        j['status']?.toString(),
        Valores.fromJson(j),
      );
}

class Facetas {
  final List<String> ufs;
  final List<String> modalidades;
  final List<String> status;
  const Facetas({this.ufs = const [], this.modalidades = const [], this.status = const ['Ativa']});

  factory Facetas.fromJson(Map<String, dynamic>? j) => j == null
      ? const Facetas()
      : Facetas(
          ufs: [for (final u in (j['ufs'] as List? ?? [])) u.toString()],
          modalidades: [for (final m in (j['modalidades'] as List? ?? [])) m.toString()],
          status: [for (final s in (j['status'] as List? ?? ['Ativa'])) s.toString()],
        );
}

class ExplorarModel {
  final int anoInicio;
  final int anoFim;

  /// Anos efetivamente consultados (podem não ser contíguos, ex.: 2019, 2021).
  final List<int> anos;
  final String granularidade;
  final List<int> anosDisponiveis;
  final List<int> anosParciais;
  final Facetas facetas;
  final Valores kpis;
  final int totalOperadoras;
  final List<PontoSerie> serie;
  final List<ModalidadeExplorar> porModalidade;
  final List<OperadoraExplorar> operadoras;

  /// Período anterior equivalente (quando "comparar" está ligado).
  final Valores? kpisAnteriores;
  final List<PontoSerie> serieAnterior;
  final String? avisoComparativo;
  final (int, int)? periodoAnterior;
  final List<int> anosAnteriores;

  const ExplorarModel({
    required this.anoInicio,
    required this.anoFim,
    this.anos = const [],
    required this.granularidade,
    required this.anosDisponiveis,
    required this.anosParciais,
    required this.facetas,
    required this.kpis,
    required this.totalOperadoras,
    required this.serie,
    required this.porModalidade,
    required this.operadoras,
    this.kpisAnteriores,
    this.serieAnterior = const [],
    this.avisoComparativo,
    this.periodoAnterior,
    this.anosAnteriores = const [],
  });

  factory ExplorarModel.fromJson(Map<String, dynamic> j) {
    final periodo = Map<String, dynamic>.from(j['periodo'] as Map);
    final kpis = Map<String, dynamic>.from(j['kpis'] as Map);
    final comp = j['comparativo'] is Map ? Map<String, dynamic>.from(j['comparativo'] as Map) : null;
    List<T> lista<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        [for (final e in (v as List? ?? [])) f(Map<String, dynamic>.from(e as Map))];
    return ExplorarModel(
      anoInicio: (periodo['ano_inicio'] as num).toInt(),
      anoFim: (periodo['ano_fim'] as num).toInt(),
      anos: [for (final a in (periodo['anos'] as List? ?? [])) (a as num).toInt()],
      granularidade: (periodo['granularidade'] ?? 'trimestre').toString(),
      anosDisponiveis: [for (final a in (j['anos_disponiveis'] as List? ?? [])) (a as num).toInt()],
      anosParciais: [for (final a in (j['anos_parciais'] as List? ?? [])) (a as num).toInt()],
      facetas: Facetas.fromJson(j['facetas'] is Map ? Map<String, dynamic>.from(j['facetas'] as Map) : null),
      kpis: Valores.fromJson(kpis),
      totalOperadoras: (j['total_operadoras'] as num? ?? kpis['operadoras'] as num? ?? 0).toInt(),
      serie: lista(j['serie'], PontoSerie.fromJson),
      porModalidade: lista(j['por_modalidade'], ModalidadeExplorar.fromJson),
      operadoras: lista(j['operadoras'], OperadoraExplorar.fromJson),
      kpisAnteriores: comp?['kpis'] is Map ? Valores.fromJson(Map<String, dynamic>.from(comp!['kpis'] as Map)) : null,
      serieAnterior: lista(comp?['serie'], PontoSerie.fromJson),
      avisoComparativo: comp?['aviso']?.toString(),
      periodoAnterior: comp == null
          ? null
          : ((comp['ano_inicio'] as num).toInt(), (comp['ano_fim'] as num).toInt()),
      anosAnteriores: [for (final a in (comp?['anos'] as List? ?? [])) (a as num).toInt()],
    );
  }
}
