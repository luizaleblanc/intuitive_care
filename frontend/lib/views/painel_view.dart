import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/operadoras_viewmodel.dart';
import '../viewmodels/painel_viewmodel.dart';
import 'app_shell.dart';
import 'painel/painel_admin_section.dart';
import 'painel/painel_colaborador_section.dart';

export '../shared/ui/grid_row.dart' show GridRow;

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
      if (user != null) {
        vm.aplicarPreferencias(
          ufPadrao: user.preferencias.ufPadrao,
          trimestrePadrao: user.preferencias.trimestrePadrao,
          isAdmin: user.isAdmin,
        );
        if (!user.isAdmin) {
          context.read<OperadorasViewModel>().carregarResumo();
        }
      }
      vm.carregar(escopo: user == null ? null : (user.isAdmin ? 'admin' : 'colaborador'));
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
    final periodo = fmtPeriodosSelecionados([for (final x in p.periodosSelecionados) (x.ano, x.trimestre)]);
    final vm = context.read<PainelViewModel>();
    final linhas = user.isAdmin
        ? <List<String>>[
            ['Indicador', 'Total de despesas processadas', fmtBi(p.totalDespesas)],
            ['Indicador', 'Registros extraídos da ANS', fmtInt(p.registrosExtraidos)],
            ['Indicador', 'Operadoras ativas', fmtInt(p.operadorasAtivas)],
            for (final m in p.modalidades) ['Modalidade', m.modalidade, fmtPct(m.pct)],
            for (final s in p.serieAdmin) ['Série', fmtPeriodo(s.ano, s.trimestre), fmtBi(s.valor)],
          ]
        : <List<String>>[
            ['Indicador', 'Despesas médico-hospitalares', fmtBi(p.despesasMh)],
            [
              'Indicador',
              'Sinistralidade média',
              p.sinistralidade == null ? '—' : fmtPct(p.sinistralidade! * 100),
            ],
            ['Indicador', 'Beneficiários cobertos', fmtInt(p.beneficiarios)],
            [
              'Indicador',
              'Ticket médio por vida (trimestre)',
              p.ticketMedio == null ? '—' : fmtReais(p.ticketMedio!),
            ],
            for (var i = 0; i < p.ranking.length; i++)
              ['Ranking ${i + 1}', '${p.ranking[i].nome} (${p.ranking[i].uf})', fmtBi(p.ranking[i].valor)],
            for (final s in p.serieColaborador) ['Série', fmtPeriodo(s.ano, s.trimestre), fmtBi(s.valor)],
          ];
    final nome = await Exporter.exportar(
      ExportTable(
        titulo: 'Painel Geral · $periodo',
        subtitulo:
            'UF: ${vm.uf.isEmpty ? 'Todas' : vm.uf.replaceAll(',', ', ')} · '
            'Modalidade: ${vm.modalidade.isEmpty ? 'Todas' : vm.modalidade.replaceAll(',', ', ')}',
        colunas: const ['Tipo', 'Descrição', 'Valor'],
        linhas: linhas,
      ),
      nomeBase: 'painel_${p.periodo.ano}_${p.periodo.trimestre}tri',
      formato: user.preferencias.formatoExportacao,
    );
    if (mounted) {
      context.read<ToastController>().show('Relatório exportado ($nome)');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final isAdmin = context.watch<AuthViewModel>().currentUser?.isAdmin ?? false;
    final vm = context.watch<PainelViewModel>();
    final p = vm.painel;

    if (p == null) {
      if (vm.error != null) {
        return ErrorBox(vm.error!, onRetry: () => vm.carregar());
      }
      return const LoadingBlock(label: 'Carregando painel...');
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: vm.isLoading ? 0.6 : 1,
      child: isAdmin ? PainelAdminSection(p, vm) : PainelColaboradorSection(p, vm),
    );
  }
}
