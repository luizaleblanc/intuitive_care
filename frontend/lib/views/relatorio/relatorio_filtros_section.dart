import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/explorar_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/explorar_viewmodel.dart';
import 'relatorio_secoes_section.dart';

class RelatorioFormatoPeriodoSection extends StatelessWidget {
  final String formato;
  final String resumoFormato;
  final List<int> anosDisponiveis;
  final Set<int> anos;
  final Set<int> trimestres;
  final String granularidade;
  final ValueChanged<String> onFormatoChanged;
  final ValueChanged<Set<int>> onAnosChanged;
  final ValueChanged<Set<int>> onTrimestresChanged;
  final ValueChanged<String> onGranularidadeChanged;

  const RelatorioFormatoPeriodoSection({
    super.key,
    required this.formato,
    required this.resumoFormato,
    required this.anosDisponiveis,
    required this.anos,
    required this.trimestres,
    required this.granularidade,
    required this.onFormatoChanged,
    required this.onAnosChanged,
    required this.onTrimestresChanged,
    required this.onGranularidadeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RelatorioSecaoContainer(
          titulo: 'Formato do arquivo',
          ajuda: resumoFormato,
          child: SegmentedPill<String>(
            value: formato,
            options: const [
              ('XLSX', 'XLSX'),
              ('CSV', 'CSV'),
              ('PDF', 'PDF'),
            ],
            onChanged: onFormatoChanged,
          ),
        ),
        RelatorioSecaoContainer(
          titulo: 'Período (anos e trimestres)',
          ajuda: 'Selecione um ou mais anos carregados no ETL e, se quiser, restrinja os trimestres.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                AppMultiSelect<int>(
                  semanticLabel: 'Anos do relatório',
                  icon: LucideIcons.calendarDays,
                  selected: anos,
                  minSelected: 1,
                  options: [for (final a in anosDisponiveis.reversed) (a, '$a')],
                  formatSelected: (l) => fmtAnos(l.map((e) => e.$1)),
                  onChanged: onAnosChanged,
                ),
                AppMultiSelect<int>(
                  semanticLabel: 'Trimestres do relatório',
                  icon: LucideIcons.calendar,
                  selected: trimestres,
                  emptyLabel: 'Todos os trimestres',
                  options: [for (var t = 1; t <= 4; t++) (t, fmtTrimestre(t))],
                  formatSelected: (l) => fmtTrimestres(l.map((e) => e.$1)),
                  onChanged: onTrimestresChanged,
                ),
              ]),
              const SizedBox(height: 10),
              SegmentedPill<String>(
                value: granularidade,
                expand: false,
                options: const [('ano', 'Por ano'), ('trimestre', 'Por trimestre')],
                onChanged: onGranularidadeChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RelatorioFiltrosAvancadosSection extends StatelessWidget {
  final Facetas facetas;
  final Set<String> ufs;
  final Set<String> modalidades;
  final Set<String> portes;
  final Set<String> statuses;
  final Set<String> consolidacoes;
  final ValueChanged<Set<String>> onUfsChanged;
  final ValueChanged<Set<String>> onModalidadesChanged;
  final ValueChanged<Set<String>> onPortesChanged;
  final ValueChanged<Set<String>> onStatusesChanged;
  final ValueChanged<Set<String>> onConsolidacoesChanged;

  const RelatorioFiltrosAvancadosSection({
    super.key,
    required this.facetas,
    required this.ufs,
    required this.modalidades,
    required this.portes,
    required this.statuses,
    required this.consolidacoes,
    required this.onUfsChanged,
    required this.onModalidadesChanged,
    required this.onPortesChanged,
    required this.onStatusesChanged,
    required this.onConsolidacoesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RelatorioSecaoContainer(
      titulo: 'Filtros avançados',
      ajuda: 'Deixe em branco para exportar toda a base extraída do período selecionado.',
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        AppMultiSelect<String>(
          semanticLabel: 'UFs do relatório',
          icon: LucideIcons.mapPin,
          selected: ufs,
          emptyLabel: 'Todas UFs',
          options: [for (final u in facetas.ufs) (u, u)],
          formatSelected: (l) => l.length <= 2 ? l.map((e) => e.$1).join(', ') : '${l.length} UFs',
          onChanged: onUfsChanged,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: AppMultiSelect<String>(
            semanticLabel: 'Modalidades do relatório',
            icon: LucideIcons.layers,
            selected: modalidades,
            emptyLabel: 'Todas modalidades',
            options: [for (final m in facetas.modalidades) (m, m)],
            formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} modalidades',
            onChanged: onModalidadesChanged,
          ),
        ),
        AppMultiSelect<String>(
          semanticLabel: 'Porte ANS das operadoras',
          icon: LucideIcons.building2,
          selected: portes,
          emptyLabel: 'Todos os portes',
          options: [for (final e in rotulosPorte.entries) (e.key, e.value)],
          formatSelected: (l) => l.length == 1 ? l.first.$2 : '${l.length} portes',
          onChanged: onPortesChanged,
        ),
        if (facetas.status.length > 1)
          AppMultiSelect<String>(
            semanticLabel: 'Status das operadoras',
            icon: LucideIcons.circleCheck,
            selected: statuses,
            emptyLabel: 'Todos os status',
            options: [for (final s in facetas.status) (s, s)],
            formatSelected: (l) => l.map((e) => e.$2).join(', '),
            onChanged: onStatusesChanged,
          ),
        AppMultiSelect<String>(
          semanticLabel: 'Consolidação dos lotes ETL',
          icon: LucideIcons.shieldCheck,
          selected: consolidacoes,
          emptyLabel: 'Todos os lotes',
          options: [for (final e in rotulosConsolidacao.entries) (e.key, e.value)],
          formatSelected: (l) => l.length == 1 ? l.first.$2 : 'Todos os lotes',
          onChanged: onConsolidacoesChanged,
        ),
      ]),
    );
  }
}
