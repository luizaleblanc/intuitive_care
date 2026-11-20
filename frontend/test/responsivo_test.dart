import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/app/router.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/shared/ui/ui.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/views/home_view.dart';
import 'package:intuitive_care_app/views/login_view.dart';
import 'package:intuitive_care_app/views/password_reset_views.dart';
import 'package:intuitive_care_app/views/perfil_view.dart';
import 'package:intuitive_care_app/views/register_view.dart';
import 'package:provider/provider.dart';

/// Critério 11 do MVP: Página inicial e Login sem rolagem horizontal em 360px.
/// Qualquer RenderFlex overflow vira exceção e reprova o teste.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> renderizar(WidgetTester tester, Widget tela, double largura) async {
    tester.view.physicalSize = Size(largura, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = ApiClient();
    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: SessionStorageService()),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: auth, child: MaterialApp(home: tela)),
    );
    await tester.pump();
  }

  // google_fonts não tem as fontes offline: ignora só esse erro, mantendo overflow como falha.
  void ignorarFontes(WidgetTester tester) {
    final e = tester.takeException();
    if (e != null && !e.toString().contains('GoogleFonts')) throw e as Object;
  }

  for (final largura in [360.0, 1440.0]) {
    testWidgets('Página inicial sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const HomeView(), largura);
      ignorarFontes(tester);
      expect(find.text('Começar agora'), findsOneWidget);
      expect(find.text('Design System'), findsOneWidget);
    });

    testWidgets('Login sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const LoginView(), largura);
      ignorarFontes(tester);
      expect(find.text('Entrar'), findsWidgets);
      // Painel Forest só aparece a partir de 1024px.
      expect(find.textContaining('sem planilha no meio.', findRichText: true), largura >= 1024 ? findsOneWidget : findsNothing);
    });

    testWidgets('Cadastro sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const RegisterView(), largura);
      ignorarFontes(tester);
      expect(find.text('Criar conta'), findsWidgets);
      final botao = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Criar conta'));
      expect(botao.onPressed, isNull);
    });

    testWidgets('Reset de senha sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const ForgotPasswordView(), largura);
      ignorarFontes(tester);
      await renderizar(tester, const ResetPasswordView(), largura);
      ignorarFontes(tester);
      expect(find.text('Link de redefinição inválido.'), findsOneWidget);
    });
  }

  testWidgets('Começar agora leva para a tela de login (não cadastro)', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = ApiClient();
    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: SessionStorageService()),
    );
    final router = buildRouter(auth);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: auth, child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(find.text('Começar agora'), findsOneWidget);
    await tester.ensureVisible(find.text('Começar agora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(RegisterView), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('AppMultiSelect permite marcar mais de uma opção e aplicar', (tester) async {
    Set<int> selecionado = {2025};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) => Center(
              child: AppMultiSelect<int>(
                semanticLabel: 'Anos',
                selected: selecionado,
                minSelected: 1,
                options: const [(2026, '2026'), (2025, '2025'), (2024, '2024')],
                onChanged: (v) => setState(() => selecionado = v),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(selecionado, {2025, 2024});
  });

  testWidgets('PerfilView oculta exportação/alertas para Colaborador e remove botões redundantes de foto', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<AuthViewModel> logarPerfil(String perfil, List<String> permissoes) async {
      final client = ApiClient(
        httpClient: MockClient((req) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'token': 'jwt',
                'usuario': {
                  'id': 1,
                  'nome': 'Luiza Ferraz',
                  'email': 'luiza@x.com',
                  'perfil': perfil,
                  'permissoes': permissoes,
                },
              })),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      final vm = AuthViewModel(
        AuthRepository(apiClient: client, authService: AuthService(client), storageService: _SessaoMemoria()),
      );
      await vm.login(email: 'luiza@x.com', senha: '123');
      return vm;
    }

    final colab = await logarPerfil('COLABORADOR', ['painel.ver', 'perfil.editar_proprio']);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: colab,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PerfilView()))),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(find.text('Enviar foto'), findsNothing);
    expect(find.text('JPG ou PNG, até 2 MB.'), findsNothing);
    expect(find.text('Exportar como'), findsNothing);
    expect(find.text('Resumo semanal por e-mail'), findsNothing);
    expect(find.text('Avisar quando houver novos dados da ANS'), findsNothing);

    final admin = await logarPerfil('ADMIN', ['painel.ver', 'dados.exportar', 'perfil.editar_proprio']);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: admin,
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PerfilView()))),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(find.text('Enviar foto'), findsNothing);
    expect(find.text('Exportar como'), findsOneWidget);
    expect(find.text('Resumo semanal por e-mail'), findsOneWidget);
    expect(find.text('Avisar quando houver novos dados da ANS'), findsOneWidget);
  });
}

class _SessaoMemoria extends SessionStorageService {
  String? _t;
  @override
  Future<void> saveToken(String token) async => _t = token;
  @override
  Future<String?> readToken() async => _t;
  @override
  Future<void> clearToken() async => _t = null;
}
