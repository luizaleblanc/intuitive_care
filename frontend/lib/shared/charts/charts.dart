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
                                style: AppText.numeric(11, color: Colors.white)),
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
                            overflow: TextOverflow.ellipsis,
                            style: AppText.numeric(11, weight: FontWeight.w500, color: AppColors.caption)),
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


/// Linha/área de evolução: série principal em Forest com área degradê; comparação em Mint tracejada.
class TrendAreaChart extends StatefulWidget {
  final List<BarDatum> data;
  final List<BarDatum> comparacao;
  final String unit;
  final double height;
  final String rotuloComparacao;

  const TrendAreaChart({
    super.key,
    required this.data,
    this.comparacao = const [],
    this.unit = '',
    this.height = 240,
    this.rotuloComparacao = 'Período anterior',
  });

  @override
  State<TrendAreaChart> createState() => _TrendAreaChartState();
}

class _TrendAreaChartState extends State<TrendAreaChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final dados = widget.data;
    if (dados.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Sem dados para o período.', style: AppText.sans(14, color: AppColors.muted))),
      );
    }
    final ativo = _hover ?? dados.length - 1;
    final comp = widget.comparacao;
    return Semantics(
      label: 'Gráfico de evolução: ${dados.map((d) => '${d.label} ${fmtDec1(d.value)} ${widget.unit}').join(', ')}',
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (context, c) {
          final largura = c.maxWidth;
          int indice(double x) {
            if (dados.length == 1) return 0;
            final passo = (largura - _TrendPainter.margemEsq) / (dados.length - 1);
            return ((x - _TrendPainter.margemEsq) / passo).round().clamp(0, dados.length - 1);
          }

          return MouseRegion(
            onHover: (e) => setState(() => _hover = indice(e.localPosition.dx)),
            onExit: (_) => setState(() => _hover = null),
            child: GestureDetector(
              onTapDown: (e) => setState(() => _hover = indice(e.localPosition.dx)),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(largura, widget.height),
                    painter: _TrendPainter(dados, comp, ativo, widget.unit),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${dados[ativo].label} · ${fmtDec1(dados[ativo].value)} ${widget.unit}'
                        '${ativo < comp.length ? '  |  ${widget.rotuloComparacao}: ${fmtDec1(comp[ativo].value)} ${widget.unit}' : ''}',
                        style: AppText.numeric(11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  static const margemEsq = 44.0;
  static const margemSup = 34.0;
  static const margemInf = 26.0;

  final List<BarDatum> dados;
  final List<BarDatum> comp;
  final int ativo;
  final String unit;
  _TrendPainter(this.dados, this.comp, this.ativo, this.unit);

  @override
  void paint(Canvas canvas, Size size) {
    final valores = [...dados.map((d) => d.value), ...comp.map((d) => d.value)];
    var maxV = valores.fold<double>(0, math.max);
    var minV = valores.fold<double>(maxV, math.min);
    if (maxV == minV) {
      maxV += 1;
      minV = math.max(0, minV - 1);
    }
    minV = math.max(0, minV - (maxV - minV) * 0.15);
    final altura = size.height - margemSup - margemInf;
    final largura = size.width - margemEsq;
    double y(double v) => margemSup + altura - (v - minV) / (maxV - minV) * altura;
    double x(int i) => margemEsq + (dados.length == 1 ? largura / 2 : largura * i / (dados.length - 1));

    final grade = Paint()
      ..color = AppColors.slate200
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final v = minV + (maxV - minV) * k / 3;
      final yy = y(v);
      canvas.drawLine(Offset(margemEsq, yy), Offset(size.width, yy), grade);
      _texto(canvas, fmtDec1(v), Offset(0, yy - 7), AppColors.muted, 40, TextAlign.right);
    }

    Path linha(List<BarDatum> s) {
      final p = Path();
      for (var i = 0; i < s.length && i < dados.length; i++) {
        final o = Offset(x(i), y(s[i].value));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    if (comp.isNotEmpty) {
      final tracejado = Paint()
        ..color = AppColors.mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final m in linha(comp).computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 9) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), tracejado);
        }
      }
    }

    final principal = linha(dados);
    final area = Path.from(principal)
      ..lineTo(x(dados.length - 1), margemSup + altura)
      ..lineTo(x(0), margemSup + altura)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forest.withValues(alpha: 0.18), AppColors.forest.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, margemSup, size.width, altura)),
    );
    canvas.drawPath(
      principal,
      Paint()
        ..color = AppColors.forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(Offset(x(ativo), margemSup), Offset(x(ativo), margemSup + altura),
        Paint()..color = AppColors.forest.withValues(alpha: 0.2));
    for (var i = 0; i < dados.length; i++) {
      final o = Offset(x(i), y(dados[i].value));
      canvas.drawCircle(o, i == ativo ? 6 : 3.5, Paint()..color = i == ativo ? AppColors.forest : AppColors.mint);
      canvas.drawCircle(o, i == ativo ? 3 : 1.5, Paint()..color = Colors.white);
      // Rótulos espaçados para não se sobreporem.
      final passo = (dados.length / 8).ceil();
      if (i % passo == 0 || i == dados.length - 1) {
        _texto(canvas, dados[i].label, Offset(o.dx - 30, size.height - 16), AppColors.caption, 60, TextAlign.center);
      }
    }
  }

  void _texto(Canvas canvas, String t, Offset o, Color cor, double largura, TextAlign align) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: AppText.numeric(10, weight: FontWeight.w500, color: cor)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: largura, maxWidth: largura);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.dados != dados || old.comp != comp || old.ativo != ativo || old.unit != unit;
}

class ItemRanking {
  final String rotulo;
  final String? detalhe;
  final double valor;
  final String valorFormatado;
  const ItemRanking(this.rotulo, this.valor, this.valorFormatado, {this.detalhe});
}

/// Ranking horizontal: posição, nome, barra (Forest no 1º, Mint nos demais) e valor tabular.
class HorizontalRanking extends StatelessWidget {
  final List<ItemRanking> itens;
  final ValueChanged<int>? onTap;
  const HorizontalRanking({super.key, required this.itens, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Nenhuma operadora no recorte.', style: AppText.sans(14, color: AppColors.muted))),
      );
    }
    final maxV = itens.map((i) => i.valor).fold<double>(0, math.max);
    return Column(
      children: [
        for (var i = 0; i < itens.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}', style: AppText.numeric(12, color: AppColors.muted)),
                  ),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itens[i].rotulo,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w600)),
                        if (itens[i].detalhe != null)
                          Text(itens[i].detalhe!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: ProgressBar(
                      fraction: maxV <= 0 ? 0 : itens[i].valor / maxV,
                      color: i == 0 ? AppColors.forest : AppColors.mint,
                      track: AppColors.surface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(itens[i].valorFormatado,
                        textAlign: TextAlign.right, style: AppText.numeric(13, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
