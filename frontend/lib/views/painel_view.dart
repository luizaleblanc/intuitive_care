import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/analitico_model.dart';
import '../shared/charts/charts.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/operadoras_viewmodel.dart';
import '../viewmodels/painel_viewmodel.dart';
import 'app_shell.dart';

/// Linha do grid de 12 colunas (gutter 24px).
class GridRow extends StatelessWidget {
  final List<(int, Widget)> cols;

  /// true: cards com a mesma altura (KPIs). false: alinhados pelo topo (cards de conteúdo).
  final bool mesmaAltura;
  const GridRow(this.cols, {super.key, this.mesmaAltura = true});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: mesmaAltura ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: AppLayout.gutter),
          Expanded(flex: cols[i].$1, child: cols[i].$2),
        ],
      ],
    );
    return mesmaAltura ? IntrinsicHeight(child: row) : row;
  }
}

class PainelView extends StatefulWidget {
  const PainelView({super.key});

  @override
  State<PainelView> createState() => _PainelViewState();
}

class _PainelViewState extends State<PainelView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthViewModel>().currentUser;
      final vm = context.read<PainelViewModel>();
      if (user != null && !user.isAdmin) {
        vm.aplicarPreferencias(
            ufPadrao: user.preferencias.ufPadrao, trimestrePadrao: user.preferencias.trimestrePadrao);
        final ops = context.read<OperadorasViewModel>();
        if (ops.resumo.ufs.isEmpty) ops.carregar(resumo: true);
      }
      vm.carregar();
      context.read<ShellActions>().registrarExportacao(_exportar);
    });
  }

  @override
  void deactivate() {
    context.read<ShellActions>().registrarExportacao(null);
    super.deactivate();
  }

  Future<void> _exportar() async {
    final p = context.read<PainelViewModel>().painel;
    final user = context.read<AuthViewModel>().currentUser;
    if (p == null || user == null) return;
    final periodo = fmtPeriodo(p.periodo.ano, p.periodo.trimestre);
    final vm = context.read<PainelViewModel>();
    final linhas = <List<String>>[
      ['Indicador', 'Despesas médico-hospitalares', fmtBi(p.despesasMh)],
      ['Indicador', 'Sinistralidade média', p.sinistralidade == null ? '—' : fmtPct(p.sinistralidade! * 100)],
      ['Indicador', 'Beneficiários cobertos', fmtInt(p.beneficiarios)],
      ['Indicador', 'Ticket médio por vida (trimestre)', p.ticketMedio == null ? '—' : fmtReais(p.ticketMedio!)],
      for (var i = 0; i < p.ranking.length; i++)
        ['Ranking ${i + 1}', '${p.ranking[i].nome} (${p.ranking[i].uf})', fmtBi(p.ranking[i].valor)],
      for (final s in p.serieConsumidor)
        ['Série', fmtPeriodo(s.ano, s.trimestre), fmtBi(s.valor)],
    ];
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Painel Geral · $periodo',
        subtitulo: 'UF: ${vm.uf.isEmpty ? 'Todas' : vm.uf} · Modalidade: ${vm.modalidade.isEmpty ? 'Todas' : vm.modalidade}',
        colunas: const ['Tipo', 'Descrição', 'Valor'],
        linhas: linhas,
      ),
      nomeBase: 'painel_${p.periodo.ano}_${p.periodo.trimestre}tri',
      formato: user.preferencias.formatoExportacao,
    );
    if (mounted) context.read<ToastController>().show('Relatório exportado ($nome)');
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthViewModel>().currentUser?.isAdmin ?? false;
    final vm = context.watch<PainelViewModel>();
    final p = vm.painel;

    if (p == null) {
      if (vm.error != null) return ErrorBox(vm.error!, onRetry: () => vm.carregar());
      return const LoadingBlock(label: 'Carregando painel...');
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: vm.isLoading ? 0.6 : 1,
      child: isAdmin ? _PainelAdmin(p) : _PainelConsumidor(p, vm),
    );
  }
}

// ---------------------------------------------------------------------------
// Administrador
// ---------------------------------------------------------------------------
class _PainelAdmin extends StatelessWidget {
  final PainelModel p;
  const _PainelAdmin(this.p);

