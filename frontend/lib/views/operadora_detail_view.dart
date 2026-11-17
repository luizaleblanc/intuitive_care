import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/despesa_viewmodel.dart';
import '../viewmodels/operadora_viewmodel.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/despesa_tile.dart';
import 'despesa_form_view.dart';
import 'operadora_form_view.dart';

class OperadoraDetailView extends StatefulWidget {
  final String registroAns;

  const OperadoraDetailView({super.key, required this.registroAns});

  @override
  State<OperadoraDetailView> createState() => _OperadoraDetailViewState();
}

class _OperadoraDetailViewState extends State<OperadoraDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OperadoraViewModel>().loadOperadoraDetail(widget.registroAns);
    });
  }

  @override
  Widget build(BuildContext context) {
    final opVm = context.watch<OperadoraViewModel>();
    final despVm = context.read<DespesaViewModel>();
    final dashVm = context.read<DashboardViewModel>();
    final op = opVm.selectedOperadora;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Operadora'),
        actions: [
          if (op != null)
            IconButton(
              tooltip: 'Editar operadora',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OperadoraFormView(operadora: op)),
                );
                if (mounted) {
                  opVm.loadOperadoraDetail(widget.registroAns);
                }
              },
            ),
        ],
      ),
      floatingActionButton: op == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => DespesaFormView(initialRegAns: op.registroAns),
                  ),
                );
                if (saved == true && mounted) {
                  opVm.loadOperadoraDetail(widget.registroAns);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Lançar Despesa'),
            ),
      body: opVm.isLoading && op == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (opVm.errorMessage != null) AppErrorBanner(message: opVm.errorMessage!),
                if (op != null) ...[
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.razaoSocial,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (op.nomeFantasia != null && op.nomeFantasia!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(op.nomeFantasia!, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('ANS: ${op.registroAns}')),
                              Chip(label: Text('CNPJ: ${op.cnpj}')),
                              Chip(label: Text('UF: ${op.uf}')),
                              if (op.modalidade != null) Chip(label: Text(op.modalidade!)),
                            ],
                          ),
                          const Divider(height: 24),
                          _InfoRow(label: 'Cidade/UF', value: '${op.cidade ?? '-'} / ${op.uf}'),
                          _InfoRow(label: 'E-mail', value: op.email ?? '-'),
                          _InfoRow(label: 'Telefone', value: op.telefone ?? '-'),
                          _InfoRow(
                            label: 'Representante',
                            value: op.representante != null
                                ? '${op.representante} (${op.cargoRepresentante ?? 'Gestor'})'
                                : '-',
                          ),
                          _InfoRow(
                            label: 'Total Acumulado',
                            value: CurrencyFormatter.formatBrl(op.totalDespesas),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Histórico de Despesas (${opVm.selectedDespesas.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (opVm.selectedDespesas.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Nenhum lançamento de despesa registrado para esta operadora.'),
                      ),
                    )
                  else
                    ...opVm.selectedDespesas.map(
                      (desp) => DespesaTile(
                        despesa: desp,
                        onEdit: () async {
                          final saved = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => DespesaFormView(despesa: desp)),
                          );
                          if (saved == true && mounted) {
                            opVm.loadOperadoraDetail(widget.registroAns);
                          }
                        },
                        onDelete: desp.id == null
                            ? null
                            : () async {
                                final ok = await showConfirmDeleteDialog(
                                  context,
                                  title: 'Excluir Despesa',
                                  message: 'Deseja excluir o lançamento ${desp.ano}/${desp.trimestre}ºT?',
                                );
                                if (ok && mounted) {
                                  await despVm.deleteDespesa(desp.id!);
                                  if (mounted) {
                                    dashVm.loadDashboard();
                                    opVm.loadOperadoras();
                                    opVm.loadOperadoraDetail(widget.registroAns);
                                  }
                                }
                              },
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
