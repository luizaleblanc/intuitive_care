import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/app_error_banner.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/kpi_card.dart';
import '../widgets/uf_bar_chart.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final dashVm = context.watch<DashboardViewModel>();
    final stats = dashVm.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intuitive Care • Painel Geral'),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: dashVm.isLoading ? null : dashVm.loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: dashVm.loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (authVm.currentUser != null)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          authVm.currentUser!.nome.isNotEmpty
                              ? authVm.currentUser!.nome[0].toUpperCase()
                              : 'U',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, ${authVm.currentUser!.nome}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${authVm.currentUser!.email} • Perfil ${authVm.currentUser!.perfil}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            if (dashVm.errorMessage != null)
              AppErrorBanner(
                message: dashVm.errorMessage!,
                onRetry: dashVm.loadDashboard,
              ),
            if (dashVm.isLoading && stats == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (stats != null) ...[
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 640 ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.25,
                children: [
                  KpiCard(
                    title: 'Total de Despesas',
                    value: CurrencyFormatter.formatCompactBrl(stats.totalGeral),
                    subtitle: '${stats.totalLancamentos} lançamentos',
                    icon: Icons.payments_outlined,
                  ),
                  KpiCard(
                    title: 'Operadoras Ativas',
                    value: '${stats.totalOperadoras}',
                    subtitle: 'Base ANS cadastrada',
                    icon: Icons.business_outlined,
                    accentColor: Colors.teal,
                  ),
                  KpiCard(
                    title: 'Média por Lançamento',
                    value: CurrencyFormatter.formatCompactBrl(stats.mediaDespesa),
                    icon: Icons.show_chart,
                    accentColor: Colors.indigo,
                  ),
                  KpiCard(
                    title: 'Crescimento no Período',
                    value: '${stats.crescimentoPeriodoPct >= 0 ? '+' : ''}${stats.crescimentoPeriodoPct}%',
                    subtitle: 'Evolução trimestral',
                    icon: Icons.trending_up,
                    accentColor: Colors.deepOrange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top 5 Estados por Volume de Despesas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      UfBarChart(items: stats.topUfs),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução Trimestral Consolidada',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...stats.serieTrimestral.map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today, size: 18),
                          title: Text('${item.ano} - ${item.trimestre}º Trimestre'),
                          trailing: Text(
                            CurrencyFormatter.formatBrl(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
