import 'dart:math' as math;

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
import '../viewmodels/contas_viewmodel.dart';
import 'app_shell.dart';
import 'painel_view.dart' show GridRow;

class DespesasView extends StatefulWidget {
  final String? contaDestacada;
  const DespesasView({super.key, this.contaDestacada});

  @override
  State<DespesasView> createState() => _DespesasViewState();
}

class _DespesasViewState extends State<DespesasView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContasViewModel>().carregar();
      context.read<ShellActions>().registrarExportacao(_exportar);
    });
  }

  @override
  void deactivate() {
    context.read<ShellActions>().registrarExportacao(null);
    super.deactivate();
  }

  Future<void> _exportar() async {
    final c = context.read<ContasViewModel>().contas;
    final formato = context.read<AuthViewModel>().currentUser?.preferencias.formatoExportacao ?? 'CSV';
    if (c == null) return;
    final atual = fmtPeriodo(c.periodo.ano, c.periodo.trimestre);
    final anterior = fmtPeriodo(c.periodoAnterior.ano, c.periodoAnterior.trimestre);
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Demonstrações contábeis · $atual',
        subtitulo: 'Plano de contas ANS · total do setor em R\$ bilhões · comparação com o $anterior',
        colunas: ['Conta', 'Descrição', 'Grupo', atual, anterior, 'Variação'],
        linhas: [
          for (final l in c.contas)
            [
              l.codigo,
              l.descricao,
              l.grupo,
              fmtBiNum(l.valorAtual / 1e9),
              l.valorAnterior == null ? '—' : fmtBiNum(l.valorAnterior! / 1e9),
              variation(l.valorAtual, l.valorAnterior) == null ? '—' : fmtDelta(variation(l.valorAtual, l.valorAnterior)!),
            ],
        ],
      ),
      nomeBase: 'despesas_contabeis_${c.periodo.ano}_${c.periodo.trimestre}tri',
      formato: formato,
    );
    if (mounted) context.read<ToastController>().show('Relatório exportado ($nome)');
  }

  Future<void> _auditar() async {
    final vm = context.read<ContasViewModel>();
    final toast = context.read<ToastController>();
    final msg = await vm.auditarLote();
    if (msg != null) {
      toast.show(msg);
    } else if (vm.error != null) {
      toast.show(vm.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ContasViewModel>();
    final isAdmin = context.watch<AuthViewModel>().currentUser?.isAdmin ?? false;
    final c = vm.contas;
    if (c == null) {
      if (vm.error != null) return ErrorBox(vm.error!, onRetry: () => vm.carregar());
      return const LoadingBlock(label: 'Carregando demonstrações contábeis...');
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: vm.isLoading ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Competência', style: AppText.sans(14, weight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                AppSelect<int>(
                  semanticLabel: 'Ano',
                  icon: LucideIcons.calendarDays,
                  value: c.periodo.ano,
                  options: [for (final a in vm.anosDisponiveis) (a, '$a')],
                  onChanged: (v) => vm.carregar(ano: v),
                ),
                const SizedBox(width: 12),
                AppSelect<int>(
                  semanticLabel: 'Trimestre',
                  icon: LucideIcons.calendar,
                  value: c.periodo.trimestre,
                  options: [for (final t in vm.trimestresDoAno(c.periodo.ano)) (t, fmtTrimestre(t))],
                  onChanged: (v) => vm.carregar(trimestre: v),
                ),
                const SizedBox(width: 12),
                AppSelect<String>(
                  semanticLabel: 'Grupo de contas',
                  icon: LucideIcons.folderTree,
                  value: vm.grupo,
                  options: [('', 'Todos os grupos'), for (final g in c.grupos) (g.$1, '${g.$1} · ${g.$2}')],
                  onChanged: (v) => vm.carregar(grupo: v),
                ),
                const Spacer(),
                if (isAdmin) ...[
                  if (c.lote.auditado)
                    Tooltip(
                      message: c.lote.auditadoPor == null
                          ? 'Lote auditado'
                          : 'Auditado por ${c.lote.auditadoPor} em ${fmtData(c.lote.auditadoEm, hora: true)}',
                      child: const Pill('Lote auditado', tone: PillTone.ok, icon: LucideIcons.shieldCheck),
                    )
                  else
                    AppButton('Auditar lote',
                        variant: ButtonVariant.secondary,
                        icon: LucideIcons.shieldCheck,
                        loading: vm.isAuditing,
                        loadingLabel: 'Auditando...',
                        onPressed: _auditar),
                  const SizedBox(width: 8),
                  AppButton('Exportar relatório',
                      variant: ButtonVariant.accent, icon: LucideIcons.download, onPressed: _exportar),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppLayout.gutter),
          GridRow([
            (4, _kpi(c, '41', 'Eventos conhecidos (conta 41)', LucideIcons.receipt, dark: true)),
            (4, _kpi(c, '46', 'Despesas administrativas (46)', LucideIcons.briefcase)),
            (4, _kpi(c, '43', 'Comercialização (43)', LucideIcons.megaphone)),
          ]),
          const SizedBox(height: AppLayout.gutter),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: _TabelaContas(c, destaque: widget.contaDestacada)),
              const SizedBox(width: AppLayout.gutter),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Composicao(c.composicao),
                    const SizedBox(height: AppLayout.gutter),
                    _Destaques(c),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(ContasModel c, String conta, String label, IconData icon, {bool dark = false}) {
    final k = c.kpis[conta] ?? (0.0, null);
    return KpiCard(
      dark: dark,
      label: label,
      value: fmtBi(k.$1),
      delta: variation(k.$1, k.$2),
      foot: 'vs competência anterior',
      icon: icon,
    );
  }
}

class _TabelaContas extends StatelessWidget {
  final ContasModel c;
  final String? destaque;
  const _TabelaContas(this.c, {this.destaque});

  static const _flex = [12, 36, 20, 12, 12];

  @override
  Widget build(BuildContext context) {
    final maxV = c.contas.fold<double>(
        0, (m, l) => math.max(m, math.max(l.valorAtual.abs(), (l.valorAnterior ?? 0).abs())));
    Widget th(String t, int i, {TextAlign align = TextAlign.left}) => Expanded(
          flex: _flex[i],
          child: Text(t.toUpperCase(),
              textAlign: align,
              style: AppText.sans(11, weight: FontWeight.w700, color: Colors.white, spacing: 11 * 0.05)),
        );
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: CardHeader(
              'Demonstrações contábeis · plano de contas ANS',
              subtitle: 'Total do setor em R\$ bilhões · ${fmtPeriodo(c.periodo.ano, c.periodo.trimestre)} '
                  'vs ${fmtTrimestre(c.periodoAnterior.trimestre)} de ${c.periodoAnterior.ano}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legenda(AppColors.forest, 'Atual'),
                  const SizedBox(width: 16),
                  _legenda(AppColors.mint.withValues(alpha: 0.5), 'Anterior'),
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.forest,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              th('Conta', 0),
              th('Descrição', 1),
              th('Comparativo', 2),
              th('Atual', 3, align: TextAlign.right),
              th('Var.', 4, align: TextAlign.right),
            ]),
          ),
          if (c.contas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text('Sem contas para o filtro selecionado.',
                  textAlign: TextAlign.center, style: AppText.sans(14, color: AppColors.muted)),
            ),
          for (final l in c.contas) _LinhaConta(l, maxV: maxV, flex: _flex, destacada: l.codigo == destaque),
        ],
      ),
    );
  }

  Widget _legenda(Color cor, String t) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: AppText.sans(12, color: AppColors.muted)),
      ]);
}

