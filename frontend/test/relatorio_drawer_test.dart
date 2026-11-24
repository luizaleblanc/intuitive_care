import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/app/theme.dart';
import 'package:intuitive_care_app/repositories/analitico_repository.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/services/analitico_service.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/shared/ui/ui.dart';
import 'package:intuitive_care_app/shared/utils/exporter.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/viewmodels/explorar_viewmodel.dart';
import 'package:intuitive_care_app/views/relatorio_drawer.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _explorarMock() => {
      'periodo': {'ano_inicio': 2025, 'ano_fim': 2025, 'anos': [2025], 'granularidade': 'ano'},
      'anos_disponiveis': [2023, 2024, 2025],
      'anos_parciais': [],
      'facetas': {
        'ufs': ['PB', 'RJ', 'SP'],
        'modalidades': ['Cooperativa Médica', 'Medicina de Grupo'],
        'status': ['Ativa', 'Inativa'],
      },
      'kpis': {'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80.0, 'beneficiarios': 100000, 'operadoras': 2},
      'serie': [
        {'ano': 2025, 'trimestre': null, 'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80.0, 'beneficiarios': 100000},
      ],
      'por_modalidade': [
        {'modalidade': 'Medicina de Grupo', 'despesas': 2e9, 'receitas': 2.5e9, 'sinistralidade': 80.0, 'beneficiarios': 100000, 'operadoras': 2},
      ],
      'operadoras': [
        {
          'registro_ans': '326305',
          'nome': 'AMIL',
          'uf': 'SP',
          'modalidade': 'Medicina de Grupo',
          'status': 'Ativa',
          'despesas': 2e9,
          'receitas': 2.5e9,
          'sinistralidade': 80.0,
          'beneficiarios': 100000,
        },
      ],
      'total_operadoras': 2,
      'comparativo': null,
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void ignorarFontes(WidgetTester tester) {
    final e = tester.takeException();
    if (e != null && !e.toString().contains('GoogleFonts')) throw e as Object;
  }

  Future<ToastController> pumpDrawer(
    WidgetTester tester, {
    required Future<http.Response> Function(Map<String, dynamic> payload) onExportar,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(580, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AppColors.isDark = dark;
    addTearDown(() => AppColors.isDark = false);

    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/relatorios/exportar')) {
          return onExportar(jsonDecode(req.body) as Map<String, dynamic>);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode(_explorarMock())),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: SessionStorageService()),
    );
    final explorar = ExplorarViewModel(AnaliticoRepository(AnaliticoService(client)));
    final toast = ToastController();
    addTearDown(() {
      toast.dispose();
      explorar.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: explorar),
          ChangeNotifierProvider.value(value: toast),
        ],
        child: MaterialApp(
          theme: buildAppTheme(dark: false),
          darkTheme: buildAppTheme(dark: true),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(body: RelatorioDrawer()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    return toast;
  }

  group('RelatorioDrawer UI (claro e escuro, sem overflow e fluxo de exportação)', () {
    for (final dark in [false, true]) {
      testWidgets('renderiza todas as 8 seções sem overflow no modo ${dark ? "escuro" : "claro"}', (tester) async {
        Map<String, dynamic>? ultimoPayload;
        await pumpDrawer(
          tester,
          dark: dark,
          onExportar: (payload) async {
            ultimoPayload = payload;
            return http.Response.bytes(
              Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]),
              200,
              headers: {
                'content-type': Exporter.mimeXlsx,
                'content-disposition': 'attachment; filename="relatorio_etl_ans_2025.xlsx"',
              },
            );
          },
        );

        expect(find.text('Exportar relatório ETL (ANS)'), findsOneWidget);
        expect(find.text('VISÕES EXECUTIVAS'), findsOneWidget);
        expect(find.text('BASES COMPLETAS DO ETL (ANS)'), findsOneWidget);
        for (final s in SecaoRelatorio.values) {
          expect(find.text(s.nome), findsOneWidget);
        }

        // Aciona o botão de exportação XLSX e valida payload enviado para /api/relatorios/exportar
        await tester.tap(find.widgetWithText(AppButton, 'Exportar planilha'));
        await tester.pumpAndSettle();
        ignorarFontes(tester);

        expect(ultimoPayload, isNotNull);
        expect(ultimoPayload!['formato'], 'XLSX');
        expect(ultimoPayload!['anos'], [2025]);
        expect(ultimoPayload!['secoes'], [for (final s in SecaoRelatorio.values) s.codigo]);
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('fluxo PDF solicita formato JSON a /relatorios/exportar e gera PDF', (tester) async {
      Map<String, dynamic>? payloadPdf;
      final toast = await pumpDrawer(
        tester,
        onExportar: (payload) async {
          payloadPdf = payload;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'titulo_geral': 'Relatório Analítico ANS · Intuitive Care',
              'subtitulo_geral': 'Período 2025',
              'nome_base': 'relatorio_etl_ans_2025',
              'abas': [
                {
                  'titulo': 'Resumo Executivo',
                  'colunas': ['Indicador', 'Valor'],
                  'linhas': [
                    ['Operadoras', '2'],
                  ],
                },
              ],
            })),
            200,
            headers: {'content-type': 'application/json'},
          );
        },
      );

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Exportar PDF'));
      await tester.pumpAndSettle();
      ignorarFontes(tester);

      expect(payloadPdf, isNotNull);
      expect(payloadPdf!['formato'], 'JSON');
      expect(toast.message, contains('relatorio_etl_ans_2025.pdf'));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
