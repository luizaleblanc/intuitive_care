import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/analitico_model.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/contas_viewmodel.dart';
import 'app_shell.dart';
import 'despesas/despesas_paineis_laterais.dart';
import 'despesas/despesas_tabela_contas.dart';

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
    final atual = fmtPeriodosSelecionados([for (final x in c.periodosSelecionados) (x.ano, x.trimestre)]);
    final anterior = fmtPeriodo(c.periodoAnterior.ano, c.periodoAnterior.trimestre);
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Demonstrações contábeis · $atual',
        subtitulo: c.periodosSelecionados.length > 1
            ? 'Plano de contas ANS · total do setor em R\$ bilhões · $atual'
            : 'Plano de contas ANS · total do setor em R\$ bilhões · comparação com o $anterior',
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
    AppColors.watchDark(context);
    final vm = context.watch<ContasViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final formatoData = user?.preferencias.formatoData ?? 'DD/MM/AAAA';
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
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Competência', style: AppText.sans(14, weight: FontWeight.w600)),
                      ),
                      AppMultiSelect<int>(
                        semanticLabel: 'Anos',
                        icon: LucideIcons.calendarDays,
                        selected: vm.anos,
                        minSelected: 1,
                        options: [for (final a in vm.anosDisponiveis) (a, '$a')],
                        formatSelected: (l) => fmtAnos(l.map((e) => e.$1)),
                        onChanged: (v) => vm.carregar(anos: v),
                      ),
                      AppMultiSelect<int>(
                        semanticLabel: 'Trimestres',
                        icon: LucideIcons.calendar,
                        selected: vm.trimestres,
                        minSelected: 1,
                        options: [for (final t in vm.trimestresDosAnos(vm.anos)) (t, fmtTrimestre(t))],
                        formatSelected: (l) => fmtTrimestres(l.map((e) => e.$1)),
                        onChanged: (v) => vm.carregar(trimestres: v),
                      ),
                      AppMultiSelect<String>(
                        semanticLabel: 'Grupos de contas',
                        icon: LucideIcons.folderTree,
                        selected: vm.grupos,
                        emptyLabel: 'Todos os grupos',
                        options: [for (final g in c.grupos) (g.$1, '${g.$1} · ${g.$2}')],
                        formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} grupos',
                        onChanged: (v) => vm.carregar(grupos: v),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 12),
                  if (!vm.podeAuditar)
                    Tooltip(
                      message: 'Selecione apenas 1 ano e 1 trimestre para auditar o lote individual.',
                      child: Pill(
                        c.lote.auditado ? 'Lotes auditados' : '${c.periodosSelecionados.length} lotes selecionados',
                        tone: c.lote.auditado ? PillTone.ok : PillTone.sage,
                        icon: LucideIcons.shieldCheck,
                      ),
                    )
                  else if (c.lote.auditado)
                    Tooltip(
                      message: c.lote.auditadoPor == null
                          ? 'Lote auditado'
                          : 'Auditado por ${c.lote.auditadoPor} em ${fmtData(c.lote.auditadoEm, formato: formatoData, hora: true)}',
                      child: const Pill('Lote auditado', tone: PillTone.ok, icon: LucideIcons.shieldCheck),
                    )
                  else
                    AppButton(
                      'Auditar lote',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.shieldCheck,
                      loading: vm.isAuditing,
                      loadingLabel: 'Auditando...',
                      onPressed: _auditar,
                    ),
                  const SizedBox(width: 8),
                  AppButton(
                    'Exportar relatório',
                    variant: ButtonVariant.accent,
                    icon: LucideIcons.download,
                    onPressed: _exportar,
                  ),
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
              Expanded(flex: 8, child: DespesasTabelaContas(c, destaque: widget.contaDestacada)),
              const SizedBox(width: AppLayout.gutter),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DespesasComposicaoCard(c.composicao),
                    const SizedBox(height: AppLayout.gutter),
                    DespesasDestaquesCard(c),
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
