import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/explorar_model.dart';
import '../../shared/ui/ui.dart';
import '../../viewmodels/explorar_viewmodel.dart';
import 'explorar_controles.dart';

// ---------------------------------------------------------------------------
// Drawer: filtros avançados com facetas reais do dataset
// ---------------------------------------------------------------------------
void abrirFiltrosExplorar(BuildContext context, ExplorarViewModel vm, ExplorarModel dados) {
  showSideDrawer<void>(context, width: 480, builder: (_) => _PainelFiltros(vm: vm, facetas: dados.facetas));
}

Set<String> _alternar(Set<String> atual, String v) => atual.contains(v) ? ({...atual}..remove(v)) : {...atual, v};

class _PainelFiltros extends StatefulWidget {
  final ExplorarViewModel vm;
  final Facetas facetas;
  const _PainelFiltros({required this.vm, required this.facetas});

  @override
  State<_PainelFiltros> createState() => _PainelFiltrosState();
}

class _PainelFiltrosState extends State<_PainelFiltros> {
  late FiltrosExplorar _f = widget.vm.filtros;

  Widget _secao(String titulo, String ajuda, Widget conteudo) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sageText)),
          const SizedBox(height: 2),
          Text(ajuda, style: AppText.sans(12, color: AppColors.sageMuted)),
          const SizedBox(height: 10),
          conteudo,
        ]),
      );

  Widget _chips(List<(String, String)> opcoes, bool Function(String) ativo, void Function(String) alternar) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (valor, rotulo) in opcoes)
            ExplorarChip(rotulo: rotulo, ativo: ativo(valor), onTap: () => setState(() => alternar(valor))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final fac = widget.facetas;
    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
            child: Row(children: [
              Expanded(child: Text('Filtros avançados', style: AppText.display(20, color: AppColors.sageText))),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _secao('Modalidade da operadora', 'Selecione uma ou mais.', _chips(
                  [for (final m in fac.modalidades) (m, m)],
                  _f.modalidades.contains,
                  (m) => _f = _f.copyWith(modalidades: _alternar(_f.modalidades, m)),
                )),
                _secao('UF / Região', 'Estado da sede da operadora.', _chips(
                  [for (final u in fac.ufs) (u, u)],
                  _f.ufs.contains,
                  (u) => _f = _f.copyWith(ufs: _alternar(_f.ufs, u)),
                )),
                _secao('Porte (faixa de beneficiários)', 'Classificação da ANS. Selecione um ou mais.', _chips(
                  [for (final e in rotulosPorte.entries) (e.key, '${e.value} · ${descricoesPorte[e.key]}')],
                  _f.portes.contains,
                  (v) => _f = _f.copyWith(portes: _alternar(_f.portes, v)),
                )),
                _secao('Faixa de despesa no período', 'Soma das despesas da operadora no recorte. Selecione uma ou mais.',
                    _chips(
                  [for (final e in rotulosFaixa.entries) (e.key, e.value)],
                  _f.faixas.contains,
                  (v) => _f = _f.copyWith(faixas: _alternar(_f.faixas, v)),
                )),
                _secao('Status de consolidação', 'Trimestres com lote auditado ou pendente. Selecione um ou ambos.', _chips(
                  [for (final e in rotulosConsolidacao.entries) (e.key, e.value)],
                  _f.consolidacoes.contains,
                  (v) => _f = _f.copyWith(consolidacoes: _alternar(_f.consolidacoes, v)),
                )),
                if (fac.status.length > 1)
                  _secao('Status da operadora', 'Visível apenas para Administrador. Selecione um ou mais.', _chips(
                    [for (final s in fac.status) (s, s)],
                    _f.statuses.contains,
                    (v) => _f = _f.copyWith(statuses: _alternar(_f.statuses, v)),
                  )),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              AppButton('Limpar', variant: ButtonVariant.ghost, onPressed: () => setState(() => _f = _f.semAvancados())),
              const Spacer(),
              AppButton('Aplicar filtros', icon: LucideIcons.check, onPressed: () {
                widget.vm.aplicar(_f);
                Navigator.of(context).pop();
              }),
            ]),
          ),
        ],
      ),
    );
  }
}
