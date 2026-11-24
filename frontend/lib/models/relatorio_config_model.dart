import '../shared/utils/exporter.dart';
import 'explorar_model.dart';

/// Seções disponíveis para compor o relatório analítico do Administrador (visões executivas + bases ETL ANS).
enum SecaoRelatorio {
  resumo('resumo', 'Resumo executivo', 'KPIs consolidados, fórmulas e rastreabilidade do ETL', false),
  evolucao('evolucao', 'Evolução no período', 'Série histórica anual ou trimestral com gráfico nativo', false),
  modalidades('modalidades', 'Por modalidade', 'Participação e indicadores por modalidade ANS com gráfico', false),
  ufs('ufs', 'Por UF', 'Distribuição regional por unidade federativa', false),
  operadoras('operadoras', 'Ranking de operadoras', 'Operadoras do recorte ordenadas pelo indicador escolhido', false),
  contasSetor('contas_setor', 'Plano de Contas ANS', 'Tabela completa contas_setor por código e grupo contábil', true),
  baseDemonstracoes(
    'base_demonstracoes',
    'Base ETL · Demonstrações',
    'Base fato operadora × trimestre (pronta para tabela dinâmica)',
    true,
  ),
  lotesCadastro(
    'lotes_cadastro',
    'Base ETL · Lotes e Cadastro',
    'Auditoria de lotes extraídos (lotes_etl) e cadastro CADOP (operadoras)',
    true,
  );

  final String codigo;
  final String nome;
  final String descricao;
  final bool ehBaseEtl;
  const SecaoRelatorio(this.codigo, this.nome, this.descricao, this.ehBaseEtl);

  static const visoesExecutivas = [resumo, evolucao, modalidades, ufs, operadoras];
  static const basesEtl = [contasSetor, baseDemonstracoes, lotesCadastro];
}

/// Critérios de ordenação para o ranking de operadoras na exportação do backend.
enum OrdemRelatorio {
  despesas('despesas', 'Despesas'),
  receitas('receitas', 'Receitas'),
  sinistralidade('sinistralidade', 'Sinistralidade'),
  beneficiarios('beneficiarios', 'Beneficiários'),
  resultado('resultado', 'Resultado operacional'),
  administrativas('administrativas', 'Administrativas');

  final String codigo;
  final String nome;
  const OrdemRelatorio(this.codigo, this.nome);
}

/// Configuração escolhida pelo Administrador para montar a planilha/relatório das bases ETL.
class ConfigRelatorio {
  final Set<int> anos;
  final Set<int> trimestres;
  final String granularidade;
  final Set<String> ufs;
  final Set<String> modalidades;
  final Set<String> portes;
  final Set<String> statuses;
  final Set<String> consolidacoes;
  final Set<SecaoRelatorio> secoes;
  final Set<Metrica> metricas;
  final Metrica ordenarPor;
  final OrdemRelatorio? ordenarRelatorio;
  final int? limiteOperadoras;
  final String formato;
  final String formatoData;

  const ConfigRelatorio({
    this.anos = const {},
    this.trimestres = const {},
    this.granularidade = 'ano',
    this.ufs = const {},
    this.modalidades = const {},
    this.portes = const {},
    this.statuses = const {},
    this.consolidacoes = const {},
    this.secoes = const {
      SecaoRelatorio.resumo,
      SecaoRelatorio.evolucao,
      SecaoRelatorio.modalidades,
      SecaoRelatorio.ufs,
      SecaoRelatorio.operadoras,
      SecaoRelatorio.contasSetor,
      SecaoRelatorio.baseDemonstracoes,
      SecaoRelatorio.lotesCadastro,
    },
    this.metricas = const {
      Metrica.despesas,
      Metrica.receitas,
      Metrica.sinistralidade,
      Metrica.beneficiarios,
    },
    this.ordenarPor = Metrica.despesas,
    this.ordenarRelatorio,
    this.limiteOperadoras = 50,
    this.formato = 'XLSX',
    this.formatoData = 'DD/MM/AAAA',
  });

  /// Monta o payload JSON enviado ao endpoint `POST /api/relatorios/exportar`.
  Map<String, dynamic> toApiPayload({String? formatoOverride}) {
    final anosOrd = anos.toList()..sort();
    final trisOrd = trimestres.toList()..sort();
    final secoesOrd = [for (final s in SecaoRelatorio.values) if (secoes.contains(s)) s.codigo];
    return {
      'anos': anosOrd,
      'trimestres': trisOrd,
      'granularidade': granularidade,
      'ufs': ufs.toList()..sort(),
      'modalidades': modalidades.toList()..sort(),
      'portes': portes.toList()..sort(),
      'statuses': statuses.toList()..sort(),
      'consolidacoes': consolidacoes.toList()..sort(),
      'secoes': secoesOrd,
      'ordenar_por': (ordenarRelatorio?.codigo ?? ordenarPor.codigo),
      'limite_operadoras': limiteOperadoras,
      'formato': (formatoOverride ?? formato).toUpperCase(),
      'formato_data': formatoData,
    };
  }
}

/// Converte o retorno JSON de `POST /api/relatorios/exportar` (formato `JSON`) em tabelas prontas para PDF.
({String tituloGeral, String subtituloGeral, String nomeBase, List<ExportTable> abas}) parseRelatorioJson(
  Map<String, dynamic> json,
) {
  final abasRaw = (json['abas'] as List? ?? const []);
  final abas = <ExportTable>[
    for (final item in abasRaw)
      if (item is Map)
        ExportTable(
          titulo: (item['titulo'] ?? 'Seção').toString(),
          subtitulo: item['subtitulo']?.toString(),
          colunas: [for (final c in (item['colunas'] as List? ?? const [])) c.toString()],
          linhas: [
            for (final l in (item['linhas'] as List? ?? const []))
              if (l is List) [for (final v in l) v?.toString() ?? ''],
          ],
        ),
  ];
  return (
    tituloGeral: (json['titulo_geral'] ?? 'Relatório Analítico ANS · Intuitive Care').toString(),
    subtituloGeral: (json['subtitulo_geral'] ?? '').toString(),
    nomeBase: (json['nome_base'] ?? 'relatorio_etl_ans').toString(),
    abas: abas,
  );
}
