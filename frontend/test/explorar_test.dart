import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/config/api_config.dart';
import 'package:intuitive_care_app/models/explorar_model.dart';
import 'package:intuitive_care_app/repositories/analitico_repository.dart';
import 'package:intuitive_care_app/services/analitico_service.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/viewmodels/explorar_viewmodel.dart';

Map<String, dynamic> _resposta(Map<String, String> q) => {
      'periodo': {'ano_inicio': int.parse(q['ano_inicio'] ?? '2026'), 'ano_fim': 2026, 'granularidade': q['granularidade']},
      'anos_disponiveis': [2024, 2025, 2026],
      'anos_parciais': [2026],
      'facetas': {'ufs': ['SP'], 'modalidades': ['Medicina de Grupo'], 'status': ['Ativa']},
      'kpis': {'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80.0, 'beneficiarios': 1000, 'operadoras': 1},
      'serie': [
        {'ano': 2026, 'trimestre': 1, 'despesas': 1e9, 'receitas': 1.2e9, 'sinistralidade': 83.3, 'beneficiarios': 900},
      ],
      'por_modalidade': [
        {'modalidade': 'Medicina de Grupo', 'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80, 'beneficiarios': 1000, 'operadoras': 1},
      ],
      'operadoras': [
        {'registro_ans': '326305', 'nome': 'AMIL', 'uf': 'SP', 'modalidade': 'Medicina de Grupo', 'status': 'Ativa',
          'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80, 'beneficiarios': 1000},
      ],
      'total_operadoras': 1,
      'comparativo': q['comparar'] == '1'
          ? {'ano_inicio': 2025, 'ano_fim': 2025, 'kpis': {'despesas': 1e9, 'receitas': 1e9, 'sinistralidade': 100.0, 'beneficiarios': 900, 'operadoras': 1}, 'serie': []}
          : null,
    };

void main() {
  late List<Map<String, String>> consultas;
  late ExplorarViewModel vm;

  setUp(() {
    consultas = [];
    final client = ApiClient(
      httpClient: MockClient((req) async {
        consultas.add(req.url.queryParameters);
        return http.Response.bytes(utf8.encode(jsonEncode(_resposta(req.url.queryParameters))), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    vm = ExplorarViewModel(AnaliticoRepository(AnaliticoService(client)));
  });

  test('carrega o ano mais recente e envia período, comparação e facetas', () async {
    await vm.carregar();
    expect(vm.dados!.kpis.sinistralidade, 80);
    expect(vm.intervalo, (2026, 2026));

    await vm.aplicar(vm.filtros.copyWith(modo: ModoPeriodo.ultimos, ultimos: 3, comparar: true));
    expect(consultas.last['ano_inicio'], '2024');
    expect(consultas.last['ano_fim'], '2026');
    expect(consultas.last['comparar'], '1');
    expect(vm.dados!.kpisAnteriores!.despesas, 1e9);

    await vm.aplicar(vm.filtros.copyWith(modalidades: {'Medicina de Grupo', 'Autogestão'}, ufs: {'SP'}, porte: 'grande'));
    expect(consultas.last['modalidade'], 'Autogestão,Medicina de Grupo');
    expect(consultas.last['uf'], 'SP');
    expect(consultas.last['porte'], 'grande');
    expect(vm.filtros.avancadosAtivos, 3);
    expect(vm.filtros.semAvancados().avancadosAtivos, 0);
  });

  test('intervalo invertido é corrigido antes de consultar', () async {
    await vm.carregar();
    await vm.aplicar(vm.filtros.copyWith(modo: ModoPeriodo.intervalo, anoInicio: () => 2026, anoFim: () => 2024));
    expect(consultas.last['ano_inicio'], '2024');
    expect(consultas.last['ano_fim'], '2026');
  });

  test('construtor de gráficos: adiciona, move, remove e serializa', () {
    expect(vm.graficos, GraficoConfig.padrao);
    vm.adicionarGrafico(const GraficoConfig(TipoGrafico.trendArea, Metrica.receitas));
    vm.moverGrafico(4, 0);
    expect(vm.graficos.first, const GraficoConfig(TipoGrafico.trendArea, Metrica.receitas));
    vm.removerGrafico(0);
    expect(vm.graficosJson.first, {'tipo': 'pill_bar', 'metrica': 'despesas'});
    vm.definirGraficos([for (final j in [{'tipo': 'donut_sage', 'metrica': 'beneficiarios'}, {'tipo': 'x'}]) GraficoConfig.fromJson(j)].whereType<GraficoConfig>().toList());
    expect(vm.graficos.single.tipo, TipoGrafico.donutSage);
  });

  test('API_URL colada duas vezes ou com barra final é normalizada', () {
    expect(normalizarApiUrl('https://a.vercel.app/apihttps://a.vercel.app/api'), 'https://a.vercel.app/api');
    expect(normalizarApiUrl(' https://a.vercel.app/api/ '), 'https://a.vercel.app/api');
    expect(normalizarApiUrl(''), '');
  });
}
