import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/analitico_model.dart';
import '../../shared/charts/charts.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/operadoras_viewmodel.dart';
import '../../viewmodels/painel_viewmodel.dart';

// ---------------------------------------------------------------------------
// Painel do Colaborador
// ---------------------------------------------------------------------------
class PainelColaboradorSection extends StatelessWidget {
  final PainelModel p;
  final PainelViewModel vm;
  const PainelColaboradorSection(this.p, this.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final resumo = context.watch<OperadorasViewModel>().resumo;
    final periodo = fmtPeriodosSelecionados([for (final x in p.periodosSelecionados) (x.ano, x.trimestre)]);
    final multi = p.periodosSelecionados.length > 1;
    final serie = !multi && p.serieColaborador.length > 8
        ? p.serieColaborador.sublist(p.serieColaborador.length - 8)
        : p.serieColaborador;
    final ufs = {...resumo.ufs, ...vm.ufs}.toList()..sort();
    final mods = {...resumo.modalidades, ...vm.modalidades}.toList()..sort();
    final trisDisp = vm.trimestresDosAnos(vm.anos);
    final rotuloUfs = vm.ufs.isEmpty
        ? 'Todas UFs'
        : vm.ufs.length <= 2
            ? (vm.ufs.toList()..sort()).join(', ')
            : '${vm.ufs.length} UFs';

    return Column(
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
                      child: Text(
                        'Filtros',
                        style: AppText.sans(14, weight: FontWeight.w600),
                      ),
                    ),
                    AppMultiSelect<String>(
                      semanticLabel: 'UFs',
                      icon: LucideIcons.mapPin,
                      selected: vm.ufs,
                      emptyLabel: 'Todas UFs',
                      options: [for (final u in ufs) (u, u)],
                      formatSelected: (l) => l.length <= 2 ? l.map((e) => e.$1).join(', ') : '${l.length} UFs',
                      onChanged: (v) => vm.carregar(ufs: v),
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: AppMultiSelect<String>(
                        semanticLabel: 'Modalidades',
                        icon: LucideIcons.layers,
                        selected: vm.modalidades,
                        emptyLabel: 'Todas modalidades',
                        options: [for (final m in mods) (m, m)],
                        formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} modalidades',
                        onChanged: (v) => vm.carregar(modalidades: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.lock, size: 13, color: AppColors.muted),
              const SizedBox(width: 8),
              Text(
                'Modo consulta · somente leitura',
                style: AppText.sans(12, color: AppColors.caption),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (
            3,
            KpiCard(
              dark: true,
              label: 'Despesas médico-hospitalares · $periodo',
              value: fmtBi(p.despesasMh),
              delta: variation(p.despesasMh, p.despesasMhAnterior),
              foot: multi ? 'vs período equivalente anterior' : 'vs trimestre anterior',
              icon: LucideIcons.stethoscope,
            ),
          ),
          (
            3,
            KpiCard(
              label: 'Sinistralidade média',
              value: p.sinistralidade == null ? '—' : fmtPct(p.sinistralidade! * 100),
              delta: variation(p.sinistralidade, p.sinistralidadeAnterior),
              foot: 'eventos / contraprestações',
              icon: LucideIcons.percent,
            ),
          ),
          (
            3,
            KpiCard(
              label: 'Beneficiários cobertos',
              value: fmtMi(p.beneficiarios),
              delta: variation(p.beneficiarios, p.beneficiariosAnterior),
              foot: 'planos médico-hospitalares',
              icon: LucideIcons.users,
            ),
          ),
          (
            3,
            KpiCard(
              label: 'Ticket médio por vida',
              value: p.ticketMedio == null ? '—' : fmtReais(p.ticketMedio!),
              delta: variation(p.ticketMedio, p.ticketMedioAnterior),
              foot: 'por trimestre',
              icon: LucideIcons.heartPulse,
            ),
          ),
        ]),
        const SizedBox(height: AppLayout.gutter),
        GridRow([
          (5, _RankingPainel(p.ranking, uf: rotuloUfs)),
          (
            7,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeader(
                    'Despesas por trimestre',
                    subtitle: 'Médico-hospitalar · R\$ bilhões',
                    trailing: Pill(multi ? periodo : 'Até o $periodo', tone: PillTone.sage),
                  ),
                  const SizedBox(height: 24),
                  PillBarChart(
                    height: 240,
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
        ], mesmaAltura: false),
      ],
    );
  }
}

class _RankingPainel extends StatelessWidget {
  final List<RankingItem> itens;
  final String uf;
  const _RankingPainel(this.itens, {required this.uf});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final maxV = itens.fold<double>(0, (m, i) => i.valor > m ? i.valor : m);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            'Maiores operadoras por despesa',
            trailing: Pill(uf.isEmpty ? 'Todas UFs' : uf, tone: PillTone.sage),
          ),
          const SizedBox(height: 20),
          if (itens.isEmpty)
            Text(
              'Nenhuma operadora com despesa para este recorte.',
              style: AppText.sans(14, color: AppColors.muted),
            ),
          for (var i = 0; i < itens.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: AppText.sans(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomeProprio(itens[i].nome),
                                overflow: TextOverflow.ellipsis,
                                style: AppText.sans(
                                  14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fmtBi(itens[i].valor),
                              style: AppText.sans(
                                14,
                                weight: FontWeight.w600,
                                color: AppColors.brandText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          fraction: maxV == 0 ? 0 : itens[i].valor / maxV,
                        ),
                      ],
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
