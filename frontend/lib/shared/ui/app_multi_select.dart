import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import 'app_buttons.dart';

/// Select com múltipla escolha em pílula: abre menu ancorado com caixas de seleção
/// e mantém o menu aberto enquanto o usuário marca ou desmarca várias opções.
class AppMultiSelect<T> extends StatelessWidget {
  final Set<T> selected;
  final List<(T, String)> options;
  final ValueChanged<Set<T>> onChanged;
  final IconData icon;
  final String semanticLabel;
  final String emptyLabel;
  final String Function(List<(T, String)>)? formatSelected;
  final int minSelected;
  final double? width;

  const AppMultiSelect({
    super.key,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.icon = LucideIcons.filter,
    required this.semanticLabel,
    this.emptyLabel = 'Todos',
    this.formatSelected,
    this.minSelected = 0,
    this.width,
  });

  String get _rotulo {
    final ativos = [for (final o in options) if (selected.contains(o.$1)) o];
    if (ativos.isEmpty) return emptyLabel;
    if (formatSelected != null) return formatSelected!(ativos);
    if (ativos.length == 1) return ativos.first.$2;
    return '${ativos.length} selecionados';
  }

  bool _igual(Set<T> a, Set<T> b) => a.length == b.length && a.every(b.contains);

  Future<void> _abrir(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final origem = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tamanho = renderBox.size;
    final tela = overlay.size;

    final menuWidth = (width ?? tamanho.width).clamp(240.0, 340.0);
    final left = origem.dx.clamp(12.0, (tela.width - menuWidth - 12.0).clamp(12.0, double.infinity));
    final espacoAbaixo = tela.height - (origem.dy + tamanho.height) - 16.0;
    final maxH = espacoAbaixo >= 220 ? espacoAbaixo.clamp(220.0, 440.0) : 380.0;
    final top = espacoAbaixo >= 220
        ? origem.dy + tamanho.height + 6.0
        : (origem.dy - maxH - 6.0).clamp(12.0, tela.height - 120.0);

    final rascunho = Set<T>.from(selected);
    final scrollCtrl = ScrollController();
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            AppColors.watchDark(ctx);
            void alternar(T valor) {
              setModalState(() {
                if (rascunho.contains(valor)) {
                  if (rascunho.length > minSelected) rascunho.remove(valor);
                } else {
                  rascunho.add(valor);
                }
              });
            }

            final todosMarcados = options.isNotEmpty && options.every((o) => rascunho.contains(o.$1));
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: menuWidth,
                  child: Material(
                    color: AppColors.card,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: AppColors.isDark ? 0.45 : 0.16),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.slate200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: Scrollbar(
                              controller: scrollCtrl,
                              thumbVisibility: options.length > 8,
                              child: ListView(
                                controller: scrollCtrl,
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                children: [
                                  for (final o in options)
                                    InkWell(
                                      onTap: () => alternar(o.$1),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 120),
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: rascunho.contains(o.$1) ? AppColors.primaryBg : AppColors.inputFill,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: rascunho.contains(o.$1) ? AppColors.primaryBg : AppColors.slate300,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: rascunho.contains(o.$1)
                                                  ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                o.$2,
                                                style: AppText.sans(
                                                  14,
                                                  weight: rascunho.contains(o.$1) ? FontWeight.w600 : FontWeight.w400,
                                                  color: rascunho.contains(o.$1) ? AppColors.brandText : AppColors.ink,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                if (minSelected == 0)
                                  TextButton(
                                    onPressed: rascunho.isEmpty ? null : () => setModalState(rascunho.clear),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Limpar',
                                        style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.muted)),
                                  )
                                else
                                  TextButton(
                                    onPressed: todosMarcados
                                        ? null
                                        : () => setModalState(() {
                                              for (final o in options) {
                                                rascunho.add(o.$1);
                                              }
                                            }),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Todos',
                                        style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.muted)),
                                  ),
                                const Spacer(),
                                AppButton(
                                  'Aplicar',
                                  size: ButtonSize.sm,
                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      scrollCtrl.dispose();
    }
    if (!_igual(rascunho, selected)) {
      onChanged(Set<T>.unmodifiable(rascunho));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    final rotulo = _rotulo;
    final filtrado = minSelected == 0 && selected.isNotEmpty;
    return Semantics(
      label: semanticLabel,
      value: rotulo,
      button: true,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox(
          width: width,
          height: 40,
          child: Material(
            color: filtrado ? (dark ? AppColors.sage : AppColors.sage.withValues(alpha: 0.45)) : AppColors.inputFill,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => _abrir(context),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: filtrado ? AppColors.brandText.withValues(alpha: 0.5) : AppColors.slate200),
                ),
                child: Row(
                  mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Icon(icon, size: 14, color: filtrado ? AppColors.brandText : AppColors.muted),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: width == null ? FlexFit.loose : FlexFit.tight,
                      child: Text(
                        rotulo,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          14,
                          weight: filtrado ? FontWeight.w600 : FontWeight.w500,
                          color: filtrado ? AppColors.brandText : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(LucideIcons.chevronDown, size: 14, color: filtrado ? AppColors.brandText : AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
