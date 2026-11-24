import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';

enum ButtonVariant { primary, accent, secondary, ghost, danger, dangerSolid }

enum ButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? iconRight;
  final bool loading;
  final String? loadingLabel;
  final bool expand;

  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.iconRight,
    this.loading = false,
    this.loadingLabel,
    this.expand = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final (bg, bgHover, fg, border, borderHover) = switch (widget.variant) {
      ButtonVariant.primary => (AppColors.primaryBg, AppColors.primaryHover, Colors.white, null, null),
      ButtonVariant.accent => (AppColors.mint, AppColors.mintHover, AppColors.forest, null, null),
      ButtonVariant.secondary => (AppColors.card, AppColors.cardHover, AppColors.ink, AppColors.slate200, AppColors.slate300),
      ButtonVariant.ghost => (Colors.transparent, AppColors.slate100, AppColors.ink, null, null),
      ButtonVariant.danger => (AppColors.card, AppColors.red50, AppColors.danger, AppColors.red200, AppColors.red200),
      ButtonVariant.dangerSolid => (AppColors.danger, AppColors.red600, Colors.white, null, null),
    };
    final (height, padH, fontSize, iconSize, gap) = switch (widget.size) {
      ButtonSize.sm => (32.0, 12.0, 12.0, 14.0, 6.0),
      ButtonSize.md => (40.0, 16.0, 14.0, 16.0, 8.0),
      ButtonSize.lg => (48.0, 24.0, 15.0, 16.0, 8.0),
    };
    final hovering = _hover && enabled;
    final b = hovering ? (borderHover ?? border) : border;

    final children = <Widget>[
      if (widget.loading) ...[
        Spinner(size: iconSize, color: fg),
        SizedBox(width: gap),
      ] else if (widget.icon != null) ...[
        Icon(widget.icon, size: iconSize, color: fg),
        SizedBox(width: gap),
      ],
      Flexible(
        child: Text(
          widget.loading ? (widget.loadingLabel ?? widget.label) : widget.label,
          overflow: TextOverflow.ellipsis,
          style: AppText.sans(fontSize, weight: FontWeight.w600, color: fg),
        ),
      ),
      if (widget.iconRight != null && !widget.loading) ...[
        SizedBox(width: gap),
        Icon(widget.iconRight, size: iconSize, color: fg),
      ],
    ];

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Opacity(
          opacity: enabled || widget.loading ? 1 : 0.5,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              borderRadius: BorderRadius.circular(999),
              focusColor: AppColors.mint.withValues(alpha: 0.2),
              hoverColor: Colors.transparent,
              splashColor: Colors.white.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: height,
                width: widget.expand ? double.infinity : null,
                padding: EdgeInsets.symmetric(horizontal: padH),
                decoration: BoxDecoration(
                  color: hovering ? bgHover : bg,
                  borderRadius: BorderRadius.circular(999),
                  border: b != null ? Border.all(color: b) : null,
                  boxShadow: widget.variant == ButtonVariant.primary
                      ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão circular só com ícone (sempre com rótulo acessível).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color? foreground;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.background = Colors.transparent,
    this.foreground,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final fg = foreground ?? AppColors.muted;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.45, color: fg)),
          ),
        ),
      ),
    );
  }
}

class Spinner extends StatefulWidget {
  final double size;
  final Color? color;
  const Spinner({super.key, this.size = 16, this.color});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return RotationTransition(
      turns: _c,
      child: Icon(LucideIcons.loaderCircle, size: widget.size, color: widget.color ?? AppColors.brandText),
    );
  }
}
