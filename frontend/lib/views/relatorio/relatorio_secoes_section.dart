import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/relatorio_config_model.dart';
import '../../shared/ui/ui.dart';

class RelatorioSecaoContainer extends StatelessWidget {
  final String titulo;
  final String ajuda;
  final Widget child;
  final Widget? trailing;

  const RelatorioSecaoContainer({
    super.key,
    required this.titulo,
    required this.ajuda,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(titulo, style: AppText.display(14, weight: FontWeight.w700, color: AppColors.sageText))),
            ?trailing,
          ]),
          const SizedBox(height: 2),
          Text(ajuda, style: AppText.sans(12, color: AppColors.sageMuted)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class RelatorioSecoesSelector extends StatelessWidget {
  final Set<SecaoRelatorio> secoes;
  final ValueChanged<Set<SecaoRelatorio>> onChanged;

  const RelatorioSecoesSelector({
    super.key,
    required this.secoes,
    required this.onChanged,
  });

  void _alternar(SecaoRelatorio s) {
    if (secoes.contains(s) && secoes.length > 1) {
      onChanged({...secoes}..remove(s));
    } else {
      onChanged({...secoes, s});
    }
  }

  Widget _subgrupo(String titulo, List<SecaoRelatorio> itens) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: AppText.sans(10, weight: FontWeight.w700, color: AppColors.sageMuted, spacing: 0.9),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in itens)
                Tooltip(
                  message: s.descricao,
                  child: _SecaoChip(
                    rotulo: s.nome,
                    ativo: secoes.contains(s),
                    onTap: () => _alternar(s),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _atalho(String rotulo, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(rotulo, style: AppText.sans(11, weight: FontWeight.w700, color: AppColors.brandText)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return RelatorioSecaoContainer(
      titulo: 'Seções e bases ETL incluídas',
      ajuda: 'Combine visões executivas com as tabelas completas extraídas do ETL da ANS.',
      trailing: Wrap(spacing: 4, children: [
        _atalho('Só executivo', () => onChanged(Set.of(SecaoRelatorio.visoesExecutivas))),
        _atalho('Todas (8)', () => onChanged(Set.of(SecaoRelatorio.values))),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subgrupo('Visões executivas', SecaoRelatorio.visoesExecutivas),
          const SizedBox(height: 14),
          _subgrupo('Bases completas do ETL (ANS)', SecaoRelatorio.basesEtl),
        ],
      ),
    );
  }
}

class RelatorioOrdenacaoSection extends StatelessWidget {
  final OrdemRelatorio ordenarPor;
  final int? limite;
  final ValueChanged<OrdemRelatorio> onOrdenarChanged;
  final ValueChanged<int?> onLimiteChanged;

  const RelatorioOrdenacaoSection({
    super.key,
    required this.ordenarPor,
    required this.limite,
    required this.onOrdenarChanged,
    required this.onLimiteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RelatorioSecaoContainer(
      titulo: 'Ordenação e limite do ranking de operadoras',
      ajuda: 'Defina o indicador principal do ranking e quantas operadoras entram na aba consolidada.',
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        AppSelect<OrdemRelatorio>(
          semanticLabel: 'Ordenar por',
          icon: LucideIcons.arrowDownWideNarrow,
          value: ordenarPor,
          options: [for (final o in OrdemRelatorio.values) (o, 'Por ${o.nome}')],
          onChanged: onOrdenarChanged,
        ),
        AppSelect<int>(
          semanticLabel: 'Quantidade de operadoras',
          icon: LucideIcons.listOrdered,
          value: limite ?? 0,
          options: const [
            (10, 'Top 10'),
            (25, 'Top 25'),
            (50, 'Top 50'),
            (100, 'Top 100'),
            (0, 'Todas do recorte'),
          ],
          onChanged: (v) => onLimiteChanged(v == 0 ? null : v),
        ),
      ]),
    );
  }
}

class _SecaoChip extends StatelessWidget {
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  const _SecaoChip({required this.rotulo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      selected: ativo,
      button: true,
      child: Material(
        color: ativo ? AppColors.primaryBg : AppColors.card,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (ativo) ...[
                const Icon(LucideIcons.check, size: 13, color: AppColors.mint),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  rotulo,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(12, weight: FontWeight.w600, color: ativo ? Colors.white : AppColors.sageText),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
