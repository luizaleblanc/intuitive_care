import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/analitico_model.dart';
import '../../shared/charts/charts.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';

/// Tabela comparativa do plano de contas ANS exibida na aba de despesas.
class DespesasTabelaContas extends StatelessWidget {
  final ContasModel c;
  final String? destaque;
  const DespesasTabelaContas(this.c, {super.key, this.destaque});

  static const _flex = [12, 36, 20, 12, 12];

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final maxV = c.contas.fold<double>(
      0,
      (m, l) => math.max(m, math.max(l.valorAtual.abs(), (l.valorAnterior ?? 0).abs())),
    );
    Widget th(String t, int i, {TextAlign align = TextAlign.left}) => Expanded(
          flex: _flex[i],
          child: Text(
            t.toUpperCase(),
            textAlign: align,
            style: AppText.sans(11, weight: FontWeight.w700, color: Colors.white, spacing: 11 * 0.05),
          ),
        );
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: CardHeader(
              'Demonstrações contábeis · plano de contas ANS',
              subtitle: c.periodosSelecionados.length > 1
                  ? 'Total do setor em R\$ bilhões · '
                      '${fmtPeriodosSelecionados([for (final x in c.periodosSelecionados) (x.ano, x.trimestre)])}'
                  : 'Total do setor em R\$ bilhões · ${fmtPeriodo(c.periodo.ano, c.periodo.trimestre)} '
                      'vs ${fmtTrimestre(c.periodoAnterior.trimestre)} de ${c.periodoAnterior.ano}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legenda(AppColors.brandText, 'Atual'),
                  const SizedBox(width: 16),
                  _legenda(AppColors.mint.withValues(alpha: 0.5), 'Anterior'),
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.primaryBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              th('Conta', 0),
              th('Descrição', 1),
              th('Comparativo', 2),
              th('Atual', 3, align: TextAlign.right),
              th('Var.', 4, align: TextAlign.right),
            ]),
          ),
          if (c.contas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'Sem contas para o filtro selecionado.',
                textAlign: TextAlign.center,
                style: AppText.sans(14, color: AppColors.muted),
              ),
            ),
          for (final l in c.contas) _LinhaConta(l, maxV: maxV, flex: _flex, destacada: l.codigo == destaque),
        ],
      ),
    );
  }

  Widget _legenda(Color cor, String t) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: AppText.sans(12, color: AppColors.muted)),
      ]);
}

class _LinhaConta extends StatefulWidget {
  final ContaLinha l;
  final double maxV;
  final List<int> flex;
  final bool destacada;
  const _LinhaConta(this.l, {required this.maxV, required this.flex, required this.destacada});

  @override
  State<_LinhaConta> createState() => _LinhaContaState();
}

class _LinhaContaState extends State<_LinhaConta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final l = widget.l;
    final f = widget.flex;
    final v = variation(l.valorAtual, l.valorAnterior);
    double frac(double? x) => widget.maxV == 0 || x == null ? 0 : x.abs() / widget.maxV;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: widget.destacada
              ? AppColors.mint.withValues(alpha: 0.14)
              : (_hover ? AppColors.cardHover : AppColors.card),
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: f[0],
              child: Padding(
                padding: EdgeInsets.only(left: l.nivel * 10.0),
                child: Text(l.codigo, style: AppText.mono(14)),
              ),
            ),
            Expanded(
              flex: f[1],
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizarDescricaoConta(l.descricao),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(14, weight: l.nivel == 0 ? FontWeight.w700 : FontWeight.w500),
                    ),
                    Text(l.grupo, style: AppText.sans(11, color: AppColors.caption)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: f[2],
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    ProgressBar(
                      fraction: frac(l.valorAtual),
                      height: 6,
                      color: AppColors.brandText,
                      track: Colors.transparent,
                    ),
                    const SizedBox(height: 4),
                    ProgressBar(
                      fraction: frac(l.valorAnterior),
                      height: 6,
                      color: AppColors.mint.withValues(alpha: 0.5),
                      track: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: f[3],
              child: Text(
                fmtBiNum(l.valorAtual / 1e9),
                textAlign: TextAlign.right,
                style: AppText.sans(14, weight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: f[4],
              child: Align(
                alignment: Alignment.centerRight,
                child: v == null ? Text('—', style: AppText.sans(14, color: AppColors.muted)) : DeltaBadge(value: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Descrições do plano de contas vêm em CAIXA ALTA: exibe só a primeira letra maiúscula.
String capitalizarDescricaoConta(String s) {
  final t = s.trim();
  if (t.isEmpty || t != t.toUpperCase()) return t;
  final lower = t.toLowerCase().replaceAll(' sus', ' SUS').replaceAll('(sus)', '(SUS)');
  final i = lower.indexOf(RegExp(r'[a-zà-ú]'));
  return i < 0 ? lower : lower.substring(0, i) + lower[i].toUpperCase() + lower.substring(i + 1);
}
