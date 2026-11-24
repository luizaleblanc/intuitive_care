import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/operadora_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';

class OperadoraDrawerHeader extends StatelessWidget {
  final OperadoraModel? operadora;
  final VoidCallback onClose;

  const OperadoraDrawerHeader({super.key, required this.operadora, required this.onClose});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final o = operadora;
    return Container(
      color: AppColors.heroBg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.building2, size: 22, color: AppColors.mint),
              ),
              const Spacer(),
              AppIconButton(
                icon: LucideIcons.x,
                label: 'Fechar',
                background: Colors.white.withValues(alpha: 0.1),
                foreground: Colors.white,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(o == null ? 'Nova operadora' : nomeProprio(o.nomeExibicao),
              style: AppText.display(20, weight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(o?.razaoSocial ?? 'Cadastro manual de operadora com registro na ANS',
              style: AppText.sans(14, color: Colors.white.withValues(alpha: 0.7))),
          if (o != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Pill('Reg. ANS ${o.registroAns}', tone: PillTone.lime),
              const SizedBox(width: 8),
              Pill(o.uf, background: Colors.white.withValues(alpha: 0.1), foreground: Colors.white),
            ]),
          ],
        ],
      ),
    );
  }
}

class OperadoraCampoBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool mono;
  final bool editavel;
  final bool numerico;
  final int? maxLength;

  const OperadoraCampoBox({
    super.key,
    required this.label,
    required this.controller,
    this.mono = false,
    this.editavel = false,
    this.numerico = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppText.sans(11, weight: FontWeight.w600, color: AppColors.caption, spacing: 11 * 0.05)),
          const SizedBox(height: 4),
          if (editavel)
            SizedBox(
              height: 34,
              child: TextField(
                controller: controller,
                style: mono ? AppText.mono(14, weight: FontWeight.w500, color: AppColors.ink) : AppText.sans(14),
                keyboardType: numerico ? TextInputType.number : null,
                inputFormatters: [
                  if (numerico) FilteringTextInputFormatter.digitsOnly,
                  if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.slate200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.mint)),
                ),
              ),
            )
          else
            Text(controller.text.isEmpty ? '—' : controller.text,
                style: mono ? AppText.mono(14, color: AppColors.ink) : AppText.sans(14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class OperadoraSageCard extends StatelessWidget {
  final String label;
  final String valor;

  const OperadoraSageCard({super.key, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppText.sans(11, weight: FontWeight.w600, color: AppColors.sageMuted, spacing: 11 * 0.05)),
          const SizedBox(height: 2),
          Text(valor, style: AppText.display(18, weight: FontWeight.w700, color: AppColors.sageText)),
        ],
      ),
    );
  }
}

class OperadoraInfoLinha extends StatelessWidget {
  final String label;
  final Widget valor;

  const OperadoraInfoLinha({super.key, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(label, style: AppText.sans(14, color: AppColors.muted)),
        const Spacer(),
        valor,
      ]),
    );
  }
}
