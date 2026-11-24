import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/explorar_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/explorar_viewmodel.dart';

// ---------------------------------------------------------------------------
// Barra de controles: período, granularidade, comparação e atalhos
// ---------------------------------------------------------------------------
class BarraControlesExplorar extends StatelessWidget {
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  final VoidCallback onAbrirFiltros;
  final VoidCallback onAbrirConstrutor;

  const BarraControlesExplorar({
    super.key,
    required this.vm,
    required this.dados,
    required this.onAbrirFiltros,
    required this.onAbrirConstrutor,
  });

  @override
  Widget build(BuildContext context) {
    final f = vm.filtros;
    final anos = [for (final a in dados.anosDisponiveis.reversed) (a, '$a')];
    final (ini, fim) = vm.intervalo;
    final podeExportar = context.watch<AuthViewModel>().currentUser?.pode('dados.exportar') ?? false;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Linha 1: período
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.calendarRange, size: 16, color: AppColors.brandText),
              const SizedBox(width: 8),
              Text('PERÍODO', style: AppText.eyebrow()),
            ]),
            SegmentedPill<ModoPeriodo>(
              value: f.modo,
              expand: false,
              options: const [
                (ModoPeriodo.ano, 'Ano'),
                (ModoPeriodo.intervalo, 'Intervalo'),
                (ModoPeriodo.ultimos, 'Últimos anos'),
                (ModoPeriodo.especificos, 'Anos específicos'),
              ],
              onChanged: (m) => vm.aplicar(f.copyWith(modo: m)),
            ),
            if (f.modo == ModoPeriodo.ano)
              AppSelect<int>(
                value: fim ?? anos.first.$1,
                options: anos,
                icon: LucideIcons.calendar,
                width: 130,
                semanticLabel: 'Ano',
                onChanged: (a) => vm.aplicar(f.copyWith(anoFim: () => a)),
              ),
            if (f.modo == ModoPeriodo.intervalo) ...[
              AppSelect<int>(
                value: ini ?? anos.last.$1,
                options: anos,
                icon: LucideIcons.calendar,
                width: 130,
                semanticLabel: 'Ano inicial',
                onChanged: (a) => vm.aplicar(f.copyWith(anoInicio: () => a, anoFim: () => fim)),
              ),
              Text('até', style: AppText.sans(13, color: AppColors.muted)),
              AppSelect<int>(
                value: fim ?? anos.first.$1,
                options: anos,
                icon: LucideIcons.calendar,
                width: 130,
                semanticLabel: 'Ano final',
                onChanged: (a) => vm.aplicar(f.copyWith(anoInicio: () => ini, anoFim: () => a)),
              ),
            ],
            if (f.modo == ModoPeriodo.especificos)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in dados.anosDisponiveis)
                  ExplorarChip(
                    rotulo: '$a',
                    ativo: vm.anosSelecionados.contains(a),
                    onTap: () {
                      final atual = {...vm.anosSelecionados};
                      // Sempre fica ao menos um ano marcado.
                      if (atual.contains(a) && atual.length == 1) return;
                      atual.contains(a) ? atual.remove(a) : atual.add(a);
                      vm.aplicar(f.copyWith(anos: atual));
                    },
                  ),
              ]),
            if (f.modo == ModoPeriodo.ultimos)
              AppSelect<int>(
                value: f.ultimos.clamp(2, dados.anosDisponiveis.length < 2 ? 2 : dados.anosDisponiveis.length),
                options: [
                  for (var n = 2; n <= (dados.anosDisponiveis.length < 2 ? 2 : dados.anosDisponiveis.length); n++)
                    (n, 'Últimos $n anos'),
                ],
                icon: LucideIcons.calendar,
                width: 200,
                semanticLabel: 'Quantidade de anos',
                onChanged: (n) => vm.aplicar(f.copyWith(ultimos: n)),
              ),
            AppMultiSelect<int>(
              semanticLabel: 'Trimestres',
              icon: LucideIcons.calendarDays,
              selected: f.trimestres,
              emptyLabel: 'Todos os trimestres',
              options: [for (var t = 1; t <= 4; t++) (t, fmtTrimestre(t))],
              formatSelected: (l) => fmtTrimestres(l.map((e) => e.$1)),
              onChanged: (tris) => vm.aplicar(f.copyWith(trimestres: tris)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: AppColors.slate100),
        ),
        // Linha 2: visualização, comparação e ferramentas
        Row(children: [
          SegmentedPill<String>(
            value: f.granularidade,
            expand: false,
            options: const [('ano', 'Por ano'), ('trimestre', 'Por trimestre')],
            onChanged: (g) => vm.aplicar(f.copyWith(granularidade: g)),
          ),
          const SizedBox(width: 16),
          _Interruptor(
            ligado: f.comparar,
            rotulo: 'Comparar com período anterior',
            onChanged: (v) => vm.aplicar(f.copyWith(comparar: v)),
          ),
          const SizedBox(width: 12),
          if (vm.isLoading) const Spinner(),
          const Spacer(),
          AppButton(
            f.avancadosAtivos == 0 ? 'Filtros avançados' : 'Filtros avançados (${f.avancadosAtivos})',
            icon: LucideIcons.slidersHorizontal,
            variant: f.avancadosAtivos == 0 ? ButtonVariant.secondary : ButtonVariant.primary,
            size: ButtonSize.sm,
            onPressed: onAbrirFiltros,
          ),
          const SizedBox(width: 8),
          AppButton(
            'Personalizar gráficos',
            icon: LucideIcons.chartNoAxesCombined,
            variant: ButtonVariant.secondary,
            size: ButtonSize.sm,
            onPressed: onAbrirConstrutor,
          ),
          if (!podeExportar) ...[
            const SizedBox(width: 8),
            const Tooltip(
              message: 'Exportação disponível apenas para o perfil Administrador.',
              child: Pill('Somente consulta', tone: PillTone.sage, icon: LucideIcons.eye),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Interruptor extends StatelessWidget {
  final bool ligado;
  final String rotulo;
  final ValueChanged<bool> onChanged;
  const _Interruptor({required this.ligado, required this.rotulo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      toggled: ligado,
      label: rotulo,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!ligado),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: ligado ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: ligado ? AppColors.primaryBg : AppColors.slate300,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: ligado ? AppColors.mint : Colors.white, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            Text(rotulo, style: AppText.sans(13, weight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pílulas dos filtros avançados ativos (removíveis) e chip reutilizável
// ---------------------------------------------------------------------------
class FiltrosAtivosExplorar extends StatelessWidget {
  final ExplorarViewModel vm;
  const FiltrosAtivosExplorar({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final f = vm.filtros;
    final pilulas = <(String, FiltrosExplorar)>[
      for (final m in f.modalidades) (m, f.copyWith(modalidades: {...f.modalidades}..remove(m))),
      for (final u in f.ufs) ('UF $u', f.copyWith(ufs: {...f.ufs}..remove(u))),
      for (final p in f.portes) (rotulosPorte[p]!, f.copyWith(portes: {...f.portes}..remove(p))),
      for (final x in f.faixas) ('Despesa: ${rotulosFaixa[x]!}', f.copyWith(faixas: {...f.faixas}..remove(x))),
      for (final c in f.consolidacoes)
        (rotulosConsolidacao[c]!, f.copyWith(consolidacoes: {...f.consolidacoes}..remove(c))),
      for (final s in f.statuses) ('Status: $s', f.copyWith(statuses: {...f.statuses}..remove(s))),
    ];
    if (pilulas.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (rotulo, sem) in pilulas)
          InputChip(
            label: Text(rotulo, style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.sageText)),
            backgroundColor: AppColors.sage,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            deleteIcon: Icon(LucideIcons.x, size: 14, color: AppColors.sageText),
            deleteButtonTooltipMessage: 'Remover filtro',
            onDeleted: () => vm.aplicar(sem),
          ),
        TextButton(
          onPressed: () => vm.aplicar(f.semAvancados()),
          child: Text('Limpar filtros', style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.brandText)),
        ),
      ],
    );
  }
}

class ExplorarChip extends StatelessWidget {
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;
  const ExplorarChip({super.key, required this.rotulo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      selected: ativo,
      button: true,
      child: Material(
        color: ativo ? AppColors.primaryBg : AppColors.card,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (ativo) ...[
                const Icon(LucideIcons.check, size: 13, color: AppColors.mint),
                const SizedBox(width: 6),
              ],
              Text(rotulo,
                  style: AppText.sans(12, weight: FontWeight.w600, color: ativo ? Colors.white : AppColors.sageText)),
            ]),
          ),
        ),
      ),
    );
  }
}
