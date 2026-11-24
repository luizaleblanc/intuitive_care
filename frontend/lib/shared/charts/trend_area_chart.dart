import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/formatters.dart';
import 'chart_types.dart';

export 'chart_types.dart' show BarDatum;

/// Linha/área de evolução: série principal com área degradê; comparação tracejada.
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
    final dark = AppColors.watchDark(context);
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
                    painter: _TrendPainter(dados, comp, ativo, widget.unit, dark),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(999),
                        border: dark ? Border.all(color: AppColors.mint.withValues(alpha: 0.35)) : null,
                      ),
                      child: Text(
                        '${dados[ativo].label.replaceAll('\n', ' de ')} · ${fmtDec1(dados[ativo].value)} ${widget.unit}'
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
  static const margemInf = 38.0;

  final List<BarDatum> dados;
  final List<BarDatum> comp;
  final int ativo;
  final String unit;
  final bool dark;
  _TrendPainter(this.dados, this.comp, this.ativo, this.unit, this.dark);

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

    final linhaCor = dark ? AppColors.mint : AppColors.forest;
    final compCor = dark ? AppColors.lime : AppColors.mint;

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
        ..color = compCor
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
          colors: [linhaCor.withValues(alpha: dark ? 0.24 : 0.18), linhaCor.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, margemSup, size.width, altura)),
    );
    canvas.drawPath(
      principal,
      Paint()
        ..color = linhaCor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(Offset(x(ativo), margemSup), Offset(x(ativo), margemSup + altura),
        Paint()..color = linhaCor.withValues(alpha: 0.25));
    for (var i = 0; i < dados.length; i++) {
      final o = Offset(x(i), y(dados[i].value));
      canvas.drawCircle(o, i == ativo ? 6 : 3.5, Paint()..color = i == ativo ? linhaCor : compCor);
      canvas.drawCircle(o, i == ativo ? 3 : 1.5, Paint()..color = AppColors.card);
      // Rótulos espaçados (até ~84px cada) para não se sobreporem.
      final cabem = ((size.width - margemEsq) / 84).floor().clamp(1, dados.length);
      final passo = (dados.length / cabem).ceil();
      if (i % passo == 0 || i == dados.length - 1) {
        _texto(canvas, dados[i].label, Offset((o.dx - 42).clamp(0.0, size.width - 84), size.height - 30), AppColors.caption, 84, TextAlign.center,
            linhas: 2);
      }
    }
  }

  void _texto(Canvas canvas, String t, Offset o, Color cor, double largura, TextAlign align, {int linhas = 1}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: AppText.numeric(10, weight: FontWeight.w500, color: cor).copyWith(height: 1.25)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: linhas,
      ellipsis: '…',
    )..layout(minWidth: largura, maxWidth: largura);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.dados != dados || old.comp != comp || old.ativo != ativo || old.unit != unit || old.dark != dark;
}
