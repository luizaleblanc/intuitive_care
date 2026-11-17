import 'package:flutter/material.dart';

import '../models/estatistica_model.dart';
import 'currency_formatter.dart';

/// Gráfico de barras horizontal nativo em Flutter para o Top 5 UFs.
class UfBarChart extends StatelessWidget {
  final List<UfEstatistica> items;

  const UfBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sem dados agregados por UF disponíveis.'),
      );
    }

    final maxTotal = items.map((e) => e.total).reduce((a, b) => a > b ? a : b);

    return Column(
      children: items.map((item) {
        final ratio = maxTotal > 0 ? (item.total / maxTotal).clamp(0.05, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.uf} (${item.qtdOperadoras} op.)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    CurrencyFormatter.formatCompactBrl(item.total),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
