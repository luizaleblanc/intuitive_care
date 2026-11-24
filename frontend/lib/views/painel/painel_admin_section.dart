import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/analitico_model.dart';
import '../../shared/charts/charts.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/painel_viewmodel.dart';

// ---------------------------------------------------------------------------
// Painel do Administrador
// ---------------------------------------------------------------------------
class PainelAdminSection extends StatelessWidget {
  final PainelModel p;
  final PainelViewModel vm;
  const PainelAdminSection(this.p, this.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final periodo = fmtPeriodosSelecionados([for (final x in p.periodosSelecionados) (x.ano, x.trimestre)]);
    final multi = p.periodosSelecionados.length > 1;
    final serie = !multi && p.serieAdmin.length > 8
        ? p.serieAdmin.sublist(p.serieAdmin.length - 8)
        : p.serieAdmin;
    final crescimento = serie.length >= 2 ? variation(serie.last.valor, serie.first.valor) : null;
    final trisDisp = vm.trimestresDosAnos(vm.anos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Período',
                  style: AppText.sans(14, weight: FontWeight.w600),
                ),
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
                options: [for (final t in trisDisp) (t, fmtTrimestre(t))],
                formatSelected: (l) => fmtTrimestres(l.map((e) => e.$1)),
                onChanged: (v) => vm.carregar(trimestres: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (
            4,
            KpiCard(
              dark: true,
              label: 'Total de despesas processadas · $periodo',
              value: fmtBi(p.totalDespesas),
              delta: variation(p.totalDespesas, p.totalDespesasAnterior),
              foot: multi ? 'vs período equivalente anterior' : 'vs último trimestre',
              icon: LucideIcons.wallet,
            ),
          ),
          (
            4,
            KpiCard(
              label: 'Registros extraídos da ANS',
              value: fmtInt(p.registrosExtraidos),
              delta: variation(
                p.registrosExtraidos,
                p.registrosExtraidosAnterior,
              ),
              foot: multi ? 'linhas nos ${p.periodosSelecionados.length} lotes' : 'linhas no último lote',
              icon: LucideIcons.database,
            ),
          ),
          (
            4,
            KpiCard(
              label: 'Operadoras ativas',
              value: fmtInt(p.operadorasAtivas),
              foot: 'cadastro CADOP · ${fmtInt(p.operadorasComDemonstracao)} com demonstração',
              icon: LucideIcons.building2,
            ),
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
                        : Pill(
                            '${fmtDelta(crescimento)} em ${serie.length} trimestres',
                            tone: crescimento >= 0 ? PillTone.ok : PillTone.danger,
                            icon: crescimento >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                          ),
                  ),
                  const SizedBox(height: 24),
                  PillBarChart(
                    height: 260,
                    data: [
                      for (final s in serie)
                        BarDatum(
                          fmtPeriodoCurto(s.ano, s.trimestre),
                          s.valor / 1e9,
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
    final dark = AppColors.watchDark(context);
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
            color: AppColors.sageText,
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.chartPie,
                size: 15,
                color: AppColors.sageText,
              ),
            ),
          ),
          Text(
            'Participação nas despesas do trimestre',
            style: AppText.sans(
              12,
              color: AppColors.sageMuted,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Donut(
              data: fatias,
              center: fmtInt(p.operadorasComDemonstracao),
              sub: 'operadoras',
            ),
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
                      border: Border.all(
                        color: AppColors.sageText.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.label,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(14, color: AppColors.sageText),
                    ),
                  ),
                  Text(
                    fmtPct(f.pct),
                    style: AppText.sans(
                      14,
                      weight: FontWeight.w600,
                      color: AppColors.sageText,
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
