import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/explorar_model.dart';
import '../services/api_client.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/explorar_viewmodel.dart';

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

String _fmtValorMetrica(Metrica m, Valores v) => switch (m) {
      Metrica.despesas => v.despesas.toStringAsFixed(2),
      Metrica.receitas => v.receitas.toStringAsFixed(2),
      Metrica.sinistralidade => v.sinistralidade == null ? '' : v.sinistralidade!.toStringAsFixed(2),
      Metrica.beneficiarios => v.beneficiarios.toStringAsFixed(0),
    };

String _fmtValorResumo(Metrica m, Valores v) => switch (m) {
      Metrica.despesas => fmtBi(v.despesas),
      Metrica.receitas => fmtBi(v.receitas),
      Metrica.sinistralidade => v.sinistralidade == null ? '—' : fmtPct(v.sinistralidade!),
      Metrica.beneficiarios => fmtInt(v.beneficiarios),
    };

String _colunaMetrica(Metrica m) => switch (m) {
      Metrica.despesas => 'Despesas assistenciais (R\$)',
      Metrica.receitas => 'Receitas / Contraprestações (R\$)',
      Metrica.sinistralidade => 'Sinistralidade (%)',
      Metrica.beneficiarios => 'Beneficiários',
    };

String _rotuloRecorte(ExplorarModel dados, ConfigRelatorio cfg) {
  final anos = dados.anos.isNotEmpty ? dados.anos : [dados.anoInicio];
  final parteAnos = anos.length == 1
      ? '${anos.first}'
      : (anos.length == anos.last - anos.first + 1 ? '${anos.first}–${anos.last}' : anos.join(', '));
  final parteTris = cfg.trimestres.isEmpty || cfg.trimestres.length == 4 ? '' : ' · ${fmtTrimestres(cfg.trimestres)}';
  final filtros = <String>[
    if (cfg.ufs.isNotEmpty) 'UF: ${(cfg.ufs.toList()..sort()).join(', ')}',
    if (cfg.modalidades.isNotEmpty) 'Modalidade: ${(cfg.modalidades.toList()..sort()).join(', ')}',
    if (cfg.statuses.isNotEmpty) 'Status: ${(cfg.statuses.toList()..sort()).join(', ')}',
  ];
  return [
    'Período $parteAnos$parteTris',
    if (filtros.isNotEmpty) filtros.join(' · '),
    '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
  ].join(' · ');
}

