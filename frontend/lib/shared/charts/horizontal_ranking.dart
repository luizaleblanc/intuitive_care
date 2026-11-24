import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'progress_bar.dart';

/// Linha de dados exibida no ranking horizontal.
class ItemRanking {
  final String rotulo;
  final String? detalhe;
  final double valor;
  final String valorFormatado;
  const ItemRanking(this.rotulo, this.valor, this.valorFormatado, {this.detalhe});
}

/// Ranking horizontal: posição, nome, barra destacada no 1º e Mint nos demais, valor tabular.
class HorizontalRanking extends StatelessWidget {
  final List<ItemRanking> itens;
  final ValueChanged<int>? onTap;
  const HorizontalRanking({super.key, required this.itens, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
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
                      color: i == 0 ? (dark ? AppColors.lime : AppColors.forest) : AppColors.mint,
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
