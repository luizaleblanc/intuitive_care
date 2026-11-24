import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/explorar_model.dart';
import '../../shared/ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/explorar_viewmodel.dart';
import 'explorar_controles.dart';
import 'explorar_formatters.dart';

// ---------------------------------------------------------------------------
// Drawer: construtor de gráficos (tipo × métrica)
// ---------------------------------------------------------------------------
void abrirConstrutorGrafico(BuildContext context, ExplorarViewModel vm, {int? editar}) {
  showSideDrawer<void>(context, width: 520, builder: (_) => _Construtor(vm: vm, editar: editar));
}

class _Construtor extends StatefulWidget {
  final ExplorarViewModel vm;
  final int? editar;
  const _Construtor({required this.vm, this.editar});

  @override
  State<_Construtor> createState() => _ConstrutorState();
}

class _ConstrutorState extends State<_Construtor> {
  late final List<GraficoConfig> _lista = List.of(widget.vm.graficos);
  late int? _selecionado = widget.editar ?? (_lista.isEmpty ? null : 0);
  late TipoGrafico _tipo = _selecionado == null ? TipoGrafico.pillBar : _lista[_selecionado!].tipo;
  late Metrica _metrica = _selecionado == null ? Metrica.despesas : _lista[_selecionado!].metrica;
  bool _salvando = false;

  void _selecionar(int? i) => setState(() {
        _selecionado = i;
        if (i != null) {
          _tipo = _lista[i].tipo;
          _metrica = _lista[i].metrica;
        }
      });

  void _atualizar({TipoGrafico? tipo, Metrica? metrica}) => setState(() {
        _tipo = tipo ?? _tipo;
        _metrica = metrica ?? _metrica;
        if (!combinacaoValida(_tipo, _metrica)) _metrica = Metrica.despesas;
        if (_selecionado != null) _lista[_selecionado!] = GraficoConfig(_tipo, _metrica);
      });

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final vm = widget.vm;
    final auth = context.read<AuthViewModel>();
    final toast = context.read<ToastController>();
    vm.definirGraficos(_lista);
    if (_lista.isEmpty) {
      while (vm.graficos.isNotEmpty) {
        vm.removerGrafico(0);
      }
    }
    final ok = await auth.updateProfile({'preferencias': {'graficos_explorar': vm.graficosJson}});
    if (!mounted) return;
    toast.show(ok ? 'Gráficos salvos no seu perfil' : 'Gráficos aplicados (não foi possível salvar no perfil)',
        error: !ok);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      color: AppColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
            child: Row(children: [
              Expanded(child: Text('Personalizar gráficos', style: AppText.display(20, color: AppColors.sageText))),
              AppIconButton(icon: LucideIcons.x, label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Escolha o tipo de gráfico e a métrica. O layout fica salvo no seu perfil (até 8 gráficos).',
                style: AppText.sans(13, color: AppColors.sageMuted)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('NA TELA', style: AppText.eyebrow(color: AppColors.sageText)),
                const SizedBox(height: 8),
                for (var i = 0; i < _lista.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: _selecionado == i ? AppColors.card : AppColors.card.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _selecionar(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _selecionado == i ? AppColors.brandText : Colors.transparent, width: 1.5),
                          ),
                          child: Row(children: [
                            Icon(iconeTipo(_lista[i].tipo), size: 18, color: AppColors.brandText),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${_lista[i].metrica.nome} · ${_lista[i].tipo.nome}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(13, weight: FontWeight.w600)),
                            ),
                            AppIconButton(
                              icon: LucideIcons.arrowUp,
                              label: 'Mover para cima',
                              size: 28,
                              onPressed: i == 0
                                  ? null
                                  : () => setState(() {
                                        _lista.insert(i - 1, _lista.removeAt(i));
                                        _selecionado = i - 1;
                                      }),
                            ),
                            AppIconButton(
                              icon: LucideIcons.trash2,
                              label: 'Remover',
                              size: 28,
                              onPressed: () => setState(() {
                                _lista.removeAt(i);
                                _selecionado = _lista.isEmpty ? null : 0;
                              }),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    'Adicionar gráfico',
                    icon: LucideIcons.plus,
                    variant: ButtonVariant.secondary,
                    size: ButtonSize.sm,
                    onPressed: _lista.length >= 8
                        ? null
                        : () => setState(() {
                              _lista.add(GraficoConfig(_tipo, _metrica));
                              _selecionado = _lista.length - 1;
                            }),
                  ),
                ),
                if (_selecionado != null) ...[
                  const SizedBox(height: 24),
                  Text('TIPO DE GRÁFICO', style: AppText.eyebrow(color: AppColors.sageText)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.3,
                    children: [
                      for (final t in TipoGrafico.values)
                        _OpcaoTipo(tipo: t, ativo: _tipo == t, onTap: () => _atualizar(tipo: t)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('MÉTRICA', style: AppText.eyebrow(color: AppColors.sageText)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in Metrica.values)
                      Opacity(
                        opacity: combinacaoValida(_tipo, m) ? 1 : 0.4,
                        child: ExplorarChip(
                          rotulo: m.nome,
                          ativo: _metrica == m,
                          onTap: () {
                            if (combinacaoValida(_tipo, m)) _atualizar(metrica: m);
                          },
                        ),
                      ),
                  ]),
                  if (_tipo == TipoGrafico.donutSage) ...[
                    const SizedBox(height: 8),
                    Text('Sinistralidade é uma razão e não se soma entre modalidades, por isso não entra na rosca.',
                        style: AppText.sans(12, color: AppColors.sageMuted)),
                  ],
                ],
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
              AppButton('Restaurar padrão',
                  variant: ButtonVariant.ghost,
                  onPressed: () => setState(() {
                        _lista
                          ..clear()
                          ..addAll(GraficoConfig.padrao);
                        _selecionar(0);
                      })),
              const Spacer(),
              AppButton('Aplicar', icon: LucideIcons.check, loading: _salvando, onPressed: _salvar),
            ]),
          ),
        ],
      ),
    );
  }
}

class _OpcaoTipo extends StatelessWidget {
  final TipoGrafico tipo;
  final bool ativo;
  final VoidCallback onTap;
  const _OpcaoTipo({required this.tipo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      selected: ativo,
      button: true,
      child: Material(
        color: ativo ? AppColors.primaryBg : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(iconeTipo(tipo), size: 20, color: ativo ? AppColors.mint : AppColors.brandText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipo.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(12, weight: FontWeight.w700, color: ativo ? Colors.white : AppColors.ink)),
                    Text(tipo.usoIdeal,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(11, color: ativo ? Colors.white70 : AppColors.muted)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
