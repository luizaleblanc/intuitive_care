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

/// Seções disponíveis para compor o relatório conciso do Administrador.
enum SecaoRelatorio {
  resumo('Resumo executivo', 'KPIs consolidados e recorte aplicado'),
  evolucao('Evolução no período', 'Série histórica anual ou trimestral'),
  modalidades('Por modalidade', 'Participação e indicadores por modalidade'),
  operadoras('Ranking de operadoras', 'Operadoras do recorte ordenadas pelo indicador');

  final String nome;
  final String descricao;
  const SecaoRelatorio(this.nome, this.descricao);
}

/// Configuração escolhida pelo Administrador para montar sua planilha/relatório conciso.
class ConfigRelatorio {
  final Set<int> anos;
  final Set<int> trimestres;
  final String granularidade;
  final Set<String> ufs;
  final Set<String> modalidades;
  final Set<String> statuses;
  final Set<SecaoRelatorio> secoes;
  final Set<Metrica> metricas;
  final Metrica ordenarPor;
  final int? limiteOperadoras;
  final String formato;

  const ConfigRelatorio({
    this.anos = const {},
    this.trimestres = const {},
    this.granularidade = 'ano',
    this.ufs = const {},
    this.modalidades = const {},
    this.statuses = const {},
    this.secoes = const {
      SecaoRelatorio.resumo,
      SecaoRelatorio.evolucao,
      SecaoRelatorio.modalidades,
      SecaoRelatorio.operadoras,
    },
    this.metricas = const {
      Metrica.despesas,
      Metrica.receitas,
      Metrica.sinistralidade,
      Metrica.beneficiarios,
    },
    this.ordenarPor = Metrica.despesas,
    this.limiteOperadoras = 25,
    this.formato = 'XLSX',
  });
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

/// Monta as abas/seções concisas do relatório personalizado a partir dos dados extraídos da ANS.
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
          ['Período analisado', _rotuloRecorte(dados, cfg).split(' · ').first.replaceFirst('Período ', ''), cfg.granularidade == 'ano' ? 'Agrupamento anual' : 'Agrupamento trimestral'],
          ['Operadoras no recorte', fmtInt(dados.totalOperadoras), cfg.statuses.isEmpty ? 'Ativas e inativas conforme filtro' : (cfg.statuses.toList()..sort()).join(', ')],
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

/// Abre o construtor de relatório conciso (planilha XLSX / CSV / PDF) exclusivo do Administrador.
void abrirRelatorioPersonalizado(BuildContext context) {
  showSideDrawer<void>(context, width: 540, builder: (_) => const _RelatorioDrawer());
}

class _RelatorioDrawer extends StatefulWidget {
  const _RelatorioDrawer();

  @override
  State<_RelatorioDrawer> createState() => _RelatorioDrawerState();
}

class _RelatorioDrawerState extends State<_RelatorioDrawer> {
  List<int> _anosDisponiveis = const [];
  Facetas _facetas = const Facetas();
  Set<int> _anos = {};
  Set<int> _trimestres = {};
  String _granularidade = 'ano';
  Set<String> _ufs = {};
  Set<String> _modalidades = {};
  Set<String> _statuses = {};
  Set<SecaoRelatorio> _secoes = Set.of(SecaoRelatorio.values);
  Set<Metrica> _metricas = Set.of(Metrica.values);
  Metrica _ordenarPor = Metrica.despesas;
  int? _limite = 25;
  String _formato = 'XLSX';
  bool _carregandoBase = true;
  bool _gerando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final prefFormato = context.read<AuthViewModel>().currentUser?.preferencias.formatoExportacao;
    if (prefFormato != null && const {'XLSX', 'CSV', 'PDF'}.contains(prefFormato)) {
      _formato = prefFormato;
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
      if (mounted) setState(() { _erro = e.message; _carregandoBase = false; });
    } catch (e) {
      if (mounted) setState(() { _erro = 'Não foi possível carregar as opções do relatório: $e'; _carregandoBase = false; });
    }
  }

