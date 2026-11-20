import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';

const _cross =
    'M19 7h10a2 2 0 0 1 2 2v8a2 2 0 0 0 2 2h6a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-6a2 2 0 0 0-2 2v8a2 2 0 0 1-2 2H19a2 2 0 0 1-2-2v-8a2 2 0 0 0-2-2H9a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2h6a2 2 0 0 0 2-2V9a2 2 0 0 1 2-2Z';

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Símbolo "Cruz de Dados": cruz da saúde em traço contínuo + 3 barras ETL + ponto do beneficiário.
class Mark extends StatelessWidget {
  final double size;
  final Color color;
  final Color? bg;
  final double strokeWidth;

  const Mark({
    super.key,
    this.size = 48,
    this.color = AppColors.mint,
    this.bg = AppColors.forest,
    this.strokeWidth = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    final c = _hex(color);
    final svg = '''
<svg width="48" height="48" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  ${bg != null ? '<rect width="48" height="48" rx="14" fill="${_hex(bg!)}"/>' : ''}
  <path d="$_cross" stroke="$c" stroke-width="$strokeWidth" stroke-linejoin="round"/>
  <path d="M20 31v-4M24 31v-8M28 31v-12" stroke="$c" stroke-width="$strokeWidth" stroke-linecap="round"/>
  <circle cx="35.5" cy="12.5" r="2.6" fill="$c"/>
</svg>''';
    return ExcludeSemantics(child: SvgPicture.string(svg, width: size, height: size));
  }
}

/// Logo horizontal: símbolo + wordmark "intuitivecare" + assinatura em uma linha.
class LogoHorizontal extends StatelessWidget {
  final bool negative;
  final double size;

  const LogoHorizontal({super.key, this.negative = false, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final escuro = negative || AppColors.watchDark(context);
    return Semantics(
      label: 'Intuitive Care',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mark(size: size, bg: negative ? null : AppColors.primaryBg),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'intuitivecare',
                style: AppText.display(22, color: escuro ? AppColors.mint : AppColors.forest).copyWith(height: 1),
              ),
              const SizedBox(height: 4),
              Text(
                'CONTROLE E TRATAMENTO DE DADOS',
                maxLines: 1,
                softWrap: false,
                style: AppText.sans(
                  9,
                  weight: FontWeight.w600,
                  spacing: 9 * 0.06,
                  height: 1,
                  color: escuro ? Colors.white.withValues(alpha: 0.65) : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
