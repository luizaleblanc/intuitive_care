import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Barra de progresso horizontal arredondada.
class ProgressBar extends StatelessWidget {
  final double fraction;
  final double height;
  final Color? color;
  final Color? track;
  const ProgressBar({super.key, required this.fraction, this.height = 8, this.color, this.track});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track ?? AppColors.surface, borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: color ?? AppColors.mint, borderRadius: BorderRadius.circular(999))),
      ),
    );
  }
}
