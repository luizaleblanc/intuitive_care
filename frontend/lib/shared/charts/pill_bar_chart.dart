import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/formatters.dart';
import 'chart_types.dart';

export 'chart_types.dart' show BarDatum;

/// Barras em pílula: trilho Sage, barra Mint, última/hover destacada com tooltip.
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
    final dark = AppColors.watchDark(context);
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Sem dados para o período.', style: AppText.sans(14, color: AppColors.muted))),
      );
    }
    final maxV = widget.data.map((d) => d.value).fold<double>(0, math.max);
    // Espaço do tooltip (~19px) + rótulo em até 2 linhas (~30px) + espaçamentos (16px).
    final track = widget.height - 70;
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
                              color: AppColors.primaryBg,
                              borderRadius: BorderRadius.circular(999),
                              border: dark ? Border.all(color: AppColors.mint.withValues(alpha: 0.35)) : null,
                            ),
                            child: Text('${fmtDec1(d.value)} ${widget.unit}',
                                maxLines: 1, style: AppText.numeric(11, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: track,
                          constraints: const BoxConstraints(maxWidth: 44),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: dark ? 0.95 : 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            height: h,
                            decoration: BoxDecoration(
                              color: active ? (dark ? AppColors.lime : AppColors.forest) : AppColors.mint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 30,
                          child: Text(d.label,
                              maxLines: 2,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: AppText.numeric(10, weight: FontWeight.w500, color: AppColors.caption)
                                  .copyWith(height: 1.25)),
                        ),
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
