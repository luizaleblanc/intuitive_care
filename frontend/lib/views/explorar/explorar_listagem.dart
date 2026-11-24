import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/explorar_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import 'explorar_formatters.dart';

// ---------------------------------------------------------------------------
// Listagem detalhada (ordenável, paginada)
// ---------------------------------------------------------------------------
class ListagemExplorar extends StatefulWidget {
  final ExplorarModel dados;
  const ListagemExplorar({super.key, required this.dados});

  @override
  State<ListagemExplorar> createState() => _ListagemExplorarState();
}

class _ListagemExplorarState extends State<ListagemExplorar> {
  static const _porPagina = 15;
  Metrica _ordem = Metrica.despesas;
  bool _desc = true;
  int _pagina = 0;

  @override
  void didUpdateWidget(covariant ListagemExplorar old) {
    super.didUpdateWidget(old);
    if (old.dados != widget.dados) _pagina = 0;
  }

  void _ordenar(Metrica m) => setState(() {
        _desc = _ordem == m ? !_desc : true;
        _ordem = m;
        _pagina = 0;
      });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final itens = [...widget.dados.operadoras]..sort((a, b) {
        final c = (a.valores.de(_ordem) ?? -1).compareTo(b.valores.de(_ordem) ?? -1);
        return _desc ? -c : c;
      });
    final paginas = (itens.length / _porPagina).ceil().clamp(1, 1 << 20);
    final pagina = itens.skip(_pagina * _porPagina).take(_porPagina).toList();

    Widget cabecalho(String t, {Metrica? m, int flex = 2, bool direita = true}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: m == null ? null : () => _ordenar(m),
            child: Row(
              mainAxisAlignment: direita ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(child: Text(t.toUpperCase(), overflow: TextOverflow.ellipsis, style: AppText.eyebrow())),
                if (m != null && m == _ordem)
                  Icon(_desc ? LucideIcons.arrowDown : LucideIcons.arrowUp, size: 12, color: AppColors.brandText),
              ],
            ),
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            'Operadoras no recorte',
            subtitle: '${fmtInt(widget.dados.totalOperadoras)} operadoras · clique no título de uma coluna para ordenar',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              cabecalho('Operadora', flex: 5, direita: false),
              cabecalho('UF', flex: 1, direita: false),
              cabecalho('Modalidade', flex: 3, direita: false),
              cabecalho('Despesas', m: Metrica.despesas),
              cabecalho('Receitas', m: Metrica.receitas),
              cabecalho('Sinistr.', m: Metrica.sinistralidade),
              cabecalho('Benef.', m: Metrica.beneficiarios),
            ]),
          ),
          Divider(height: 1, color: AppColors.slate200),
          if (pagina.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Nenhuma operadora com esses filtros. Remova algum filtro para ampliar o recorte.',
                    style: AppText.sans(14, color: AppColors.muted)),
              ),
            ),
          for (final o in pagina)
            InkWell(
              onTap: () => context.go('/operadoras?q=${o.registroAns}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nomeProprio(o.nome),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w600)),
                      Text('Reg. ANS ${o.registroAns}${o.status == 'Inativa' ? ' · Inativa' : ''}',
                          style: AppText.numeric(11, weight: FontWeight.w400, color: AppColors.muted)),
                    ]),
                  ),
                  Expanded(flex: 1, child: Text(o.uf ?? '—', style: AppText.sans(13))),
                  Expanded(
                    flex: 3,
                    child: Text(o.modalidade, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13)),
                  ),
                  for (final m in Metrica.values)
                    Expanded(
                      flex: 2,
                      child: Text(fmtMetrica(m, o.valores.de(m)),
                          textAlign: TextAlign.right, style: AppText.numeric(13, weight: FontWeight.w500)),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Text('Página ${_pagina + 1} de $paginas', style: AppText.numeric(12, weight: FontWeight.w500, color: AppColors.muted)),
            const Spacer(),
            AppIconButton(
              icon: LucideIcons.chevronLeft,
              label: 'Página anterior',
              size: 32,
              onPressed: _pagina == 0 ? null : () => setState(() => _pagina--),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: LucideIcons.chevronRight,
              label: 'Próxima página',
              size: 32,
              onPressed: _pagina >= paginas - 1 ? null : () => setState(() => _pagina++),
            ),
          ]),
          if (widget.dados.granularidade == 'ano' && widget.dados.anosParciais.any((a) => a >= widget.dados.anoInicio && a <= widget.dados.anoFim)) ...[
            const SizedBox(height: 8),
            Text('* Ano com trimestres ainda não publicados pela ANS: valores anuais parciais.',
                style: AppText.sans(12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
