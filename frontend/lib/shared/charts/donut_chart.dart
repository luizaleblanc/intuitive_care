import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Fatia percentual exibida no gráfico de rosca.
class DonutSlice {
  final String label;
  final double pct;
  final Color color;
  const DonutSlice(this.label, this.pct, this.color);
}

/// Gráfico de rosca proporcional com texto centralizado.
class Donut extends StatelessWidget {
  final List<DonutSlice> data;
  final double size;
  final String center;
  final String sub;

  const Donut({super.key, required this.data, this.size = 170, required this.center, required this.sub});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _DonutPainter(data, dark)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(center, style: AppText.display(24, weight: FontWeight.w700, color: AppColors.sageText)),
              Text(sub, style: AppText.sans(11, weight: FontWeight.w500, color: AppColors.sageMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> data;
  final bool dark;
  _DonutPainter(this.data, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    // Mesma geometria do protótipo: viewBox 160, raio 62, traço 20.
    final scale = size.width / 160;
    final r = 62 * scale;
    final stroke = 20 * scale;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = dark ? Colors.white.withValues(alpha: 0.08) : AppColors.forest.withValues(alpha: 0.08));

    final circ = 2 * math.pi * r;
    var acc = 0.0;
    for (final d in data) {
      final len = d.pct / 100 * circ;
      final visible = math.max(len - 3 * scale, 0.0);
      if (visible > 0) {
        // Desconta a ponta arredondada para manter o comprimento visual igual ao SVG.
        final sweep = math.max((visible - stroke) / r, 0.001);
        final start = -math.pi / 2 + (acc + stroke / 2) / r;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = d.color,
        );
      }
      acc += len;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.data != data || old.dark != dark;
}
