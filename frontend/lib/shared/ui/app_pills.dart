import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../utils/formatters.dart';

enum PillTone { neutral, forest, mint, lime, ok, danger, warn, sage }

class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool dot;
  final Color? background;
  final Color? foreground;

  const Pill(this.label,
      {super.key, this.tone = PillTone.neutral, this.icon, this.dot = false, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.slate100, AppColors.slate700),
      PillTone.forest => (AppColors.primaryBg, Colors.white),
      PillTone.mint => (AppColors.mint.withValues(alpha: dark ? 0.18 : 0.2), AppColors.brandText),
      PillTone.lime => (AppColors.lime, AppColors.forest),
      PillTone.ok => (AppColors.emerald50, AppColors.emerald700),
      PillTone.danger => (AppColors.red50, AppColors.red600),
      PillTone.warn => (AppColors.amber50, AppColors.amber700),
      PillTone.sage => (AppColors.sage, AppColors.sageText),
    };
    final color = foreground ?? fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background ?? bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(12, weight: FontWeight.w600, color: color, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class DeltaBadge extends StatelessWidget {
  final double value;
  final bool dark;
  const DeltaBadge({super.key, required this.value, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    if (dark) {
      return Pill(fmtDelta(value), tone: PillTone.lime, icon: up ? LucideIcons.trendingUp : LucideIcons.trendingDown);
    }
    return Pill(fmtDelta(value),
        tone: up ? PillTone.ok : PillTone.danger, icon: up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight);
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) => Pill(
        status,
        dot: true,
        tone: status == 'Ativa' ? PillTone.ok : (status == 'Inativa' ? PillTone.danger : PillTone.warn),
      );
}

class ModalidadePill extends StatelessWidget {
  final String? modalidade;
  const ModalidadePill(this.modalidade, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = modalidade ?? 'Não informada';
    final tone = m == 'Medicina de Grupo'
        ? PillTone.sage
        : m == 'Cooperativa Médica'
            ? PillTone.mint
            : m == 'Autogestão'
                ? PillTone.warn
                : PillTone.neutral;
    return Pill(m, tone: tone);
  }
}