class _LinhaConta extends StatefulWidget {
  final ContaLinha l;
  final double maxV;
  final List<int> flex;
  final bool destacada;
  const _LinhaConta(this.l, {required this.maxV, required this.flex, required this.destacada});

  @override
  State<_LinhaConta> createState() => _LinhaContaState();
}

class _LinhaContaState extends State<_LinhaConta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final f = widget.flex;
    final v = variation(l.valorAtual, l.valorAnterior);
    double frac(double? x) => widget.maxV == 0 || x == null ? 0 : x.abs() / widget.maxV;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: widget.destacada
              ? AppColors.mint.withValues(alpha: 0.12)
              : (_hover ? AppColors.surface.withValues(alpha: 0.6) : Colors.white),
          border: const Border(top: BorderSide(color: AppColors.slate100)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: f[0],
              child: Padding(
                padding: EdgeInsets.only(left: l.nivel * 10.0),
                child: Text(l.codigo, style: AppText.mono(14)),
              ),
            ),
            Expanded(
              flex: f[1],
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_capitalizar(l.descricao),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(14, weight: l.nivel == 0 ? FontWeight.w700 : FontWeight.w500)),
                    Text(l.grupo, style: AppText.sans(11, color: AppColors.caption)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: f[2],
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    ProgressBar(fraction: frac(l.valorAtual), height: 6, color: AppColors.forest, track: Colors.transparent),
                    const SizedBox(height: 4),
                    ProgressBar(
                        fraction: frac(l.valorAnterior),
                        height: 6,
                        color: AppColors.mint.withValues(alpha: 0.5),
                        track: Colors.transparent),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: f[3],
              child: Text(fmtBiNum(l.valorAtual / 1e9),
                  textAlign: TextAlign.right, style: AppText.sans(14, weight: FontWeight.w600)),
            ),
            Expanded(
              flex: f[4],
              child: Align(
                alignment: Alignment.centerRight,
                child: v == null ? Text('—', style: AppText.sans(14, color: AppColors.muted)) : DeltaBadge(value: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Descrições do plano de contas vêm em CAIXA ALTA: exibe só a primeira letra maiúscula.
String _capitalizar(String s) {
  final t = s.trim();
  if (t.isEmpty || t != t.toUpperCase()) return t;
  final lower = t.toLowerCase().replaceAll(' sus', ' SUS').replaceAll('(sus)', '(SUS)');
  final i = lower.indexOf(RegExp(r'[a-zà-ú]'));
  return i < 0 ? lower : lower.substring(0, i) + lower[i].toUpperCase() + lower.substring(i + 1);
}

class _Composicao extends StatelessWidget {
  final List<ComposicaoItem> itens;
  const _Composicao(this.itens);

  @override
  Widget build(BuildContext context) => AppCard(
        color: AppColors.sage,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Composição médico-hospitalar',
                style: AppText.display(15, weight: FontWeight.w700, color: AppColors.forest)),
            Text('Eventos conhecidos por forma de pagamento',
                style: AppText.sans(12, color: AppColors.forest.withValues(alpha: 0.75))),
            const SizedBox(height: 20),
            if (itens.isEmpty) Text('Sem dados no período.', style: AppText.sans(14, color: AppColors.forest)),
            for (final i in itens.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(i.forma,
                              style: AppText.sans(14, weight: FontWeight.w500, color: AppColors.forest))),
                      Text(fmtPct(i.pct), style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.forest)),
                    ]),
                    const SizedBox(height: 6),
                    ProgressBar(
                        fraction: i.pct / 100,
                        height: 10,
                        color: AppColors.forest,
                        track: Colors.white.withValues(alpha: 0.6)),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Destaques extends StatelessWidget {
  final ContasModel c;
  const _Destaques(this.c);

  @override
  Widget build(BuildContext context) {
    final mh = c.composicao.isEmpty ? null : c.composicao.first;
    final itens = <(IconData, Color, Color, InlineSpan)>[
      for (final d in c.destaques)
        (
          d.variacao >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          d.variacao >= 0 ? AppColors.emerald50 : AppColors.red50,
          d.variacao >= 0 ? AppColors.emerald700 : AppColors.red600,
          TextSpan(children: [
            TextSpan(text: '${_capitalizar(d.descricao)} ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: '(${d.codigo}) ${d.variacao >= 0 ? 'cresceu' : 'recuou'} ${fmtPct(d.variacao.abs())}.'),
          ]),
        ),
      if (mh != null)
        (
          LucideIcons.info,
          AppColors.sage,
          AppColors.forest,
          TextSpan(children: [
            TextSpan(text: 'Pagamento ${mh.forma.toLowerCase()} ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: 'segue como ${fmtPct(mh.pct)} dos eventos médico-hospitalares.'),
          ]),
        ),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Destaques da competência', style: AppText.display(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(color: i.$2, shape: BoxShape.circle),
                    child: Icon(i.$1, size: 13, color: i.$3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text.rich(i.$4, style: AppText.sans(14, height: 1.45))),
                ],
              ),
            ),
          if (c.lote.registrosExtraidos > 0)
            Text(
              'Lote: ${fmtInt(c.lote.registrosExtraidos)} registros de ${fmtInt(c.lote.operadoras)} operadoras.',
              style: AppText.sans(12, color: AppColors.caption),
            ),
        ],
      ),
    );
  }
}
