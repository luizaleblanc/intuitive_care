import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/operadora_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';

class OperadorasTabela extends StatelessWidget {
  final List<OperadoraModel> itens;
  final bool isAdmin;
  final bool loading;
  final String busca;
  final void Function(OperadoraModel) onTap;

  const OperadorasTabela({
    super.key,
    required this.itens,
    required this.isAdmin,
    required this.loading,
    required this.busca,
    required this.onTap,
  });

  static const _flex = [12, 30, 17, 16, 5, 12, 11, 11];

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    Widget th(String t, int i, {TextAlign align = TextAlign.left}) => Expanded(
          flex: _flex[i],
          child: Text(t.toUpperCase(),
              textAlign: align,
              style: AppText.sans(11, weight: FontWeight.w700, color: Colors.white, spacing: 11 * 0.05)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primaryBg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            th('Registro ANS', 0),
            th('Operadora', 1),
            th('CNPJ', 2),
            th('Modalidade', 3),
            th('UF', 4),
            th('Beneficiários', 5, align: TextAlign.right),
            th('   Status', 6),
            th('', 7),
          ]),
        ),
        if (loading && itens.isEmpty) const LoadingBlock(height: 200, label: 'Carregando operadoras...'),
        if (!loading && itens.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: Text(
              busca.isEmpty ? 'Nenhuma operadora encontrada.' : 'Nenhuma operadora encontrada para "$busca".',
              textAlign: TextAlign.center,
              style: AppText.sans(14, color: AppColors.muted),
            ),
          ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: loading ? 0.5 : 1,
          child: Column(
            children: [
              for (final o in itens) _LinhaOperadora(op: o, isAdmin: isAdmin, flex: _flex, onTap: () => onTap(o)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinhaOperadora extends StatefulWidget {
  final OperadoraModel op;
  final bool isAdmin;
  final List<int> flex;
  final VoidCallback onTap;
  const _LinhaOperadora({required this.op, required this.isAdmin, required this.flex, required this.onTap});

  @override
  State<_LinhaOperadora> createState() => _LinhaOperadoraState();
}

class _LinhaOperadoraState extends State<_LinhaOperadora> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final o = widget.op;
    final f = widget.flex;
    return Semantics(
      button: true,
      label: '${o.nomeExibicao}, registro ${o.registroAns}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _hover ? AppColors.cardHover : AppColors.card,
              border: Border(top: BorderSide(color: AppColors.slate100)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(flex: f[0], child: Text(o.registroAns, style: AppText.mono(14))),
                Expanded(
                  flex: f[1],
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nomeProprio(o.nomeExibicao),
                            overflow: TextOverflow.ellipsis, style: AppText.sans(14, weight: FontWeight.w600)),
                        Text(o.razaoSocial,
                            overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: f[2],
                  child: Text(fmtCnpj(o.cnpj),
                      style: AppText.mono(12, weight: FontWeight.w400, color: AppColors.slate600)),
                ),
                Expanded(
                    flex: f[3],
                    child: Align(alignment: Alignment.centerLeft, child: ModalidadePill(o.modalidade))),
                Expanded(flex: f[4], child: Text(o.uf, style: AppText.sans(14, weight: FontWeight.w600))),
                Expanded(
                  flex: f[5],
                  child: Text(fmtInt(o.beneficiarios),
                      textAlign: TextAlign.right, style: AppText.sans(14, weight: FontWeight.w600)),
                ),
                Expanded(
                  flex: f[6],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Align(alignment: Alignment.centerLeft, child: StatusPill(o.status)),
                  ),
                ),
                Expanded(
                  flex: f[7],
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hover ? AppColors.sage : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.isAdmin ? LucideIcons.pencil : LucideIcons.eye,
                              size: 13, color: AppColors.brandText),
                          const SizedBox(width: 4),
                          Text(widget.isAdmin ? 'Gerenciar' : 'Detalhes',
                              style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.brandText)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
