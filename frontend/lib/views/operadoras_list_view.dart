import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/operadora_model.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/operadora_viewmodel.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/operadora_card.dart';
import 'operadora_detail_view.dart';
import 'operadora_form_view.dart';

class OperadorasListView extends StatefulWidget {
  const OperadorasListView({super.key});

  @override
  State<OperadorasListView> createState() => _OperadorasListViewState();
}

class _OperadorasListViewState extends State<OperadorasListView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(OperadoraModel op) async {
    final vm = context.read<OperadoraViewModel>();
    final dashVm = context.read<DashboardViewModel>();

    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Excluir Operadora',
      message: 'Deseja excluir a operadora "${op.razaoSocial}" (ANS ${op.registroAns})?',
    );
    if (!confirmed || !mounted) return;

    var result = await vm.deleteOperadora(op.registroAns);
    if (!result.success && result.requiresForce && mounted) {
      final forceConfirmed = await showConfirmDeleteDialog(
        context,
        title: 'Despesas Vinculadas',
        message:
            '${result.message}\n\nDeseja excluir a operadora e TODAS as despesas vinculadas em cascata?',
        confirmLabel: 'Excluir Tudo',
      );
      if (forceConfirmed && mounted) {
        result = await vm.deleteOperadora(op.registroAns, force: true);
      }
    }

    if (result.success && mounted) {
      dashVm.loadDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Operadora excluída.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OperadoraViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Operadoras (${vm.totalRecords})'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: vm.isLoading ? null : () => vm.loadOperadoras(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OperadoraFormView()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Operadora'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por Razão Social, CNPJ ou Registro ANS...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          vm.loadOperadoras(search: '', page: 1);
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) => vm.loadOperadoras(search: value, page: 1),
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
            child: vm.isLoading && vm.operadoras.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : vm.operadoras.isEmpty
                    ? const Center(child: Text('Nenhuma operadora encontrada.'))
                    : RefreshIndicator(
                        onRefresh: () => vm.loadOperadoras(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                          itemCount: vm.operadoras.length,
                          itemBuilder: (context, index) {
                            final op = vm.operadoras[index];
                            return OperadoraCard(
                              operadora: op,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OperadoraDetailView(registroAns: op.registroAns),
                                  ),
                                );
                              },
                              onEdit: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OperadoraFormView(operadora: op),
                                  ),
                                );
                              },
                              onDelete: () => _handleDelete(op),
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
                        ? () => vm.loadOperadoras(page: vm.currentPage - 1)
                        : null,
                    child: const Text('Anterior'),
                  ),
                  Text('Página ${vm.currentPage} de ${vm.totalPages}'),
                  OutlinedButton(
                    onPressed: vm.currentPage < vm.totalPages && !vm.isLoading
                        ? () => vm.loadOperadoras(page: vm.currentPage + 1)
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
