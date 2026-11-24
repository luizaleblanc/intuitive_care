import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/operadora_model.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/operadoras_viewmodel.dart';
import 'app_shell.dart';
import 'operadoras/operadora_drawer.dart';
import 'operadoras/operadoras_tabela.dart';

class OperadorasView extends StatefulWidget {
  final String? buscaInicial;
  const OperadorasView({super.key, this.buscaInicial});

  @override
  State<OperadorasView> createState() => _OperadorasViewState();
}

class _OperadorasViewState extends State<OperadorasView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperadorasViewModel>().carregar(search: widget.buscaInicial ?? '', resumo: true);
      context.read<ShellActions>().registrarExportacao(() => _exportar());
    });
  }

  @override
  void didUpdateWidget(covariant OperadorasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buscaInicial != oldWidget.buscaInicial) {
      context.read<OperadorasViewModel>().carregar(search: widget.buscaInicial ?? '');
    }
  }

  @override
  void deactivate() {
    context.read<ShellActions>().registrarExportacao(null);
    super.deactivate();
  }

  /// Sem [formato], usa a preferência "Exportar como" do perfil; o botão "Exportar CSV" força CSV.
  Future<void> _exportar({String? formato}) async {
    final vm = context.read<OperadorasViewModel>();
    formato ??= context.read<AuthViewModel>().currentUser?.preferencias.formatoExportacao ?? 'CSV';
    try {
      final linhas = await vm.exportar();
      if (linhas.isEmpty) return;
      final nome = await Exporter.exportar(
        ExportTable(
          titulo: 'Operadoras ANS',
          subtitulo: [
            if (vm.search.isNotEmpty) 'Busca: ${vm.search}',
            if (vm.modalidade.isNotEmpty) 'Modalidade: ${vm.modalidade}',
            '${linhas.length - 1} operadora(s)',
          ].join(' · '),
          colunas: linhas.first,
          linhas: linhas.skip(1).toList(),
        ),
        nomeBase: 'operadoras_ans',
        formato: formato,
      );
      if (mounted) context.read<ToastController>().show('Exportação concluída ($nome)');
    } catch (e) {
      if (mounted) context.read<ToastController>().show('Falha ao exportar: $e', error: true);
    }
  }

  void _abrir(OperadoraModel? op) {
    showSideDrawer(context, builder: (_) => OperadoraDrawer(operadora: op));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final vm = context.watch<OperadorasViewModel>();
    final isAdmin = context.watch<AuthViewModel>().currentUser?.isAdmin ?? false;
    final r = vm.resumo;
    final cards = [
      ('Ativas', fmtInt(r.ativas), LucideIcons.circleCheck),
      ('Em análise', fmtInt(r.emAnalise), LucideIcons.clock),
      ('Inativadas (12m)', fmtInt(r.inativadas12m), LucideIcons.circleOff),
      ('Beneficiários', fmtMi(r.beneficiarios), LucideIcons.users),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: AppLayout.gutter),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(16)),
                        child: Icon(cards[i].$3, size: 19, color: AppColors.sageText),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cards[i].$1, style: AppText.sans(14, color: AppColors.muted)),
                          Text(cards[i].$2, style: AppText.display(20, weight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppLayout.gutter),
        AppCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SearchInput(
                      value: vm.search,
                      width: 420,
                      placeholder: 'Buscar por Registro ANS, Razão Social ou CNPJ',
                      onChanged: (v) => vm.carregar(search: v),
                      onSubmitted: (v) => vm.carregar(search: v),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: AppMultiSelect<String>(
                        semanticLabel: 'Modalidades',
                        icon: LucideIcons.layers,
                        selected: vm.modalidades,
                        emptyLabel: 'Todas modalidades',
                        options: [for (final m in r.modalidades) (m, m)],
                        formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} modalidades',
                        onChanged: (v) => vm.carregar(modalidades: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${fmtInt(vm.total)} resultado(s)', style: AppText.sans(14, color: AppColors.muted)),
                    const Spacer(),
                    if (isAdmin) ...[
                      AppButton('Exportar CSV',
                          variant: ButtonVariant.secondary,
                          icon: LucideIcons.download,
                          onPressed: () => _exportar(formato: 'CSV')),
                      const SizedBox(width: 8),
                      AppButton('Nova operadora', icon: LucideIcons.plus, onPressed: () => _abrir(null)),
                    ],
                  ],
                ),
              ),
              if (vm.error != null)
                Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: ErrorBox(vm.error!)),
              OperadorasTabela(itens: vm.items, isAdmin: isAdmin, loading: vm.isLoading, busca: vm.search, onTap: _abrir),
              if (vm.totalPages > 1)
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text('Página ${vm.page} de ${vm.totalPages}', style: AppText.sans(14, color: AppColors.muted)),
                      const Spacer(),
                      AppButton('Anterior',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          icon: LucideIcons.chevronLeft,
                          onPressed: vm.page > 1 && !vm.isLoading ? () => vm.carregar(page: vm.page - 1) : null),
                      const SizedBox(width: 8),
                      AppButton('Próxima',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          iconRight: LucideIcons.chevronRight,
                          onPressed: vm.page < vm.totalPages && !vm.isLoading
                              ? () => vm.carregar(page: vm.page + 1)
                              : null),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