  Future<void> _gerar() async {
    if (_anos.isEmpty || _secoes.isEmpty || _metricas.isEmpty) return;
    setState(() { _gerando = true; _erro = null; });
    final vm = context.read<ExplorarViewModel>();
    final toast = context.read<ToastController>();
    final anosOrd = _anos.toList()..sort();
    final trisOrd = _trimestres.toList()..sort();
    final consulta = {
      'anos': anosOrd.join(','),
      'trimestres': trisOrd.join(','),
      'granularidade': _granularidade,
      'uf': (_ufs.toList()..sort()).join(','),
      'modalidade': (_modalidades.toList()..sort()).join(','),
      'status': (_statuses.toList()..sort()).join(','),
    };
    try {
      final dados = await vm.consultarRelatorio(consulta);
      final cfg = ConfigRelatorio(
        anos: _anos,
        trimestres: _trimestres,
        granularidade: _granularidade,
        ufs: _ufs,
        modalidades: _modalidades,
        statuses: _statuses,
        secoes: _secoes,
        metricas: _metricas,
        ordenarPor: _ordenarPor,
        limiteOperadoras: _limite,
        formato: _formato,
      );
      final abas = montarAbasRelatorio(dados, cfg);
      final sufixoAnos = anosOrd.length == 1 ? '${anosOrd.first}' : '${anosOrd.first}_${anosOrd.last}';
      final nome = await Exporter.exportarRelatorio(
        abas,
        nomeBase: 'relatorio_ans_$sufixoAnos',
        formato: _formato,
        tituloGeral: 'Relatório Analítico ANS · Intuitive Care',
        subtituloGeral: _rotuloRecorte(dados, cfg),
      );
      if (!mounted) return;
      toast.show('Relatório exportado ($nome)');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha ao gerar o relatório: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Widget _secao(String titulo, String ajuda, Widget conteudo) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: AppText.display(14, weight: FontWeight.w700, color: AppColors.sageText)),
          const SizedBox(height: 2),
          Text(ajuda, style: AppText.sans(12, color: AppColors.sageMuted)),
          const SizedBox(height: 10),
          conteudo,
        ]),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (ativo) ...[
                  const Icon(LucideIcons.check, size: 13, color: AppColors.mint),
                  const SizedBox(width: 6),
                ],
                Text(rotulo,
                    style: AppText.sans(12, weight: FontWeight.w600, color: ativo ? Colors.white : AppColors.sageText)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final podeGerar = !_carregandoBase && !_gerando && _anos.isNotEmpty && _secoes.isNotEmpty && _metricas.isNotEmpty;
    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
            child: Row(children: [
              Expanded(child: Text('Exportar relatório personalizado', style: AppText.display(20, color: AppColors.sageText))),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Monte uma planilha concisa com os dados extraídos da ANS escolhendo período, seções, métricas e filtros.',
              style: AppText.sans(13, color: AppColors.sageMuted),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _carregandoBase
                ? const LoadingBlock(label: 'Carregando anos e filtros disponíveis...')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    children: [
                      if (_erro != null) ...[ErrorBox(_erro!), const SizedBox(height: 16)],
                      _secao(
                        'Formato do arquivo',
                        'XLSX gera abas separadas por seção; CSV e PDF consolidam em um único arquivo.',
                        SegmentedPill<String>(
                          value: _formato,
                          options: const [
                            ('XLSX', 'Planilha (XLSX)'),
                            ('CSV', 'CSV'),
                            ('PDF', 'Relatório (PDF)'),
                          ],
                          onChanged: (v) => setState(() => _formato = v),
                        ),
                      ),
                      _secao(
                        'Período (anos e trimestres)',
                        'Selecione um ou mais anos e, se quiser, restrinja a trimestres específicos.',
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
                              options: const [('ano', 'Agrupar por ano'), ('trimestre', 'Agrupar por trimestre')],
                              onChanged: (v) => setState(() => _granularidade = v),
                            ),
                          ],
                        ),
                      ),
                      _secao(
                        'Seções do relatório',
                        'Escolha quais visões entram na planilha (no XLSX cada seção vira uma aba).',
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in SecaoRelatorio.values)
                            _chip(s.nome, _secoes.contains(s), () {
                              setState(() {
                                if (_secoes.contains(s) && _secoes.length > 1) {
                                  _secoes = {..._secoes}..remove(s);
                                } else {
                                  _secoes = {..._secoes, s};
                                }
                              });
                            }),
                        ]),
                      ),
                      _secao(
                        'Indicadores incluídos',
                        'Defina quais colunas financeiras e assistenciais deseja analisar.',
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final m in Metrica.values)
                            _chip(m.nome, _metricas.contains(m), () {
                              setState(() {
                                if (_metricas.contains(m) && _metricas.length > 1) {
                                  _metricas = {..._metricas}..remove(m);
                                  if (!_metricas.contains(_ordenarPor)) _ordenarPor = _metricas.first;
                                } else {
                                  _metricas = {..._metricas, m};
                                }
                              });
                            }),
                        ]),
                      ),
                      if (_secoes.contains(SecaoRelatorio.operadoras))
                        _secao(
                          'Recorte do ranking de operadoras',
                          'Ordene pelo indicador principal e limite a quantidade para manter o relatório conciso.',
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            AppSelect<Metrica>(
                              semanticLabel: 'Ordenar por',
                              icon: LucideIcons.arrowDownWideNarrow,
                              value: _metricas.contains(_ordenarPor) ? _ordenarPor : _metricas.first,
                              options: [for (final m in Metrica.values) if (_metricas.contains(m)) (m, 'Por ${m.nome}')],
                              onChanged: (v) => setState(() => _ordenarPor = v),
                            ),
                            AppSelect<int>(
                              semanticLabel: 'Quantidade de operadoras',
                              icon: LucideIcons.listOrdered,
                              value: _limite ?? 0,
                              options: const [
                                (10, 'Top 10 operadoras'),
                                (25, 'Top 25 operadoras'),
                                (50, 'Top 50 operadoras'),
                                (0, 'Todas do recorte'),
                              ],
                              onChanged: (v) => setState(() => _limite = v == 0 ? null : v),
                            ),
                          ]),
                        ),
                      _secao(
                        'Filtros opcionais',
                        'Deixe em branco para incluir toda a base extraída do período.',
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
              const Spacer(),
              AppButton(
                _formato == 'XLSX' ? 'Exportar planilha' : 'Exportar $_formato',
                icon: LucideIcons.fileSpreadsheet,
                loading: _gerando,
                loadingLabel: 'Gerando...',
                onPressed: podeGerar ? _gerar : null,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