/// Monta abas concisas client-side a partir de [ExplorarModel] (mantido para compatibilidade e fallback).
List<ExportTable> montarAbasRelatorio(ExplorarModel dados, ConfigRelatorio cfg) {
  final metricas = [for (final m in Metrica.values) if (cfg.metricas.contains(m)) m];
  final subtitulo = _rotuloRecorte(dados, cfg);
  final abas = <ExportTable>[];

  if (cfg.secoes.contains(SecaoRelatorio.resumo)) {
    abas.add(
      ExportTable(
        titulo: 'Resumo Executivo',
        subtitulo: subtitulo,
        colunas: const ['Indicador', 'Valor', 'Detalhe'],
        linhas: [
          [
            'Período analisado',
            _rotuloRecorte(dados, cfg).split(' · ').first.replaceFirst('Período ', ''),
            cfg.granularidade == 'ano' ? 'Agrupamento anual' : 'Agrupamento trimestral',
          ],
          [
            'Operadoras no recorte',
            fmtInt(dados.totalOperadoras),
            cfg.statuses.isEmpty ? 'Ativas e inativas conforme filtro' : (cfg.statuses.toList()..sort()).join(', '),
          ],
          for (final m in metricas) [m.nome, _fmtValorResumo(m, dados.kpis), m.descricao],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.evolucao)) {
    abas.add(
      ExportTable(
        titulo: 'Evolucao',
        subtitulo: subtitulo,
        colunas: ['Período', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final p in dados.serie)
            [
              p.trimestre == null ? '${p.ano}' : fmtPeriodo(p.ano, p.trimestre!),
              for (final m in metricas) _fmtValorMetrica(m, p.valores),
            ],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.modalidades)) {
    abas.add(
      ExportTable(
        titulo: 'Modalidades',
        subtitulo: subtitulo,
        colunas: ['Modalidade', 'Operadoras', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final mod in dados.porModalidade)
            [
              mod.modalidade,
              mod.operadoras.toString(),
              for (final m in metricas) _fmtValorMetrica(m, mod.valores),
            ],
        ],
      ),
    );
  }

  if (cfg.secoes.contains(SecaoRelatorio.operadoras)) {
    final lista = List<OperadoraExplorar>.from(dados.operadoras)
      ..sort((a, b) => (b.valores.de(cfg.ordenarPor) ?? -1).compareTo(a.valores.de(cfg.ordenarPor) ?? -1));
    final recorte = cfg.limiteOperadoras == null ? lista : lista.take(cfg.limiteOperadoras!).toList();
    abas.add(
      ExportTable(
        titulo: 'Operadoras',
        subtitulo: '$subtitulo · Ordenado por ${cfg.ordenarPor.nome}',
        colunas: ['Registro ANS', 'Operadora', 'UF', 'Modalidade', 'Status', for (final m in metricas) _colunaMetrica(m)],
        linhas: [
          for (final o in recorte)
            [
              o.registroAns,
              o.nome,
              o.uf ?? '',
              o.modalidade,
              o.status ?? '',
              for (final m in metricas) _fmtValorMetrica(m, o.valores),
            ],
        ],
      ),
    );
  }

  return abas;
}

/// Abre o construtor de relatório personalizado (planilha XLSX com openpyxl / CSV / PDF) exclusivo do Administrador.
void abrirRelatorioPersonalizado(BuildContext context) {
  showSideDrawer<void>(context, width: 580, builder: (_) => const RelatorioDrawer());
}

class RelatorioDrawer extends StatefulWidget {
  const RelatorioDrawer({super.key});

  @override
  State<RelatorioDrawer> createState() => _RelatorioDrawerState();
}

class _RelatorioDrawerState extends State<RelatorioDrawer> {
  List<int> _anosDisponiveis = const [];
  Facetas _facetas = const Facetas();
  Set<int> _anos = {};
  Set<int> _trimestres = {};
  String _granularidade = 'ano';
  Set<String> _ufs = {};
  Set<String> _modalidades = {};
  Set<String> _portes = {};
  Set<String> _statuses = {};
  Set<String> _consolidacoes = {};
  Set<SecaoRelatorio> _secoes = Set.of(SecaoRelatorio.values);
  OrdemRelatorio _ordenarPor = OrdemRelatorio.despesas;
  int? _limite = 50;
  String _formato = 'XLSX';
  String _formatoData = 'DD/MM/AAAA';
  bool _carregandoBase = true;
  bool _gerando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AuthViewModel>().currentUser?.preferencias;
    if (prefs != null) {
      if (const {'XLSX', 'CSV', 'PDF'}.contains(prefs.formatoExportacao)) {
        _formato = prefs.formatoExportacao;
      }
      if (const {'DD/MM/AAAA', 'AAAA-MM-DD'}.contains(prefs.formatoData)) {
        _formatoData = prefs.formatoData;
      }
    }
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    final vm = context.read<ExplorarViewModel>();
    try {
      final base = vm.dados ?? await vm.consultarRelatorio(const {'granularidade': 'ano'});
      if (!mounted) return;
      setState(() {
        _anosDisponiveis = base.anosDisponiveis;
        _facetas = base.facetas;
        _anos = base.anosDisponiveis.isEmpty ? {} : {base.anosDisponiveis.last};
        _carregandoBase = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.message;
          _carregandoBase = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar as opções do relatório: $e';
          _carregandoBase = false;
        });
      }
    }
  }

  int get _quantidadeAbasXlsx {
    var total = _secoes.length;
    // A seção "Base ETL · Lotes e Cadastro" gera duas abas no XLSX: "Lotes ETL" e "Cadastro Operadoras".
    if (_secoes.contains(SecaoRelatorio.lotesCadastro)) total += 1;
    return total;
  }

  Future<void> _gerar() async {
    if (_anos.isEmpty || _secoes.isEmpty) return;
    setState(() {
      _gerando = true;
      _erro = null;
    });
    final vm = context.read<ExplorarViewModel>();
    final toast = context.read<ToastController>();
    final anosOrd = _anos.toList()..sort();
    final sufixoAnos = anosOrd.length == 1 ? '${anosOrd.first}' : '${anosOrd.first}_${anosOrd.last}';

    final cfg = ConfigRelatorio(
      anos: _anos,
      trimestres: _trimestres,
      granularidade: _granularidade,
      ufs: _ufs,
      modalidades: _modalidades,
      portes: _portes,
      statuses: _statuses,
      consolidacoes: _consolidacoes,
      secoes: _secoes,
      ordenarRelatorio: _ordenarPor,
      limiteOperadoras: _limite,
      formato: _formato,
      formatoData: _formatoData,
    );

    try {
      late final String nomeFinal;
      if (_formato == 'PDF') {
        final resposta = await vm.exportarRelatorioJson(cfg.toApiPayload(formatoOverride: 'JSON'));
        final parsed = parseRelatorioJson(resposta);
        if (parsed.abas.isEmpty) {
          throw const ApiException(statusCode: 404, message: 'Não há dados para compor o relatório com esses filtros.');
        }
        nomeFinal = await Exporter.exportarRelatorio(
          parsed.abas,
          nomeBase: parsed.nomeBase,
          formato: 'PDF',
          tituloGeral: parsed.tituloGeral,
          subtituloGeral: parsed.subtituloGeral,
        );
      } else {
        final resposta = await vm.exportarRelatorioBytes(cfg.toApiPayload());
        final ext = _formato == 'CSV' ? 'csv' : 'xlsx';
        final mime = _formato == 'CSV' ? Exporter.mimeCsv : Exporter.mimeXlsx;
        final nome = resposta.filename ?? 'relatorio_etl_ans_$sufixoAnos.$ext';
        nomeFinal = Exporter.salvarBytes(resposta.bytes, nome, mime);
      }
      if (!mounted) return;
      toast.show('Relatório exportado ($nomeFinal)');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha ao gerar o relatório: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Widget _secao(String titulo, String ajuda, Widget conteudo, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(titulo, style: AppText.display(14, weight: FontWeight.w700, color: AppColors.sageText))),
            ?trailing,
          ]),
          const SizedBox(height: 2),
          Text(ajuda, style: AppText.sans(12, color: AppColors.sageMuted)),
          const SizedBox(height: 10),
          conteudo,
        ]),
      );

  Widget _subgrupo(String titulo, List<SecaoRelatorio> itens) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: AppText.sans(10, weight: FontWeight.w700, color: AppColors.sageMuted, spacing: 0.9),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in itens)
                Tooltip(
                  message: s.descricao,
                  child: _chip(s.nome, _secoes.contains(s), () {
                    setState(() {
                      if (_secoes.contains(s) && _secoes.length > 1) {
                        _secoes = {..._secoes}..remove(s);
                      } else {
                        _secoes = {..._secoes, s};
                      }
                    });
                  }),
                ),
            ],
          ),
        ],
      );

  Widget _chip(String rotulo, bool ativo, VoidCallback onTap) => Semantics(
        selected: ativo,
        button: true,
        child: Material(
          color: ativo ? AppColors.primaryBg : AppColors.card,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (ativo) ...[
                  const Icon(LucideIcons.check, size: 13, color: AppColors.mint),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    rotulo,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(12, weight: FontWeight.w600, color: ativo ? Colors.white : AppColors.sageText),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _atalhoSecoes(String rotulo, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(rotulo, style: AppText.sans(11, weight: FontWeight.w700, color: AppColors.brandText)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final podeGerar = !_carregandoBase && !_gerando && _anos.isNotEmpty && _secoes.isNotEmpty;
    final resumoFormato = switch (_formato) {
      'XLSX' => '$_quantidadeAbasXlsx aba(s) com fórmulas vivas, gráficos nativos e formatação contábil ANS',
      'CSV' => '${_secoes.length} bloco(s) em UTF-8 BOM compatível com Excel e BI',
      _ => '${_secoes.length} seção(ões) estruturadas direto das bases ETL da ANS',
    };

    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  'Exportar relatório ETL (ANS)',
                  style: AppText.display(20, color: AppColors.sageText),
                ),
              ),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Gere planilhas analíticas diretamente sobre todas as bases do ETL da ANS com filtros avançados, fórmulas e gráficos.',
              style: AppText.sans(13, color: AppColors.sageMuted),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _carregandoBase
                ? const LoadingBlock(label: 'Carregando filtros...')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    children: [
                      if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 16)],
                      _secao(
                        'Formato do arquivo',
                        resumoFormato,
                        SegmentedPill<String>(
                          value: _formato,
                          options: const [
                            ('XLSX', 'XLSX'),
                            ('CSV', 'CSV'),
                            ('PDF', 'PDF'),
                          ],
                          onChanged: (v) => setState(() => _formato = v),
                        ),
                      ),
                      _secao(
                        'Período (anos e trimestres)',
                        'Selecione um ou mais anos carregados no ETL e, se quiser, restrinja os trimestres.',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              AppMultiSelect<int>(
                                semanticLabel: 'Anos do relatório',
                                icon: LucideIcons.calendarDays,
                                selected: _anos,
                                minSelected: 1,
                                options: [for (final a in _anosDisponiveis.reversed) (a, '$a')],
                                formatSelected: (l) => fmtAnos(l.map((e) => e.$1)),
                                onChanged: (v) => setState(() => _anos = v),
                              ),
                              AppMultiSelect<int>(
                                semanticLabel: 'Trimestres do relatório',
                                icon: LucideIcons.calendar,
                                selected: _trimestres,
                                emptyLabel: 'Todos os trimestres',
                                options: [for (var t = 1; t <= 4; t++) (t, fmtTrimestre(t))],
                                formatSelected: (l) => fmtTrimestres(l.map((e) => e.$1)),
                                onChanged: (v) => setState(() => _trimestres = v),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            SegmentedPill<String>(
                              value: _granularidade,
                              expand: false,
                              options: const [('ano', 'Por ano'), ('trimestre', 'Por trimestre')],
                              onChanged: (v) => setState(() => _granularidade = v),
                            ),
                          ],
                        ),
                      ),
                      _secao(
                        'Seções e bases ETL incluídas',
                        'Combine visões executivas com as tabelas completas extraídas do ETL da ANS.',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _subgrupo('Visões executivas', SecaoRelatorio.visoesExecutivas),
                            const SizedBox(height: 14),
                            _subgrupo('Bases completas do ETL (ANS)', SecaoRelatorio.basesEtl),
                          ],
                        ),
                        trailing: Wrap(spacing: 4, children: [
                          _atalhoSecoes(
                            'Só executivo',
                            () => setState(() => _secoes = Set.of(SecaoRelatorio.visoesExecutivas)),
                          ),
                          _atalhoSecoes(
                            'Todas (8)',
                            () => setState(() => _secoes = Set.of(SecaoRelatorio.values)),
                          ),
                        ]),
                      ),
                      if (_secoes.contains(SecaoRelatorio.operadoras))
                        _secao(
                          'Ordenação e limite do ranking de operadoras',
                          'Defina o indicador principal do ranking e quantas operadoras entram na aba consolidada.',
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            AppSelect<OrdemRelatorio>(
                              semanticLabel: 'Ordenar por',
                              icon: LucideIcons.arrowDownWideNarrow,
                              value: _ordenarPor,
                              options: [for (final o in OrdemRelatorio.values) (o, 'Por ${o.nome}')],
                              onChanged: (v) => setState(() => _ordenarPor = v),
                            ),
                            AppSelect<int>(
                              semanticLabel: 'Quantidade de operadoras',
                              icon: LucideIcons.listOrdered,
                              value: _limite ?? 0,
                              options: const [
                                (10, 'Top 10'),
                                (25, 'Top 25'),
                                (50, 'Top 50'),
                                (100, 'Top 100'),
                                (0, 'Todas do recorte'),
                              ],
                              onChanged: (v) => setState(() => _limite = v == 0 ? null : v),
                            ),
                          ]),
                        ),
                      _secao(
                        'Filtros avançados',
                        'Deixe em branco para exportar toda a base extraída do período selecionado.',
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          AppMultiSelect<String>(
                            semanticLabel: 'UFs do relatório',
                            icon: LucideIcons.mapPin,
                            selected: _ufs,
                            emptyLabel: 'Todas UFs',
                            options: [for (final u in _facetas.ufs) (u, u)],
                            formatSelected: (l) => l.length <= 2 ? l.map((e) => e.$1).join(', ') : '${l.length} UFs',
                            onChanged: (v) => setState(() => _ufs = v),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: AppMultiSelect<String>(
                              semanticLabel: 'Modalidades do relatório',
                              icon: LucideIcons.layers,
                              selected: _modalidades,
                              emptyLabel: 'Todas modalidades',
                              options: [for (final m in _facetas.modalidades) (m, m)],
                              formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} modalidades',
                              onChanged: (v) => setState(() => _modalidades = v),
                            ),
                          ),
                          AppMultiSelect<String>(
                            semanticLabel: 'Porte ANS das operadoras',
                            icon: LucideIcons.building2,
                            selected: _portes,
                            emptyLabel: 'Todos os portes',
                            options: [for (final e in rotulosPorte.entries) (e.key, e.value)],
                            formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} portes',
                            onChanged: (v) => setState(() => _portes = v),
                          ),
                          if (_facetas.status.length > 1)
                            AppMultiSelect<String>(
                              semanticLabel: 'Status das operadoras',
                              icon: LucideIcons.circleCheck,
                              selected: _statuses,
                              emptyLabel: 'Todos os status',
                              options: [for (final s in _facetas.status) (s, s)],
                              formatSelected: (l) => l.map((e) => e.$2).join(', '),
                              onChanged: (v) => setState(() => _statuses = v),
                            ),
                          AppMultiSelect<String>(
                            semanticLabel: 'Consolidação dos lotes ETL',
                            icon: LucideIcons.shieldCheck,
                            selected: _consolidacoes,
                            emptyLabel: 'Todos os lotes',
                            options: [for (final e in rotulosConsolidacao.entries) (e.key, e.value)],
                            formatSelected: (l) => l.length == 1 ? l.first.$2 : 'Todos os lotes',
                            onChanged: (v) => setState(() => _consolidacoes = v),
                          ),
                        ]),
                      ),
                    ],
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AppButton('Cancelar', variant: ButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    _formato == 'XLSX' ? 'Exportar planilha' : 'Exportar $_formato',
                    icon: LucideIcons.fileSpreadsheet,
                    loading: _gerando,
                    loadingLabel: 'Gerando...',
                    onPressed: podeGerar ? _gerar : null,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