  @override
  Widget build(BuildContext context) {
    final serie = p.serieAdmin.length > 8 ? p.serieAdmin.sublist(p.serieAdmin.length - 8) : p.serieAdmin;
    final crescimento = serie.length >= 2 ? variation(serie.last.valor, serie.first.valor) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridRow([
          (
            4,
            KpiCard(
              dark: true,
              label: 'Total de despesas processadas · ${fmtPeriodo(p.periodo.ano, p.periodo.trimestre)}',
              value: fmtBi(p.totalDespesas),
              delta: variation(p.totalDespesas, p.totalDespesasAnterior),
              foot: 'vs último trimestre',
              icon: LucideIcons.wallet,
            )
          ),
          (
            4,
            KpiCard(
              label: 'Registros extraídos da ANS',
              value: fmtInt(p.registrosExtraidos),
              delta: variation(p.registrosExtraidos, p.registrosExtraidosAnterior),
              foot: 'linhas no último lote',
              icon: LucideIcons.database,
            )
          ),
          (
            4,
            KpiCard(
              label: 'Operadoras ativas',
              value: fmtInt(p.operadorasAtivas),
              foot: 'cadastro CADOP · ${fmtInt(p.operadorasComDemonstracao)} com demonstração',
              icon: LucideIcons.building2,
            )
          ),
        ]),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (
            8,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeader(
                    'Evolução de despesas assistenciais',
                    subtitle: 'Eventos indenizáveis líquidos · R\$ bilhões por trimestre',
                    trailing: crescimento == null
                        ? null
                        : Pill('${fmtDelta(crescimento)} em ${serie.length} trimestres',
                            tone: crescimento >= 0 ? PillTone.ok : PillTone.danger,
                            icon: crescimento >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight),
                  ),
                  const SizedBox(height: 24),
                  PillBarChart(
                    height: 260,
                    data: [for (final s in serie) BarDatum(fmtPeriodoCurto(s.ano, s.trimestre), s.valor / 1e9)],
                  ),
                ],
              ),
            )
          ),
          (4, _DonutModalidades(p)),
        ], mesmaAltura: false),
      ],
    );
  }
}

class _DonutModalidades extends StatelessWidget {
  final PainelModel p;
  const _DonutModalidades(this.p);

  @override
  Widget build(BuildContext context) {
    final top = p.modalidades.take(4).toList();
    final resto = p.modalidades.skip(4).fold<double>(0, (s, m) => s + m.pct);
    final fatias = [
      for (var i = 0; i < top.length; i++) DonutSlice(top[i].modalidade, top[i].pct, AppColors.chart[i]),
      if (resto > 0) DonutSlice('Outras modalidades', resto, AppColors.chart[4]),
    ];
    return AppCard(
      color: AppColors.sage,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            'Distribuição por modalidade',
            size: 15,
            color: AppColors.forest,
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
              child: const Icon(LucideIcons.chartPie, size: 15, color: AppColors.forest),
            ),
          ),
          Text('Participação nas despesas do trimestre',
              style: AppText.sans(12, color: AppColors.forest.withValues(alpha: 0.75))),
          const SizedBox(height: 16),
          Center(
            child: Donut(data: fatias, center: fmtInt(p.operadorasComDemonstracao), sub: 'operadoras'),
          ),
          const SizedBox(height: 20),
          for (final f in fatias)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: f.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.forest.withValues(alpha: 0.2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f.label,
                        overflow: TextOverflow.ellipsis, style: AppText.sans(14, color: AppColors.forest)),
                  ),
                  Text(fmtPct(f.pct), style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.forest)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consumidor
// ---------------------------------------------------------------------------
class _PainelConsumidor extends StatelessWidget {
  final PainelModel p;
  final PainelViewModel vm;
  const _PainelConsumidor(this.p, this.vm);

