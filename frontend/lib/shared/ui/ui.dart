import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../utils/formatters.dart';

// ============================================================================
// Button
// ============================================================================
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
    final enabled = widget.onPressed != null && !widget.loading;
    final (bg, bgHover, fg, border, borderHover) = switch (widget.variant) {
      ButtonVariant.primary => (AppColors.forest, AppColors.forestHover, Colors.white, null, null),
      ButtonVariant.accent => (AppColors.mint, AppColors.mintHover, AppColors.forest, null, null),
      ButtonVariant.secondary => (Colors.white, const Color(0xFFF8FAFC), AppColors.ink, AppColors.slate200, AppColors.slate300),
      ButtonVariant.ghost => (Colors.transparent, AppColors.slate100, AppColors.ink, null, null),
      ButtonVariant.danger => (Colors.white, AppColors.red50, AppColors.danger, AppColors.red200, AppColors.red200),
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
  final Color foreground;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.background = Colors.transparent,
    this.foreground = AppColors.muted,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
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
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.45, color: foreground)),
          ),
        ),
      ),
    );
  }
}

class Spinner extends StatefulWidget {
  final double size;
  final Color color;
  const Spinner({super.key, this.size = 16, this.color = AppColors.forest});

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
  Widget build(BuildContext context) => RotationTransition(
        turns: _c,
        child: Icon(LucideIcons.loaderCircle, size: widget.size, color: widget.color),
      );
}

// ============================================================================
// Pills / badges
// ============================================================================
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
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (AppColors.slate100, AppColors.slate700),
      PillTone.forest => (AppColors.forest, Colors.white),
      PillTone.mint => (AppColors.mint.withValues(alpha: 0.2), AppColors.forest),
      PillTone.lime => (AppColors.lime, AppColors.forest),
      PillTone.ok => (AppColors.emerald50, AppColors.emerald700),
      PillTone.danger => (AppColors.red50, AppColors.red600),
      PillTone.warn => (AppColors.amber50, AppColors.amber700),
      PillTone.sage => (AppColors.sage, AppColors.forest),
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

// ============================================================================
// Card
// ============================================================================
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final bool clip;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
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
    final clickable = widget.onTap != null;
    final lifted = clickable && _hover;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        boxShadow: widget.color == AppColors.sage ? null : (lifted ? AppShadows.lift : AppShadows.card),
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
  final Color color;
  final double size;

  const CardHeader(this.title,
      {super.key, this.subtitle, this.trailing, this.color = AppColors.ink, this.size = 17});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(size, weight: FontWeight.w700, color: color)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: AppText.sans(size >= 17 ? 14 : 12,
                          color: color == AppColors.forest ? AppColors.forest.withValues(alpha: 0.7) : AppColors.muted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      );
}

// ============================================================================
// KPI
// ============================================================================
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? AppColors.forest : Colors.white,
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
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
                              color: dark ? Colors.white.withValues(alpha: 0.7) : AppColors.muted)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withValues(alpha: 0.1) : AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 17, color: dark ? AppColors.mint : AppColors.forest),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: dark
                        ? AppText.heroValue()
                        : AppText.display(28, weight: FontWeight.w700),
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
                              color: dark ? Colors.white.withValues(alpha: 0.6) : AppColors.muted)),
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

// ============================================================================
// Inputs
// ============================================================================
InputDecoration pillInputDecoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  bool error = false,
  double height = 40,
}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.sans(14, color: AppColors.muted.withValues(alpha: 0.8)),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: (height - 20) / 2),
    prefixIcon: icon == null ? null : Icon(icon, size: 16, color: AppColors.muted),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
    suffixIcon: suffix,
    border: b(error ? AppColors.red300 : AppColors.slate200),
    enabledBorder: b(error ? AppColors.red300 : AppColors.slate200),
    focusedBorder: b(error ? AppColors.danger : AppColors.mint, 1.5),
  );
}

/// Halo de foco Mint 4px (seção 8 · estados de interação).
class FocusHalo extends StatefulWidget {
  final Widget child;
  final bool error;
  const FocusHalo({super.key, required this.child, this.error = false});

  @override
  State<FocusHalo> createState() => _FocusHaloState();
}

class _FocusHaloState extends State<FocusHalo> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: (widget.error ? AppColors.red200 : AppColors.mint).withValues(alpha: widget.error ? 0.6 : 0.2),
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      );
}

class SearchInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final double? width;
  final Duration debounce;

  const SearchInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.placeholder = 'Buscar...',
    this.width,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final _controller = TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(covariant SearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: 40,
        child: FocusHalo(
          child: TextField(
            controller: _controller,
            style: AppText.sans(14),
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _timer?.cancel();
              _timer = Timer(widget.debounce, () => widget.onChanged(v));
            },
            onSubmitted: widget.onSubmitted,
            decoration: pillInputDecoration(hint: widget.placeholder, icon: LucideIcons.search),
          ),
        ),
      );
}

