import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/explorar_model.dart';
import '../shared/charts/charts.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/explorar_viewmodel.dart';
import 'app_shell.dart' show ShellActions;
import 'painel_view.dart' show GridRow;

// ---------------------------------------------------------------------------
// Formatação por métrica (sempre algarismos tabulares na tela)
// ---------------------------------------------------------------------------
String fmtMetrica(Metrica m, double? v) {
  if (v == null) return '—';
  return switch (m) {
    Metrica.despesas || Metrica.receitas => v.abs() >= 1e9 ? fmtBi(v) : 'R\$ ${fmtDec1(v / 1e6)} mi',
    Metrica.sinistralidade => fmtPct(v),
    Metrica.beneficiarios => fmtMi(v),
  };
}

/// Divisor e unidade para os eixos dos gráficos.
(double, String) escalaMetrica(Metrica m, double maximo) => switch (m) {
      Metrica.despesas || Metrica.receitas => maximo >= 1e9 ? (1e9, 'bi') : (1e6, 'mi'),
      Metrica.sinistralidade => (1, '%'),
      Metrica.beneficiarios => maximo >= 1e6 ? (1e6, 'mi') : (1e3, 'mil'),
    };

bool combinacaoValida(TipoGrafico t, Metrica m) => !(t == TipoGrafico.donutSage && m == Metrica.sinistralidade);

IconData iconeTipo(TipoGrafico t) => switch (t) {
      TipoGrafico.pillBar => LucideIcons.chartColumnBig,
      TipoGrafico.donutSage => LucideIcons.chartPie,
      TipoGrafico.trendArea => LucideIcons.chartLine,
      TipoGrafico.horizontalRanking => LucideIcons.chartBarBig,
    };

class ExplorarView extends StatefulWidget {
  const ExplorarView({super.key});

  @override
  State<ExplorarView> createState() => _ExplorarViewState();
}

class _ExplorarViewState extends State<ExplorarView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<ExplorarViewModel>();
      final salvos = context.read<AuthViewModel>().currentUser?.preferencias.graficosExplorar;
      vm.definirGraficos(salvos?.map(GraficoConfig.fromJson).whereType<GraficoConfig>().toList());
      if (vm.dados == null) vm.carregar();
      context.read<ShellActions>().registrarExportacao(_exportar);
    });
  }

  @override
  void deactivate() {
    context.read<ShellActions>().registrarExportacao(null);
    super.deactivate();
  }

  Future<void> _exportar() async {
    final dados = context.read<ExplorarViewModel>().dados;
    if (dados == null) return;
    final formato = context.read<AuthViewModel>().currentUser?.preferencias.formatoExportacao ?? 'CSV';
    final toast = context.read<ToastController>();
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Exploração ANS · ${_rotuloPeriodo(dados)}',
        subtitulo: '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
        colunas: const ['Registro ANS', 'Operadora', 'UF', 'Modalidade', 'Despesas (R\$)', 'Receitas (R\$)',
          'Sinistralidade (%)', 'Beneficiários'],
        linhas: [
          for (final o in dados.operadoras)
            [
              o.registroAns,
              o.nome,
              o.uf ?? '',
              o.modalidade,
              o.valores.despesas.toStringAsFixed(2),
              o.valores.receitas.toStringAsFixed(2),
              o.valores.sinistralidade?.toStringAsFixed(2) ?? '',
              o.valores.beneficiarios.toStringAsFixed(0),
            ],
        ],
      ),
      nomeBase: 'exploracao_ans_${dados.anoInicio}_${dados.anoFim}',
      formato: formato,
    );
    toast.show('Exploração exportada ($nome)');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExplorarViewModel>();
    final dados = vm.dados;
    if (dados == null) {
      if (vm.error != null) return ErrorBox(vm.error!, onRetry: vm.carregar);
      return const LoadingBlock(label: 'Carregando exploração...');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BarraControles(vm: vm, dados: dados),
        const SizedBox(height: 12),
        _FiltrosAtivos(vm: vm),
        if (vm.error != null) ...[
          const SizedBox(height: 12),
          ErrorBox(vm.error!, onRetry: vm.carregar),
        ],
        const SizedBox(height: 12),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: vm.isLoading ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kpis(dados: dados, comparar: vm.filtros.comparar),
              const SizedBox(height: AppLayout.gutter),
              _GradeGraficos(vm: vm, dados: dados),
              const SizedBox(height: AppLayout.gutter),
              _Listagem(dados: dados),
            ],
          ),
        ),
      ],
    );
  }
}

