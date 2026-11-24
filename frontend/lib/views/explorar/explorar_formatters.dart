import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/explorar_model.dart';
import '../../shared/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Formatação por métrica e período (sempre algarismos tabulares na tela)
// ---------------------------------------------------------------------------
String fmtMetrica(Metrica m, double? v) {
  if (v == null) return '—';
  return switch (m) {
    Metrica.despesas || Metrica.receitas => v.abs() >= 1e9 ? fmtBi(v) : 'R\$ ${fmtDec1(v / 1e6)} mi',
    Metrica.sinistralidade => fmtPct(v),
    Metrica.beneficiarios => fmtMi(v),
  };
}

/// Divisor e unidade para os eixos dos gráficos.
(double, String) escalaMetrica(Metrica m, double maximo) => switch (m) {
      Metrica.despesas || Metrica.receitas => maximo >= 1e9 ? (1e9, 'bi') : (1e6, 'mi'),
      Metrica.sinistralidade => (1, '%'),
      Metrica.beneficiarios => maximo >= 1e6 ? (1e6, 'mi') : (1e3, 'mil'),
    };

bool combinacaoValida(TipoGrafico t, Metrica m) => !(t == TipoGrafico.donutSage && m == Metrica.sinistralidade);

IconData iconeTipo(TipoGrafico t) => switch (t) {
      TipoGrafico.pillBar => LucideIcons.chartColumnBig,
      TipoGrafico.donutSage => LucideIcons.chartPie,
      TipoGrafico.trendArea => LucideIcons.chartLine,
      TipoGrafico.horizontalRanking => LucideIcons.chartBarBig,
    };

String rotuloAnosExplorar(List<int> anos, int ini, int fim) {
  final contiguo = anos.isEmpty || anos.length == fim - ini + 1;
  if (ini == fim) return '$ini';
  return contiguo ? '$ini–$fim' : anos.join(', ');
}

String rotuloPeriodoExplorar(ExplorarModel d) {
  final base = rotuloAnosExplorar(d.anos, d.anoInicio, d.anoFim);
  if (d.trimestres.isEmpty || d.trimestres.length == 4) return base;
  return '$base · ${fmtTrimestres(d.trimestres)}';
}

String rotuloPontoExplorar(ExplorarModel d, PontoSerie p) => p.trimestre == null
    ? '${p.ano}${d.anosParciais.contains(p.ano) ? '*' : ''}'
    : fmtPeriodoCurto(p.ano, p.trimestre!);
