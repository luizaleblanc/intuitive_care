import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/analitico_model.dart';
import '../../shared/charts/charts.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import 'despesas_tabela_contas.dart';

/// Painel lateral com a composição médico-hospitalar por forma de pagamento.
class DespesasComposicaoCard extends StatelessWidget {
  final List<ComposicaoItem> itens;
  const DespesasComposicaoCard(this.itens, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    return AppCard(
      color: AppColors.sage,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Composição médico-hospitalar',
            style: AppText.display(15, weight: FontWeight.w700, color: AppColors.sageText),
          ),
          Text('Eventos conhecidos por forma de pagamento', style: AppText.sans(12, color: AppColors.sageMuted)),
          const SizedBox(height: 20),
          if (itens.isEmpty) Text('Sem dados no período.', style: AppText.sans(14, color: AppColors.sageText)),
          for (final i in itens.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        i.forma,
                        style: AppText.sans(14, weight: FontWeight.w500, color: AppColors.sageText),
                      ),
                    ),
                    Text(fmtPct(i.pct), style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sageText)),
                  ]),
                  const SizedBox(height: 6),
                  ProgressBar(
                    fraction: i.pct / 100,
                    height: 10,
                    color: dark ? AppColors.mint : AppColors.forest,
                    track: dark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Painel lateral com os principais destaques e volume do lote da competência.
class DespesasDestaquesCard extends StatelessWidget {
  final ContasModel c;
  const DespesasDestaquesCard(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final mh = c.composicao.isEmpty ? null : c.composicao.first;
    final itens = <(IconData, Color, Color, InlineSpan)>[
      for (final d in c.destaques)
        (
          d.variacao >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          d.variacao >= 0 ? AppColors.emerald50 : AppColors.red50,
          d.variacao >= 0 ? AppColors.emerald700 : AppColors.red600,
          TextSpan(children: [
            TextSpan(
              text: '${capitalizarDescricaoConta(d.descricao)} ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '(${d.codigo}) ${d.variacao >= 0 ? 'cresceu' : 'recuou'} ${fmtPct(d.variacao.abs())}.'),
          ]),
        ),
      if (mh != null)
        (
          LucideIcons.info,
          AppColors.sage,
          AppColors.sageText,
          TextSpan(children: [
            TextSpan(
              text: 'Pagamento ${mh.forma.toLowerCase()} ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: 'segue como ${fmtPct(mh.pct)} dos eventos médico-hospitalares.'),
          ]),
        ),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Destaques da competência', style: AppText.display(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(color: i.$2, shape: BoxShape.circle),
                    child: Icon(i.$1, size: 13, color: i.$3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text.rich(i.$4, style: AppText.sans(14, height: 1.45))),
                ],
              ),
            ),
          if (c.lote.registrosExtraidos > 0)
            Text(
              'Lote: ${fmtInt(c.lote.registrosExtraidos)} registros de ${fmtInt(c.lote.operadoras)} operadoras.',
              style: AppText.sans(12, color: AppColors.caption),
            ),
        ],
      ),
    );
  }
}
