import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/explorar_model.dart';
import '../../shared/charts/charts.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/explorar_viewmodel.dart';
import 'explorar_formatters.dart';

// ---------------------------------------------------------------------------
// KPIs reativos (com variação quando a comparação está ligada)
// ---------------------------------------------------------------------------
class KpisExplorar extends StatelessWidget {
  final ExplorarModel dados;
  final bool comparar;
  const KpisExplorar({super.key, required this.dados, required this.comparar});

  @override
  Widget build(BuildContext context) {
    final ant = dados.kpisAnteriores;
    final periodoAnt = dados.periodoAnterior;
    final foot = !comparar
        ? 'Período ${rotuloPeriodoExplorar(dados)}'
        : ant == null
            ? 'Sem dados no período anterior'
            : 'vs ${rotuloAnosExplorar(dados.anosAnteriores, periodoAnt!.$1, periodoAnt.$2)}';
    double? delta(Metrica m) => comparar && ant != null ? variation(dados.kpis.de(m), ant.de(m)) : null;
    return GridRow([
      (3, KpiCard(dark: true, label: 'Despesas assistenciais', value: fmtMetrica(Metrica.despesas, dados.kpis.despesas),
          delta: delta(Metrica.despesas), foot: foot, icon: LucideIcons.wallet)),
      (3, KpiCard(label: 'Receitas (contraprestações)', value: fmtMetrica(Metrica.receitas, dados.kpis.receitas),
          delta: delta(Metrica.receitas), foot: foot, icon: LucideIcons.trendingUp)),
      (3, KpiCard(label: 'Sinistralidade do recorte', value: fmtMetrica(Metrica.sinistralidade, dados.kpis.sinistralidade),
          delta: delta(Metrica.sinistralidade), foot: foot, icon: LucideIcons.activity)),
      (3, KpiCard(label: 'Beneficiários', value: fmtMetrica(Metrica.beneficiarios, dados.kpis.beneficiarios),
          delta: delta(Metrica.beneficiarios), foot: '${fmtInt(dados.totalOperadoras)} operadoras no recorte',
          icon: LucideIcons.users)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Grade de gráficos escolhidos pelo usuário (2 por linha)
// ---------------------------------------------------------------------------
class GradeGraficosExplorar extends StatelessWidget {
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  final VoidCallback onPersonalizar;
  final ValueChanged<int> onEditarGrafico;

  const GradeGraficosExplorar({
    super.key,
    required this.vm,
    required this.dados,
    required this.onPersonalizar,
    required this.onEditarGrafico,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final graficos = vm.graficos;
    if (graficos.isEmpty) {
      return AppCard(
        child: Column(children: [
          Icon(LucideIcons.chartNoAxesCombined, size: 28, color: AppColors.brandText),
          const SizedBox(height: 8),
          Text('Nenhum gráfico na tela', style: AppText.cardTitle()),
          const SizedBox(height: 4),
          Text('Escolha os gráficos e as métricas que quer acompanhar.', style: AppText.sans(14, color: AppColors.muted)),
          const SizedBox(height: 16),
          AppButton('Personalizar gráficos', icon: LucideIcons.plus, onPressed: onPersonalizar),
        ]),
      );
    }
    final linhas = <Widget>[];
    for (var i = 0; i < graficos.length; i += 2) {
      if (i > 0) linhas.add(const SizedBox(height: AppLayout.gutter));
      linhas.add(GridRow([
        (6, _CartaoGrafico(
          indice: i,
          config: graficos[i],
          vm: vm,
          dados: dados,
          onEditar: () => onEditarGrafico(i),
        )),
        (6, i + 1 < graficos.length
            ? _CartaoGrafico(
                indice: i + 1,
                config: graficos[i + 1],
                vm: vm,
                dados: dados,
                onEditar: () => onEditarGrafico(i + 1),
              )
            : const SizedBox.shrink()),
      ], mesmaAltura: false));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas);
  }
}

class _CartaoGrafico extends StatelessWidget {
  final int indice;
  final GraficoConfig config;
  final ExplorarViewModel vm;
  final ExplorarModel dados;
  final VoidCallback onEditar;

  const _CartaoGrafico({
    required this.indice,
    required this.config,
    required this.vm,
    required this.dados,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final sage = config.tipo == TipoGrafico.donutSage;
    final cor = sage ? AppColors.sageText : AppColors.ink;
    return AppCard(
      color: sage ? AppColors.sage : AppColors.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            '${config.metrica.nome} · ${_subtitulo()}',
            subtitle: '${config.tipo.nome} · ${config.metrica.descricao}',
            size: 15,
            color: cor,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconButton(
                icon: LucideIcons.pencil,
                label: 'Editar gráfico',
                size: 32,
                onPressed: onEditar,
              ),
              const SizedBox(width: 4),
              AppIconButton(
                icon: LucideIcons.x,
                label: 'Remover gráfico',
                size: 32,
                onPressed: () => vm.removerGrafico(indice),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _corpo(context),
        ],
      ),
    );
  }

  String _subtitulo() => switch (config.tipo) {
        TipoGrafico.donutSage => 'por modalidade',
        TipoGrafico.horizontalRanking => 'top operadoras',
        _ => dados.granularidade == 'ano' ? 'por ano' : 'por trimestre',
      };

  Widget _corpo(BuildContext context) {
    final m = config.metrica;
    switch (config.tipo) {
      case TipoGrafico.pillBar:
      case TipoGrafico.trendArea:
        final valores = [for (final p in dados.serie) p.valores.de(m) ?? 0];
        final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);
        final (div, unidade) = escalaMetrica(m, maximo);
        final serie = [
          for (final p in dados.serie) BarDatum(rotuloPontoExplorar(dados, p), (p.valores.de(m) ?? 0) / div),
        ];
        if (config.tipo == TipoGrafico.pillBar) {
          return PillBarChart(data: serie.length > 12 ? serie.sublist(serie.length - 12) : serie, height: 240, unit: unidade);
        }
        return TrendAreaChart(
          data: serie,
          unit: unidade,
          comparacao: [
            for (final p in dados.serieAnterior) BarDatum(rotuloPontoExplorar(dados, p), (p.valores.de(m) ?? 0) / div),
          ],
        );
      case TipoGrafico.donutSage:
        final total = dados.porModalidade.fold<double>(0, (s, x) => s + (x.valores.de(m) ?? 0));
        if (total <= 0) {
          return Text('Sem dados para o recorte.', style: AppText.sans(14, color: AppColors.sageText));
        }
        final top = dados.porModalidade.take(5).toList();
        final resto = dados.porModalidade.skip(5).fold<double>(0, (s, x) => s + (x.valores.de(m) ?? 0));
        final fatias = [
          for (var i = 0; i < top.length; i++)
            DonutSlice(top[i].modalidade, (top[i].valores.de(m) ?? 0) / total * 100, AppColors.chart[i]),
          if (resto > 0) DonutSlice('Outras modalidades', resto / total * 100, AppColors.chart[5]),
        ];
        return Row(
          children: [
            Donut(data: fatias, center: fmtInt(dados.totalOperadoras), sub: 'operadoras'),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (final f in fatias)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: f.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(12, color: AppColors.sageText)),
                        ),
                        Text(fmtPct(f.pct), style: AppText.numeric(12, color: AppColors.sageText)),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        );
      case TipoGrafico.horizontalRanking:
        final candidatos = dados.operadoras.where((o) {
          final v = o.valores.de(m);
          // Sinistralidade só faz sentido com receita relevante (evita razões de base mínima).
          return v != null && (m != Metrica.sinistralidade || o.valores.receitas >= 1e6);
        }).toList()
          ..sort((a, b) => (b.valores.de(m) ?? 0).compareTo(a.valores.de(m) ?? 0));
        final top = candidatos.take(8).toList();
        return HorizontalRanking(
          itens: [
            for (final o in top)
              ItemRanking(nomeProprio(o.nome), o.valores.de(m) ?? 0, fmtMetrica(m, o.valores.de(m)),
                  detalhe: '${o.modalidade}${o.uf == null ? '' : ' · ${o.uf}'}'),
          ],
          onTap: (i) => context.go('/operadoras?q=${top[i].registroAns}'),
        );
    }
  }
}
