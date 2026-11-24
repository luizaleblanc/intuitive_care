import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/explorar_model.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/explorar_viewmodel.dart';
import 'app_shell.dart' show ShellActions;
import 'explorar/explorar_construtor_drawer.dart';
import 'explorar/explorar_controles.dart';
import 'explorar/explorar_filtros_drawer.dart';
import 'explorar/explorar_formatters.dart';
import 'explorar/explorar_kpis_e_graficos.dart';
import 'explorar/explorar_listagem.dart';

export 'explorar/explorar_formatters.dart' show combinacaoValida, escalaMetrica, fmtMetrica, iconeTipo;

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
        titulo: 'Exploração ANS · ${rotuloPeriodoExplorar(dados)}',
        subtitulo: '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
        colunas: const [
          'Registro ANS',
          'Operadora',
          'UF',
          'Modalidade',
          'Despesas (R\$)',
          'Receitas (R\$)',
          'Sinistralidade (%)',
          'Beneficiários',
        ],
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
    AppColors.watchDark(context);
    final vm = context.watch<ExplorarViewModel>();
    final dados = vm.dados;
    if (dados == null) {
      if (vm.error != null) return ErrorBox(vm.error!, onRetry: vm.carregar);
      return const LoadingBlock(label: 'Carregando exploração...');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BarraControlesExplorar(
          vm: vm,
          dados: dados,
          onAbrirFiltros: () => abrirFiltrosExplorar(context, vm, dados),
          onAbrirConstrutor: () => abrirConstrutorGrafico(context, vm),
        ),
        const SizedBox(height: 12),
        FiltrosAtivosExplorar(vm: vm),
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
              KpisExplorar(dados: dados, comparar: vm.filtros.comparar),
              const SizedBox(height: AppLayout.gutter),
              GradeGraficosExplorar(
                vm: vm,
                dados: dados,
                onPersonalizar: () => abrirConstrutorGrafico(context, vm),
                onEditarGrafico: (i) => abrirConstrutorGrafico(context, vm, editar: i),
              ),
              const SizedBox(height: AppLayout.gutter),
              ListagemExplorar(dados: dados),
            ],
          ),
        ),
      ],
    );
  }
}