/// Campo de texto pill com rótulo associado (formulários).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const LabeledField({super.key, required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.sans(14, weight: FontWeight.w600))),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final bool error;
  final double height;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final VoidCallback? onTap;

  const PillTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.error = false,
    this.height = 44,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
    this.autofillHints,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: FocusHalo(
          error: error,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            readOnly: readOnly,
            onTap: onTap,
            style: AppText.sans(14),
            decoration: pillInputDecoration(hint: hint, icon: icon, suffix: suffix, error: error, height: height)
                .copyWith(labelText: null, semanticCounterText: label),
          ),
        ),
      );
}

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
    final maxH = espacoAbaixo >= 220 ? espacoAbaixo.clamp(220.0, 380.0) : 340.0;
    final top = espacoAbaixo >= 220
        ? origem.dy + tamanho.height + 6.0
        : (origem.dy - maxH - 6.0).clamp(12.0, tela.height - 120.0);

    final rascunho = Set<T>.from(selected);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setModalState) {
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
                  color: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.16),
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
                          child: ListView(
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
                                            color: rascunho.contains(o.$1) ? AppColors.forest : Colors.white,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: rascunho.contains(o.$1) ? AppColors.forest : AppColors.slate300,
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
                                              color: rascunho.contains(o.$1) ? AppColors.forest : AppColors.ink,
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
                        Container(
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate100))),
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
    if (!_igual(rascunho, selected)) {
      onChanged(Set<T>.unmodifiable(rascunho));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: filtrado ? AppColors.sage.withValues(alpha: 0.45) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => _abrir(context),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: filtrado ? AppColors.forest.withValues(alpha: 0.4) : AppColors.slate200),
                ),
                child: Row(
                  mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Icon(icon, size: 14, color: filtrado ? AppColors.forest : AppColors.muted),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: width == null ? FlexFit.loose : FlexFit.tight,
                      child: Text(
                        rotulo,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          14,
                          weight: filtrado ? FontWeight.w600 : FontWeight.w500,
                          color: filtrado ? AppColors.forest : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(LucideIcons.chevronDown, size: 14, color: filtrado ? AppColors.forest : AppColors.muted),
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
          constraints: BoxConstraints(minWidth: width ?? 200, maxHeight: 360),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
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
                              color: o.$1 == value ? AppColors.forest : AppColors.ink)),
                    ),
                    if (o.$1 == value) const Icon(LucideIcons.check, size: 14, color: AppColors.forest),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.only(left: 12, right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Toggle
// ============================================================================
class ToggleRow extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  final String label;
  final String desc;

  const ToggleRow({super.key, required this.on, required this.onChanged, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) => Semantics(
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
                    color: on ? AppColors.forest : AppColors.slate200,
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

/// Controle segmentado (Tema: Claro / Escuro / Sistema).
class SegmentedPill<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  const SegmentedPill({super.key, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            for (final o in options)
              Expanded(
                child: Semantics(
                  selected: o.$1 == value,
                  button: true,
                  child: GestureDetector(
                    onTap: () => onChanged(o.$1),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: o.$1 == value ? AppColors.forest : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(o.$2,
                            style: AppText.sans(12,
                                weight: FontWeight.w600, color: o.$1 == value ? Colors.white : AppColors.muted)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

// ============================================================================
// Feedback
// ============================================================================
class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBox(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: AppColors.red50, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(LucideIcons.circleAlert, size: 15, color: AppColors.red700),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: AppText.sans(14, color: AppColors.red700))),
              if (onRetry != null) AppButton('Tentar novamente', size: ButtonSize.sm, variant: ButtonVariant.secondary, onPressed: onRetry),
            ],
          ),
        ),
      );
}

class LoadingBlock extends StatelessWidget {
  final String label;
  final double height;
  const LoadingBlock({super.key, this.label = 'Carregando...', this.height = 240});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spinner(size: 18),
              const SizedBox(width: 10),
              Text(label, style: AppText.sans(14, color: AppColors.muted)),
            ],
          ),
        ),
      );
}

/// Toast centralizado embaixo, some em 2,2s (seção 8).
class ToastController extends ChangeNotifier {
  String? _message;
  bool _error = false;
  Timer? _timer;

  String? get message => _message;
  bool get isError => _error;

  void show(String message, {bool error = false}) {
    _message = message;
    _error = error;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      _message = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ToastOverlay extends StatelessWidget {
  final ToastController controller;
  final Widget child;
  const ToastOverlay({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final msg = controller.message;
              return Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    ),
                    child: msg == null
                        ? const SizedBox.shrink()
                        : Center(
                            key: ValueKey(msg),
                            child: Semantics(
                              liveRegion: true,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: AppShadows.lift,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(controller.isError ? LucideIcons.circleAlert : LucideIcons.circleCheck,
                                          size: 16, color: controller.isError ? AppColors.red300 : AppColors.mint),
                                      const SizedBox(width: 8),
                                      Text(msg,
                                          style: AppText.sans(14, weight: FontWeight.w500, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      );
}

// ============================================================================
// Drawer lateral (480px)
// ============================================================================
Future<T?> showSideDrawer<T>(BuildContext context, {required WidgetBuilder builder, double width = 480}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: AppColors.ink.withValues(alpha: 0.3),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 24,
        child: SizedBox(width: width, height: double.infinity, child: builder(ctx)),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Linha "rótulo à esquerda, valor à direita".
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.sans(14, color: AppColors.muted)),
          Text(value, style: AppText.sans(14, weight: FontWeight.w700)),
        ],
      );
}
