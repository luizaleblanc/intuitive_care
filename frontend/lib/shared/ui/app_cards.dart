import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_pills.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool clip;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.onTap,
    this.clip = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    final bg = widget.color ?? AppColors.card;
    final clickable = widget.onTap != null;
    final lifted = clickable && _hover;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        border: dark && bg == AppColors.card ? Border.all(color: AppColors.cardBorder) : null,
        boxShadow: bg == AppColors.sage ? null : (lifted ? AppShadows.lift : AppShadows.card),
      ),
      padding: widget.padding,
      child: widget.child,
    );
    if (!clickable) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}

class CardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final double size;

  const CardHeader(this.title, {super.key, this.subtitle, this.trailing, this.color, this.size = 17});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final c = color ?? AppColors.ink;
    final onSage = c == AppColors.forest || c == AppColors.sageText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.display(size, weight: FontWeight.w700, color: c)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: AppText.sans(size >= 17 ? 14 : 12,
                        color: onSage ? AppColors.sageMuted : AppColors.muted)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  final bool dark;
  final String label;
  final String value;
  final double? delta;
  final String foot;
  final IconData icon;

  const KpiCard({
    super.key,
    this.dark = false,
    required this.label,
    required this.value,
    this.delta,
    required this.foot,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = AppColors.watchDark(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? AppColors.heroBg : AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        border: !dark && isDarkTheme
            ? Border.all(color: AppColors.cardBorder)
            : (dark && isDarkTheme ? Border.all(color: AppColors.mint.withValues(alpha: 0.18)) : null),
        boxShadow: dark ? AppShadows.lift : AppShadows.card,
      ),
      child: Stack(
        children: [
          if (dark)
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.1), shape: BoxShape.circle),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(label,
                          style: AppText.sans(14,
                              weight: FontWeight.w500,
                              color: dark ? Colors.white.withValues(alpha: 0.72) : AppColors.muted)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withValues(alpha: 0.1) : AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 17, color: dark ? AppColors.mint : AppColors.sageText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: dark ? AppText.heroValue() : AppText.display(28, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (delta != null) ...[DeltaBadge(value: delta!, dark: dark), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(foot,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(12,
                              color: dark ? Colors.white.withValues(alpha: 0.65) : AppColors.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
