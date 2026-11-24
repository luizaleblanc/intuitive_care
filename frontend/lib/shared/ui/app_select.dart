import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';

/// Select em pílula: ícone à esquerda e chevron à direita.
class AppSelect<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final String semanticLabel;
  final double? width;

  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon = LucideIcons.filter,
    required this.semanticLabel,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final selected = options.where((o) => o.$1 == value).map((o) => o.$2).firstOrNull ?? '';
    return Semantics(
      label: semanticLabel,
      value: selected,
      button: true,
      child: SizedBox(
        width: width,
        height: 40,
        child: PopupMenuButton<T>(
          tooltip: semanticLabel,
          initialValue: value,
          onSelected: onChanged,
          position: PopupMenuPosition.under,
          constraints: BoxConstraints(minWidth: width ?? 200, maxHeight: 420),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.slate200),
          ),
          color: AppColors.card,
          elevation: 6,
          itemBuilder: (_) => [
            for (final o in options)
              PopupMenuItem<T>(
                value: o.$1,
                height: 38,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(o.$2,
                          style: AppText.sans(14,
                              weight: o.$1 == value ? FontWeight.w600 : FontWeight.w400,
                              color: o.$1 == value ? AppColors.brandText : AppColors.ink)),
                    ),
                    if (o.$1 == value) Icon(LucideIcons.check, size: 14, color: AppColors.brandText),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.only(left: 12, right: 12),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(icon, size: 14, color: AppColors.muted),
                const SizedBox(width: 8),
                Flexible(
                  fit: width == null ? FlexFit.loose : FlexFit.tight,
                  child: Text(selected,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(14, weight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronDown, size: 14, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
