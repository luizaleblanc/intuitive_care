import 'package:flutter/material.dart';

import '../../app/theme.dart';

class ToggleRow extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  final String label;
  final String desc;

  const ToggleRow({super.key, required this.on, required this.onChanged, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      toggled: on,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.sans(14, weight: FontWeight.w600)),
                    Text(desc, style: AppText.sans(12, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  color: on ? AppColors.primaryBg : AppColors.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Controle segmentado (Tema: Claro / Escuro ou modos de período).
class SegmentedPill<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool expand;
  const SegmentedPill({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    Widget item((T, String) o) {
      final child = Semantics(
        selected: o.$1 == value,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(o.$1),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: o.$1 == value ? AppColors.primaryBg : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                o.$2,
                softWrap: false,
                style: AppText.sans(
                  12,
                  weight: FontWeight.w600,
                  color: o.$1 == value ? Colors.white : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: dark ? Border.all(color: AppColors.slate200) : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final o in options) item(o)],
      ),
    );
  }
}
