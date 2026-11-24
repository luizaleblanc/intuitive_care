import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';

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
    fillColor: AppColors.inputFill,
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
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Focus(
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
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return SizedBox(
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
}

/// Campo de texto pill com rótulo associado (formulários).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const LabeledField({super.key, required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Column(
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
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return SizedBox(
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
}