String _rotuloAnos(List<int> anos, int ini, int fim) {
  final contiguo = anos.isEmpty || anos.length == fim - ini + 1;
  if (ini == fim) return '$ini';
  return contiguo ? '$ini–$fim' : anos.join(', ');
}

String _rotuloPeriodo(ExplorarModel d) => _rotuloAnos(d.anos, d.anoInicio, d.anoFim);

String _rotuloPonto(ExplorarModel d, PontoSerie p) => p.trimestre == null
    ? '${p.ano}${d.anosParciais.contains(p.ano) ? '*' : ''}'
    : fmtPeriodoCurto(p.ano, p.trimestre!);

// ---------------------------------------------------------------------------
// Barra de controles: período, granularidade, comparação e atalhos
// ---------------------------------------------------------------------------
class _BarraControles extends StatelessWidget {
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  const _BarraControles({required this.vm, required this.dados});

  @override
  Widget build(BuildContext context) {
    final f = vm.filtros;
    final anos = [for (final a in dados.anosDisponiveis.reversed) (a, '$a')];
    final (ini, fim) = vm.intervalo;
    final podeExportar = context.watch<AuthViewModel>().currentUser?.pode('dados.exportar') ?? false;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Linha 1: período
        Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.calendarRange, size: 16, color: AppColors.forest),
            const SizedBox(width: 8),
            Text('PERÍODO', style: AppText.eyebrow()),
          ]),
          SizedBox(
            width: 440,
            child: SegmentedPill<ModoPeriodo>(
              value: f.modo,
              options: const [
                (ModoPeriodo.ano, 'Ano'),
                (ModoPeriodo.intervalo, 'Intervalo'),
                (ModoPeriodo.ultimos, 'Últimos anos'),
                (ModoPeriodo.especificos, 'Anos específicos'),
              ],
              onChanged: (m) => vm.aplicar(f.copyWith(modo: m)),
            ),
          ),
          if (f.modo == ModoPeriodo.ano)
            AppSelect<int>(
              value: fim ?? anos.first.$1,
              options: anos,
              icon: LucideIcons.calendar,
              width: 130,
              semanticLabel: 'Ano',
              onChanged: (a) => vm.aplicar(f.copyWith(anoFim: () => a)),
            ),
          if (f.modo == ModoPeriodo.intervalo) ...[
            AppSelect<int>(
              value: ini ?? anos.last.$1,
              options: anos,
              icon: LucideIcons.calendar,
              width: 130,
              semanticLabel: 'Ano inicial',
              onChanged: (a) => vm.aplicar(f.copyWith(anoInicio: () => a, anoFim: () => fim)),
            ),
            Text('até', style: AppText.sans(13, color: AppColors.muted)),
            AppSelect<int>(
              value: fim ?? anos.first.$1,
              options: anos,
              icon: LucideIcons.calendar,
              width: 130,
              semanticLabel: 'Ano final',
              onChanged: (a) => vm.aplicar(f.copyWith(anoInicio: () => ini, anoFim: () => a)),
            ),
          ],
          if (f.modo == ModoPeriodo.especificos)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in dados.anosDisponiveis)
                _Chip(
                  rotulo: '$a',
                  ativo: vm.anosSelecionados.contains(a),
                  onTap: () {
                    final atual = {...vm.anosSelecionados};
                    // Sempre fica ao menos um ano marcado.
                    if (atual.contains(a) && atual.length == 1) return;
                    atual.contains(a) ? atual.remove(a) : atual.add(a);
                    vm.aplicar(f.copyWith(anos: atual));
                  },
                ),
            ]),
          if (f.modo == ModoPeriodo.ultimos)
            AppSelect<int>(
              value: f.ultimos.clamp(2, dados.anosDisponiveis.length < 2 ? 2 : dados.anosDisponiveis.length),
              options: [
                for (var n = 2; n <= (dados.anosDisponiveis.length < 2 ? 2 : dados.anosDisponiveis.length); n++)
                  (n, 'Últimos $n anos'),
              ],
              icon: LucideIcons.calendar,
              width: 200,
              semanticLabel: 'Quantidade de anos',
              onChanged: (n) => vm.aplicar(f.copyWith(ultimos: n)),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
        // Linha 2: visualização, comparação e ferramentas
        Row(children: [
          SizedBox(
            width: 230,
            child: SegmentedPill<String>(
              value: f.granularidade,
              options: const [('ano', 'Por ano'), ('trimestre', 'Por trimestre')],
              onChanged: (g) => vm.aplicar(f.copyWith(granularidade: g)),
            ),
          ),
          const SizedBox(width: 16),
          _Interruptor(
            ligado: f.comparar,
            rotulo: 'Comparar com período anterior',
            onChanged: (v) => vm.aplicar(f.copyWith(comparar: v)),
          ),
          const SizedBox(width: 12),
          if (vm.isLoading) const Spinner(),
          const Spacer(),
          AppButton(
            f.avancadosAtivos == 0 ? 'Filtros avançados' : 'Filtros avançados (${f.avancadosAtivos})',
            icon: LucideIcons.slidersHorizontal,
            variant: f.avancadosAtivos == 0 ? ButtonVariant.secondary : ButtonVariant.primary,
            size: ButtonSize.sm,
            onPressed: () => _abrirFiltros(context, vm, dados),
          ),
          const SizedBox(width: 8),
          AppButton(
            'Personalizar gráficos',
            icon: LucideIcons.chartNoAxesCombined,
            variant: ButtonVariant.secondary,
            size: ButtonSize.sm,
            onPressed: () => _abrirConstrutor(context, vm),
          ),
          if (!podeExportar) ...[
            const SizedBox(width: 8),
            const Tooltip(
              message: 'Exportação disponível apenas para o perfil Administrador.',
              child: Pill('Somente consulta', tone: PillTone.sage, icon: LucideIcons.eye),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Interruptor extends StatelessWidget {
  final bool ligado;
  final String rotulo;
  final ValueChanged<bool> onChanged;
  const _Interruptor({required this.ligado, required this.rotulo, required this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: ligado,
        label: rotulo,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(!ligado),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 20,
                padding: const EdgeInsets.all(2),
                alignment: ligado ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: ligado ? AppColors.forest : AppColors.slate300,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: ligado ? AppColors.mint : Colors.white, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              Text(rotulo, style: AppText.sans(13, weight: FontWeight.w500)),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Pílulas dos filtros avançados ativos (removíveis)
// ---------------------------------------------------------------------------
class _FiltrosAtivos extends StatelessWidget {
  final ExplorarViewModel vm;
  const _FiltrosAtivos({required this.vm});

  @override
  Widget build(BuildContext context) {
    final f = vm.filtros;
    final pilulas = <(String, FiltrosExplorar)>[
      for (final m in f.modalidades) (m, f.copyWith(modalidades: {...f.modalidades}..remove(m))),
      for (final u in f.ufs) ('UF $u', f.copyWith(ufs: {...f.ufs}..remove(u))),
      for (final p in f.portes) (rotulosPorte[p]!, f.copyWith(portes: {...f.portes}..remove(p))),
      for (final x in f.faixas) ('Despesa: ${rotulosFaixa[x]!}', f.copyWith(faixas: {...f.faixas}..remove(x))),
      for (final c in f.consolidacoes)
        (rotulosConsolidacao[c]!, f.copyWith(consolidacoes: {...f.consolidacoes}..remove(c))),
      if (f.status.isNotEmpty) ('Status: ${f.status}', f.copyWith(status: '')),
    ];
    if (pilulas.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (rotulo, sem) in pilulas)
          InputChip(
            label: Text(rotulo, style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.forest)),
            backgroundColor: AppColors.sage,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            deleteIcon: const Icon(LucideIcons.x, size: 14, color: AppColors.forest),
            deleteButtonTooltipMessage: 'Remover filtro',
            onDeleted: () => vm.aplicar(sem),
          ),
        TextButton(
          onPressed: () => vm.aplicar(f.semAvancados()),
          child: Text('Limpar filtros', style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.forest)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// KPIs reativos (com variação quando a comparação está ligada)
// ---------------------------------------------------------------------------
class _Kpis extends StatelessWidget {
  final ExplorarModel dados;
  final bool comparar;
  const _Kpis({required this.dados, required this.comparar});

  @override
  Widget build(BuildContext context) {
    final ant = dados.kpisAnteriores;
    final periodoAnt = dados.periodoAnterior;
    final foot = !comparar
        ? 'Período ${_rotuloPeriodo(dados)}'
        : ant == null
            ? 'Sem dados no período anterior'
            : 'vs ${_rotuloAnos(dados.anosAnteriores, periodoAnt!.$1, periodoAnt.$2)}';
    double? delta(Metrica m) => comparar && ant != null ? variation(dados.kpis.de(m), ant.de(m)) : null;
    return GridRow([
      (3, KpiCard(dark: true, label: 'Despesas assistenciais', value: fmtMetrica(Metrica.despesas, dados.kpis.despesas),
          delta: delta(Metrica.despesas), foot: foot, icon: LucideIcons.wallet)),
      (3, KpiCard(label: 'Receitas (contraprestações)', value: fmtMetrica(Metrica.receitas, dados.kpis.receitas),
          delta: delta(Metrica.receitas), foot: foot, icon: LucideIcons.trendingUp)),
      (3, KpiCard(label: 'Sinistralidade do recorte', value: fmtMetrica(Metrica.sinistralidade, dados.kpis.sinistralidade),
          delta: delta(Metrica.sinistralidade), foot: foot, icon: LucideIcons.activity)),
      (3, KpiCard(label: 'Beneficiários', value: fmtMetrica(Metrica.beneficiarios, dados.kpis.beneficiarios),
          delta: delta(Metrica.beneficiarios), foot: '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
          icon: LucideIcons.users)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Grade de gráficos escolhidos pelo usuário (2 por linha)
// ---------------------------------------------------------------------------
class _GradeGraficos extends StatelessWidget {
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  const _GradeGraficos({required this.vm, required this.dados});

  @override
  Widget build(BuildContext context) {
    final graficos = vm.graficos;
    if (graficos.isEmpty) {
      return AppCard(
        child: Column(children: [
          const Icon(LucideIcons.chartNoAxesCombined, size: 28, color: AppColors.forest),
          const SizedBox(height: 8),
          Text('Nenhum gráfico na tela', style: AppText.cardTitle()),
          const SizedBox(height: 4),
          Text('Escolha os gráficos e as métricas que quer acompanhar.', style: AppText.sans(14, color: AppColors.muted)),
          const SizedBox(height: 16),
          AppButton('Personalizar gráficos', icon: LucideIcons.plus, onPressed: () => _abrirConstrutor(context, vm)),
        ]),
      );
    }
    final linhas = <Widget>[];
    for (var i = 0; i < graficos.length; i += 2) {
      if (i > 0) linhas.add(const SizedBox(height: AppLayout.gutter));
      linhas.add(GridRow([
        (6, _CartaoGrafico(indice: i, config: graficos[i], vm: vm, dados: dados)),
        (6, i + 1 < graficos.length
            ? _CartaoGrafico(indice: i + 1, config: graficos[i + 1], vm: vm, dados: dados)
            : const SizedBox.shrink()),
      ], mesmaAltura: false));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas);
  }
}

class _CartaoGrafico extends StatelessWidget {
  final int indice;
  final GraficoConfig config;
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  const _CartaoGrafico({required this.indice, required this.config, required this.vm, required this.dados});

  @override
  Widget build(BuildContext context) {
    final sage = config.tipo == TipoGrafico.donutSage;
    final cor = sage ? AppColors.forest : AppColors.ink;
    return AppCard(
      color: sage ? AppColors.sage : Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            '${config.metrica.nome} · ${_subtitulo()}',
            subtitle: '${config.tipo.nome} · ${config.metrica.descricao}',
            size: 15,
            color: cor,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconButton(
                icon: LucideIcons.pencil,
                label: 'Editar gráfico',
                size: 32,
                onPressed: () => _abrirConstrutor(context, vm, editar: indice),
              ),
              const SizedBox(width: 4),
              AppIconButton(
                icon: LucideIcons.x,
                label: 'Remover gráfico',
                size: 32,
                onPressed: () => vm.removerGrafico(indice),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _corpo(context),
        ],
      ),
    );
  }

  String _subtitulo() => switch (config.tipo) {
        TipoGrafico.donutSage => 'por modalidade',
        TipoGrafico.horizontalRanking => 'top operadoras',
        _ => dados.granularidade == 'ano' ? 'por ano' : 'por trimestre',
      };

  Widget _corpo(BuildContext context) {
    final m = config.metrica;
    switch (config.tipo) {
      case TipoGrafico.pillBar:
      case TipoGrafico.trendArea:
        final valores = [for (final p in dados.serie) p.valores.de(m) ?? 0];
        final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);
        final (div, unidade) = escalaMetrica(m, maximo);
        final serie = [
          for (final p in dados.serie) BarDatum(_rotuloPonto(dados, p), (p.valores.de(m) ?? 0) / div),
        ];
        if (config.tipo == TipoGrafico.pillBar) {
          return PillBarChart(data: serie.length > 12 ? serie.sublist(serie.length - 12) : serie, height: 240, unit: unidade);
        }
        return TrendAreaChart(
          data: serie,
          unit: unidade,
          comparacao: [
            for (final p in dados.serieAnterior) BarDatum(_rotuloPonto(dados, p), (p.valores.de(m) ?? 0) / div),
          ],
        );
      case TipoGrafico.donutSage:
        final total = dados.porModalidade.fold<double>(0, (s, x) => s + (x.valores.de(m) ?? 0));
        if (total <= 0) {
          return Text('Sem dados para o recorte.', style: AppText.sans(14, color: AppColors.forest));
        }
        final top = dados.porModalidade.take(5).toList();
        final resto = dados.porModalidade.skip(5).fold<double>(0, (s, x) => s + (x.valores.de(m) ?? 0));
        final fatias = [
          for (var i = 0; i < top.length; i++)
            DonutSlice(top[i].modalidade, (top[i].valores.de(m) ?? 0) / total * 100, AppColors.chart[i]),
          if (resto > 0) DonutSlice('Outras modalidades', resto / total * 100, AppColors.chart[5]),
        ];
        return Row(
          children: [
            Donut(data: fatias, center: fmtInt(dados.totalOperadoras), sub: 'operadoras'),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (final f in fatias)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: f.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: AppColors.forest)),
                        ),
                        Text(fmtPct(f.pct), style: AppText.numeric(12, color: AppColors.forest)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        );
      case TipoGrafico.horizontalRanking:
        final candidatos = dados.operadoras.where((o) {
          final v = o.valores.de(m);
          // Sinistralidade só faz sentido com receita relevante (evita razões de base mínima).
          return v != null && (m != Metrica.sinistralidade || o.valores.receitas >= 1e6);
        }).toList()
          ..sort((a, b) => (b.valores.de(m) ?? 0).compareTo(a.valores.de(m) ?? 0));
        final top = candidatos.take(8).toList();
        return HorizontalRanking(
          itens: [
            for (final o in top)
              ItemRanking(nomeProprio(o.nome), o.valores.de(m) ?? 0, fmtMetrica(m, o.valores.de(m)),
                  detalhe: '${o.modalidade}${o.uf == null ? '' : ' · ${o.uf}'}'),
          ],
          onTap: (i) => context.go('/operadoras?q=${top[i].registroAns}'),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Listagem detalhada (ordenável, paginada)
// ---------------------------------------------------------------------------
class _Listagem extends StatefulWidget {
  final ExplorarModel dados;
  const _Listagem({required this.dados});

  @override
  State<_Listagem> createState() => _ListagemState();
}

class _ListagemState extends State<_Listagem> {
  static const _porPagina = 15;
  Metrica _ordem = Metrica.despesas;
  bool _desc = true;
  int _pagina = 0;

  @override
  void didUpdateWidget(covariant _Listagem old) {
    super.didUpdateWidget(old);
    if (old.dados != widget.dados) _pagina = 0;
  }

  void _ordenar(Metrica m) => setState(() {
        _desc = _ordem == m ? !_desc : true;
        _ordem = m;
        _pagina = 0;
      });

  @override
  Widget build(BuildContext context) {
    final itens = [...widget.dados.operadoras]..sort((a, b) {
        final c = (a.valores.de(_ordem) ?? -1).compareTo(b.valores.de(_ordem) ?? -1);
        return _desc ? -c : c;
      });
    final paginas = (itens.length / _porPagina).ceil().clamp(1, 1 << 20);
    final pagina = itens.skip(_pagina * _porPagina).take(_porPagina).toList();

    Widget cabecalho(String t, {Metrica? m, int flex = 2, bool direita = true}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: m == null ? null : () => _ordenar(m),
            child: Row(
              mainAxisAlignment: direita ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(child: Text(t.toUpperCase(), overflow: TextOverflow.ellipsis, style: AppText.eyebrow())),
                if (m != null && m == _ordem)
                  Icon(_desc ? LucideIcons.arrowDown : LucideIcons.arrowUp, size: 12, color: AppColors.forest),
              ],
            ),
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            'Operadoras no recorte',
            subtitle: '${fmtInt(widget.dados.totalOperadoras)} operadoras · clique no título de uma coluna para ordenar',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              cabecalho('Operadora', flex: 5, direita: false),
              cabecalho('UF', flex: 1, direita: false),
              cabecalho('Modalidade', flex: 3, direita: false),
              cabecalho('Despesas', m: Metrica.despesas),
              cabecalho('Receitas', m: Metrica.receitas),
              cabecalho('Sinistr.', m: Metrica.sinistralidade),
              cabecalho('Benef.', m: Metrica.beneficiarios),
            ]),
          ),
          const Divider(height: 1, color: AppColors.slate200),
          if (pagina.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Nenhuma operadora com esses filtros. Remova algum filtro para ampliar o recorte.',
                    style: AppText.sans(14, color: AppColors.muted)),
              ),
            ),
          for (final o in pagina)
            InkWell(
              onTap: () => context.go('/operadoras?q=${o.registroAns}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nomeProprio(o.nome),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w600)),
                      Text('Reg. ANS ${o.registroAns}${o.status == 'Inativa' ? ' · Inativa' : ''}',
                          style: AppText.numeric(11, weight: FontWeight.w400, color: AppColors.muted)),
                    ]),
                  ),
                  Expanded(flex: 1, child: Text(o.uf ?? '—', style: AppText.sans(13))),
                  Expanded(
                    flex: 3,
                    child: Text(o.modalidade, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13)),
                  ),
                  for (final m in Metrica.values)
                    Expanded(
                      flex: 2,
                      child: Text(fmtMetrica(m, o.valores.de(m)),
                          textAlign: TextAlign.right, style: AppText.numeric(13, weight: FontWeight.w500)),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Text('Página ${_pagina + 1} de $paginas', style: AppText.numeric(12, weight: FontWeight.w500, color: AppColors.muted)),
            const Spacer(),
            AppIconButton(
              icon: LucideIcons.chevronLeft,
              label: 'Página anterior',
              size: 32,
              onPressed: _pagina == 0 ? null : () => setState(() => _pagina--),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: LucideIcons.chevronRight,
              label: 'Próxima página',
              size: 32,
              onPressed: _pagina >= paginas - 1 ? null : () => setState(() => _pagina++),
            ),
          ]),
          if (widget.dados.granularidade == 'ano' && widget.dados.anosParciais.any((a) => a >= widget.dados.anoInicio && a <= widget.dados.anoFim)) ...[
            const SizedBox(height: 8),
            Text('* Ano com trimestres ainda não publicados pela ANS: valores anuais parciais.',
                style: AppText.sans(12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer: filtros avançados com facetas reais do dataset
// ---------------------------------------------------------------------------
void _abrirFiltros(BuildContext context, ExplorarViewModel vm, ExplorarModel dados) {
  showSideDrawer<void>(context, width: 480, builder: (_) => _PainelFiltros(vm: vm, facetas: dados.facetas));
}

class _PainelFiltros extends StatefulWidget {
  final ExplorarViewModel vm;
  final Facetas facetas;
  const _PainelFiltros({required this.vm, required this.facetas});

  @override
  State<_PainelFiltros> createState() => _PainelFiltrosState();
}

class _PainelFiltrosState extends State<_PainelFiltros> {
  late FiltrosExplorar _f = widget.vm.filtros;

  Widget _secao(String titulo, String ajuda, Widget conteudo) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.forest)),
          const SizedBox(height: 2),
          Text(ajuda, style: AppText.sans(12, color: AppColors.forest.withValues(alpha: 0.7))),
          const SizedBox(height: 10),
          conteudo,
        ]),
      );

  Widget _chips(List<(String, String)> opcoes, bool Function(String) ativo, void Function(String) alternar) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (valor, rotulo) in opcoes)
            _Chip(rotulo: rotulo, ativo: ativo(valor), onTap: () => setState(() => alternar(valor))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final fac = widget.facetas;
    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Row(children: [
              Expanded(child: Text('Filtros avançados', style: AppText.display(20, color: AppColors.forest))),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _secao('Modalidade da operadora', 'Selecione uma ou mais.', _chips(
                  [for (final m in fac.modalidades) (m, m)],
                  _f.modalidades.contains,
                  (m) => _f = _f.copyWith(modalidades: _f.modalidades.contains(m)
                      ? ({..._f.modalidades}..remove(m))
                      : {..._f.modalidades, m}),
                )),
                _secao('UF / Região', 'Estado da sede da operadora.', _chips(
                  [for (final u in fac.ufs) (u, u)],
                  _f.ufs.contains,
                  (u) => _f = _f.copyWith(ufs: _f.ufs.contains(u) ? ({..._f.ufs}..remove(u)) : {..._f.ufs, u}),
                )),
                _secao('Porte (faixa de beneficiários)', 'Classificação da ANS. Selecione um ou mais.', _chips(
                  [for (final e in rotulosPorte.entries) (e.key, '${e.value} · ${descricoesPorte[e.key]}')],
                  _f.portes.contains,
                  (v) => _f = _f.copyWith(portes: _alternar(_f.portes, v)),
                )),
                _secao('Faixa de despesa no período', 'Soma das despesas da operadora no recorte. Selecione uma ou mais.',
                    _chips(
                  [for (final e in rotulosFaixa.entries) (e.key, e.value)],
                  _f.faixas.contains,
                  (v) => _f = _f.copyWith(faixas: _alternar(_f.faixas, v)),
                )),
                _secao('Status de consolidação', 'Trimestres com lote auditado ou pendente. Selecione um ou ambos.', _chips(
                  [for (final e in rotulosConsolidacao.entries) (e.key, e.value)],
                  _f.consolidacoes.contains,
                  (v) => _f = _f.copyWith(consolidacoes: _alternar(_f.consolidacoes, v)),
                )),
                if (fac.status.length > 1)
                  _secao('Status da operadora', 'Visível apenas para Administrador.', _chips(
                    [for (final s in fac.status) (s, s)],
                    (v) => _f.status == v,
                    (v) => _f = _f.copyWith(status: _f.status == v ? '' : v),
                  )),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AppButton('Limpar', variant: ButtonVariant.ghost, onPressed: () => setState(() => _f = _f.semAvancados())),
              const Spacer(),
              AppButton('Aplicar filtros', icon: LucideIcons.check, onPressed: () {
                widget.vm.aplicar(_f);
                Navigator.of(context).pop();
              }),
            ]),
          ),
        ],
      ),
    );
  }
}

Set<String> _alternar(Set<String> atual, String v) => atual.contains(v) ? ({...atual}..remove(v)) : {...atual, v};

class _Chip extends StatelessWidget {
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;
  const _Chip({required this.rotulo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: ativo,
        button: true,
        child: Material(
          color: ativo ? AppColors.forest : Colors.white,
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
                    style: AppText.sans(12, weight: FontWeight.w600, color: ativo ? Colors.white : AppColors.forest)),
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Drawer: construtor de gráficos (tipo × métrica)
// ---------------------------------------------------------------------------
void _abrirConstrutor(BuildContext context, ExplorarViewModel vm, {int? editar}) {
  showSideDrawer<void>(context, width: 520, builder: (_) => _Construtor(vm: vm, editar: editar));
}

class _Construtor extends StatefulWidget {
  final ExplorarViewModel vm;
  final int? editar;
  const _Construtor({required this.vm, this.editar});

  @override
  State<_Construtor> createState() => _ConstrutorState();
}

class _ConstrutorState extends State<_Construtor> {
  late final List<GraficoConfig> _lista = List.of(widget.vm.graficos);
  late int? _selecionado = widget.editar ?? (_lista.isEmpty ? null : 0);
  late TipoGrafico _tipo = _selecionado == null ? TipoGrafico.pillBar : _lista[_selecionado!].tipo;
  late Metrica _metrica = _selecionado == null ? Metrica.despesas : _lista[_selecionado!].metrica;
  bool _salvando = false;

  void _selecionar(int? i) => setState(() {
        _selecionado = i;
        if (i != null) {
          _tipo = _lista[i].tipo;
          _metrica = _lista[i].metrica;
        }
      });

  void _atualizar({TipoGrafico? tipo, Metrica? metrica}) => setState(() {
        _tipo = tipo ?? _tipo;
        _metrica = metrica ?? _metrica;
        if (!combinacaoValida(_tipo, _metrica)) _metrica = Metrica.despesas;
        if (_selecionado != null) _lista[_selecionado!] = GraficoConfig(_tipo, _metrica);
      });

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final vm = widget.vm;
    final auth = context.read<AuthViewModel>();
    final toast = context.read<ToastController>();
    vm.definirGraficos(_lista);
    if (_lista.isEmpty) {
      while (vm.graficos.isNotEmpty) {
        vm.removerGrafico(0);
      }
    }
    final ok = await auth.updateProfile({'preferencias': {'graficos_explorar': vm.graficosJson}});
    if (!mounted) return;
    toast.show(ok ? 'Gráficos salvos no seu perfil' : 'Gráficos aplicados (não foi possível salvar no perfil)',
        error: !ok);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
            child: Row(children: [
              Expanded(child: Text('Personalizar gráficos', style: AppText.display(20, color: AppColors.forest))),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Escolha o tipo de gráfico e a métrica. O layout fica salvo no seu perfil (até 8 gráficos).',
                style: AppText.sans(13, color: AppColors.forest.withValues(alpha: 0.75))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('NA TELA', style: AppText.eyebrow(color: AppColors.forest)),
                const SizedBox(height: 8),
                for (var i = 0; i < _lista.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: _selecionado == i ? Colors.white : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _selecionar(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selecionado == i ? AppColors.forest : Colors.transparent, width: 1.5),
                          ),
                          child: Row(children: [
                            Icon(iconeTipo(_lista[i].tipo), size: 18, color: AppColors.forest),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${_lista[i].metrica.nome} · ${_lista[i].tipo.nome}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w600)),
                            ),
                            AppIconButton(
                              icon: LucideIcons.arrowUp,
                              label: 'Mover para cima',
                              size: 28,
                              onPressed: i == 0
                                  ? null
                                  : () => setState(() {
                                        _lista.insert(i - 1, _lista.removeAt(i));
                                        _selecionado = i - 1;
                                      }),
                            ),
                            AppIconButton(
                              icon: LucideIcons.trash2,
                              label: 'Remover',
                              size: 28,
                              onPressed: () => setState(() {
                                _lista.removeAt(i);
                                _selecionado = _lista.isEmpty ? null : 0;
                              }),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    'Adicionar gráfico',
                    icon: LucideIcons.plus,
                    variant: ButtonVariant.secondary,
                    size: ButtonSize.sm,
                    onPressed: _lista.length >= 8
                        ? null
                        : () => setState(() {
                              _lista.add(GraficoConfig(_tipo, _metrica));
                              _selecionado = _lista.length - 1;
                            }),
                  ),
                ),
                if (_selecionado != null) ...[
                  const SizedBox(height: 24),
                  Text('TIPO DE GRÁFICO', style: AppText.eyebrow(color: AppColors.forest)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.3,
                    children: [
                      for (final t in TipoGrafico.values)
                        _OpcaoTipo(tipo: t, ativo: _tipo == t, onTap: () => _atualizar(tipo: t)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('MÉTRICA', style: AppText.eyebrow(color: AppColors.forest)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in Metrica.values)
                      Opacity(
                        opacity: combinacaoValida(_tipo, m) ? 1 : 0.4,
                        child: _Chip(
                          rotulo: m.nome,
                          ativo: _metrica == m,
                          onTap: () {
                            if (combinacaoValida(_tipo, m)) _atualizar(metrica: m);
                          },
                        ),
                      ),
                  ]),
                  if (_tipo == TipoGrafico.donutSage) ...[
                    const SizedBox(height: 8),
                    Text('Sinistralidade é uma razão e não se soma entre modalidades, por isso não entra na rosca.',
                        style: AppText.sans(12, color: AppColors.forest.withValues(alpha: 0.75))),
                  ],
                ],
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AppButton('Restaurar padrão',
                  variant: ButtonVariant.ghost,
                  onPressed: () => setState(() {
                        _lista
                          ..clear()
                          ..addAll(GraficoConfig.padrao);
                        _selecionar(0);
                      })),
              const Spacer(),
              AppButton('Aplicar', icon: LucideIcons.check, loading: _salvando, onPressed: _salvar),
            ]),
          ),
        ],
      ),
    );
  }
}

class _OpcaoTipo extends StatelessWidget {
  final TipoGrafico tipo;
  final bool ativo;
  final VoidCallback onTap;
  const _OpcaoTipo({required this.tipo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: ativo,
        button: true,
        child: Material(
          color: ativo ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(iconeTipo(tipo), size: 20, color: ativo ? AppColors.mint : AppColors.forest),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tipo.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(12, weight: FontWeight.w700, color: ativo ? Colors.white : AppColors.ink)),
                      Text(tipo.usoIdeal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(11, color: ativo ? Colors.white70 : AppColors.muted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
