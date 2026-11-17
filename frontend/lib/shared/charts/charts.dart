import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/formatters.dart';

class BarDatum {
  final String label;
  final double value;
  const BarDatum(this.label, this.value);
}

/// Barras em pílula: trilho Sage 70%, barra Mint, última/hover em Forest com tooltip.
class PillBarChart extends StatefulWidget {
  final List<BarDatum> data;
  final double height;
  final String unit;

  const PillBarChart({super.key, required this.data, this.height = 200, this.unit = 'bi'});

  @override
  State<PillBarChart> createState() => _PillBarChartState();
}

class _PillBarChartState extends State<PillBarChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Sem dados para o período.', style: AppText.sans(14, color: AppColors.muted))),
      );
    }
    final maxV = widget.data.map((d) => d.value).fold<double>(0, math.max);
    // Espaço do tooltip (~19px) + rótulo (~15px) + espaçamentos (16px).
    final track = widget.height - 54;
    return Semantics(
      label: 'Gráfico de barras: ${widget.data.map((d) => '${d.label} ${fmtBiNum(d.value)} ${widget.unit}').join(', ')}',
      child: SizedBox(
        height: widget.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < widget.data.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hover = i),
                  onExit: (_) => setState(() => _hover = null),
                  child: Builder(builder: (context) {
                    final d = widget.data[i];
                    final active = _hover == i || (_hover == null && i == widget.data.length - 1);
                    final h = maxV <= 0 ? 0.0 : (d.value / maxV) * track;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: active ? 1 : 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.forest, borderRadius: BorderRadius.circular(999)),
                            child: Text('${fmtDec1(d.value)} ${widget.unit}',
                                maxLines: 1,
                                style: AppText.sans(11, weight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: track,
                          constraints: const BoxConstraints(maxWidth: 44),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            height: h,
                            decoration: BoxDecoration(
                              color: active ? AppColors.forest : AppColors.mint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(d.label,
                            maxLines: 1,
                            style: AppText.sans(11, weight: FontWeight.w500, color: AppColors.caption)),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DonutSlice {
  final String label;
  final double pct;
  final Color color;
  const DonutSlice(this.label, this.pct, this.color);
}

class Donut extends StatelessWidget {
  final List<DonutSlice> data;
  final double size;
  final String center;
  final String sub;

  const Donut({super.key, required this.data, this.size = 170, required this.center, required this.sub});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.square(size), painter: _DonutPainter(data)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(center, style: AppText.display(24, weight: FontWeight.w700, color: AppColors.forest)),
                Text(sub,
                    style: AppText.sans(11,
                        weight: FontWeight.w500, color: AppColors.forest.withValues(alpha: 0.75))),
              ],
            ),
          ],
        ),
      );
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> data;
  _DonutPainter(this.data);

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
          ..color = AppColors.forest.withValues(alpha: 0.08));

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
  bool shouldRepaint(covariant _DonutPainter old) => old.data != data;
}

/// Barra de progresso horizontal arredondada.
class ProgressBar extends StatelessWidget {
  final double fraction;
  final double height;
  final Color color;
  final Color track;
  const ProgressBar(
      {super.key, required this.fraction, this.height = 8, this.color = AppColors.mint, this.track = AppColors.surface});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(999)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
        ),
      );
}
