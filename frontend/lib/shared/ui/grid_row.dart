import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Linha do grid de 12 colunas (gutter 24px).
class GridRow extends StatelessWidget {
  final List<(int, Widget)> cols;

  /// true: cards com a mesma altura (KPIs). false: alinhados pelo topo (cards de conteúdo).
  final bool mesmaAltura;
  const GridRow(this.cols, {super.key, this.mesmaAltura = true});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: mesmaAltura ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: AppLayout.gutter),
          Expanded(flex: cols[i].$1, child: cols[i].$2),
        ],
      ],
    );
    return mesmaAltura ? IntrinsicHeight(child: row) : row;
  }
}
