import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/despesa_viewmodel.dart';
import '../viewmodels/operadora_viewmodel.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/despesa_tile.dart';
import 'despesa_form_view.dart';

class DespesasListView extends StatelessWidget {
  const DespesasListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DespesaViewModel>();
    final dashVm = context.read<DashboardViewModel>();
    final opVm = context.read<OperadoraViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Despesas (${vm.totalRecords})'),
        actions: [
          if (vm.anoFilter != null || vm.trimestreFilter != null || vm.regAnsFilter.isNotEmpty)
            IconButton(
              tooltip: 'Limpar filtros',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () => vm.loadDespesas(clearFilters: true),
            ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: vm.isLoading ? null : () => vm.loadDespesas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const DespesaFormView()),
          );
          if (saved == true) {
            dashVm.loadDashboard();
            opVm.loadOperadoras();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Despesa'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos os anos'),
                  selected: vm.anoFilter == null,
                  onSelected: (_) => vm.loadDespesas(ano: 0),
                ),
                const SizedBox(width: 8),
                for (final year in [2025, 2024]) ...[
                  FilterChip(
                    label: Text('$year'),
                    selected: vm.anoFilter == year,
                    onSelected: (_) => vm.loadDespesas(ano: vm.anoFilter == year ? 0 : year),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final q in [1, 2, 3, 4]) ...[
                  FilterChip(
                    label: Text('$qºT'),
                    selected: vm.trimestreFilter == q,
                    onSelected: (_) => vm.loadDespesas(trimestre: vm.trimestreFilter == q ? 0 : q),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (vm.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppErrorBanner(
                message: vm.errorMessage!,
                onDismiss: vm.clearError,
              ),
            ),
          Expanded(
            child: vm.isLoading && vm.despesas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : vm.despesas.isEmpty
                    ? const Center(child: Text('Nenhum lançamento encontrado para os filtros atuais.'))
                    : RefreshIndicator(
                        onRefresh: () => vm.loadDespesas(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                          itemCount: vm.despesas.length,
                          itemBuilder: (context, index) {
                            final desp = vm.despesas[index];
                            return DespesaTile(
                              despesa: desp,
                              onEdit: () async {
                                final saved = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(builder: (_) => DespesaFormView(despesa: desp)),
                                );
                                if (saved == true) {
                                  dashVm.loadDashboard();
                                  opVm.loadOperadoras();
                                }
                              },
                              onDelete: desp.id == null
                                  ? null
                                  : () async {
                                      final confirmed = await showConfirmDeleteDialog(
                                        context,
                                        title: 'Excluir Lançamento',
                                        message: 'Confirmar exclusão da despesa de ${desp.ano}/${desp.trimestre}ºT?',
                                      );
                                      if (confirmed) {
                                        final ok = await vm.deleteDespesa(desp.id!);
                                        if (ok) {
                                          dashVm.loadDashboard();
                                          opVm.loadOperadoras();
                                        }
                                      }
                                    },
                            );
                          },
                        ),
                      ),
          ),
          if (vm.totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: vm.currentPage > 1 && !vm.isLoading
                        ? () => vm.loadDespesas(page: vm.currentPage - 1)
                        : null,
                    child: const Text('Anterior'),
                  ),
                  Text('Página ${vm.currentPage} de ${vm.totalPages}'),
                  OutlinedButton(
                    onPressed: vm.currentPage < vm.totalPages && !vm.isLoading
                        ? () => vm.loadDespesas(page: vm.currentPage + 1)
                        : null,
                    child: const Text('Próxima'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