  @override
  Widget build(BuildContext context) {
    final resumo = context.watch<OperadorasViewModel>().resumo;
    final periodo = fmtPeriodo(p.periodo.ano, p.periodo.trimestre);
    final serie =
        p.serieConsumidor.length > 8 ? p.serieConsumidor.sublist(p.serieConsumidor.length - 8) : p.serieConsumidor;
    final ufs = {...resumo.ufs, if (vm.uf.isNotEmpty) vm.uf}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Filtros', style: AppText.sans(14, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              AppSelect<String>(
                semanticLabel: 'UF',
                icon: LucideIcons.mapPin,
                value: vm.uf,
                options: [('', 'Todas UFs'), for (final u in ufs) (u, u)],
                onChanged: (v) => vm.carregar(uf: v),
              ),
              const SizedBox(width: 12),
              AppSelect<int>(
                semanticLabel: 'Ano',
                icon: LucideIcons.calendarDays,
                value: p.periodo.ano,
                options: [for (final a in vm.anosDisponiveis) (a, '$a')],
                onChanged: (v) => vm.carregar(ano: v),
              ),
              const SizedBox(width: 12),
              AppSelect<int>(
                semanticLabel: 'Trimestre',
                icon: LucideIcons.calendar,
                value: p.periodo.trimestre,
                options: [for (final t in vm.trimestresDoAno(p.periodo.ano)) (t, fmtTrimestre(t))],
                onChanged: (v) => vm.carregar(trimestre: v),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: AppSelect<String>(
                  semanticLabel: 'Modalidade',
                  icon: LucideIcons.layers,
                  value: vm.modalidade,
                  options: [('', 'Todas modalidades'), for (final m in resumo.modalidades) (m, m)],
                  onChanged: (v) => vm.carregar(modalidade: v),
                ),
              ),
              const Spacer(),
              const Icon(LucideIcons.lock, size: 13, color: AppColors.muted),
              const SizedBox(width: 8),
              Text('Modo consulta · somente leitura', style: AppText.sans(12, color: AppColors.caption)),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (
            3,
            KpiCard(
              dark: true,
              label: 'Despesas médico-hospitalares · $periodo',
              value: fmtBi(p.despesasMh),
              delta: variation(p.despesasMh, p.despesasMhAnterior),
              foot: 'vs trimestre anterior',
              icon: LucideIcons.stethoscope,
            )
          ),
          (
            3,
            KpiCard(
              label: 'Sinistralidade média',
              value: p.sinistralidade == null ? '—' : fmtPct(p.sinistralidade! * 100),
              delta: variation(p.sinistralidade, p.sinistralidadeAnterior),
              foot: 'eventos / contraprestações',
              icon: LucideIcons.percent,
            )
          ),
          (
            3,
            KpiCard(
              label: 'Beneficiários cobertos',
              value: fmtMi(p.beneficiarios),
              delta: variation(p.beneficiarios, p.beneficiariosAnterior),
              foot: 'planos médico-hospitalares',
              icon: LucideIcons.users,
            )
          ),
          (
            3,
            KpiCard(
              label: 'Ticket médio por vida',
              value: p.ticketMedio == null ? '—' : fmtReais(p.ticketMedio!),
              delta: variation(p.ticketMedio, p.ticketMedioAnterior),
              foot: 'por trimestre',
              icon: LucideIcons.heartPulse,
            )
          ),
        ]),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (5, _Ranking(p.ranking, uf: vm.uf)),
          (
            7,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeader(
                    'Despesas por trimestre',
                    subtitle: 'Médico-hospitalar · R\$ bilhões',
                    trailing: Pill('Até o $periodo', tone: PillTone.sage),
                  ),
                  const SizedBox(height: 24),
                  PillBarChart(
                    height: 240,
                    data: [for (final s in serie) BarDatum(fmtPeriodoCurto(s.ano, s.trimestre), s.valor / 1e9)],
                  ),
                ],
              ),
            )
          ),
        ], mesmaAltura: false),
      ],
    );
  }
}

class _Ranking extends StatelessWidget {
  final List<RankingItem> itens;
  final String uf;
  const _Ranking(this.itens, {required this.uf});

  @override
  Widget build(BuildContext context) {
    final maxV = itens.fold<double>(0, (m, i) => i.valor > m ? i.valor : m);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader('Maiores operadoras por despesa',
              trailing: Pill(uf.isEmpty ? 'Todas UFs' : uf, tone: PillTone.sage)),
          const SizedBox(height: 20),
          if (itens.isEmpty)
            Text('Nenhuma operadora com despesa para este recorte.', style: AppText.sans(14, color: AppColors.muted)),
          for (var i = 0; i < itens.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}', style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.muted)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nomeProprio(itens[i].nome),
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.sans(14, weight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Text(fmtBi(itens[i].valor),
                                style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.forest)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(fraction: maxV == 0 ? 0 : itens[i].valor / maxV),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
