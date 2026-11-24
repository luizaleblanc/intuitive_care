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
import 'package:intuitive_care_app/views/register_view.dart';
import 'package:provider/provider.dart';

/// Critério 11 do MVP: Página inicial, Login, Cadastro e Reset sem overflow em 360px e 1440px,
/// fluxo de entrada sem auto-login e seleção múltipla.
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
      expect(find.text('Design System'), findsNothing);
    });

    testWidgets('Login sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const LoginView(), largura);
      ignorarFontes(tester);
      expect(find.text('Entrar'), findsWidgets);
      expect(find.text('Design System'), findsNothing);
      // Painel Forest só aparece a partir de 1024px.
      expect(
        find.textContaining('sem planilha no meio.', findRichText: true),
        largura >= 1024 ? findsOneWidget : findsNothing,
      );
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

  testWidgets('Entrada do sistema cai na página inicial e nunca faz auto-login', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final sessao = _SessaoMemoria();
    await sessao.saveToken('token-antigo-salvo');
    var chamouMe = false;
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/me')) chamouMe = true;
        return http.Response('{}', 200);
      }),
    );
    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: sessao),
    );
    await auth.initializeSession();
    expect(auth.isAuthenticated, isFalse);
    expect(chamouMe, isFalse);
    expect(await sessao.readToken(), isNull);

    final router = buildRouter(auth);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: auth, child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(router.routeInformationProvider.value.uri.path, '/inicio');
    expect(find.byType(HomeView), findsOneWidget);

    // Navegando para '/', redireciona para a página inicial.
    router.go('/');
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(router.routeInformationProvider.value.uri.path, '/inicio');
    expect(find.byType(HomeView), findsOneWidget);

    // Rota protegida sem sessão continua exigindo login.
    router.go('/painel');
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.byType(LoginView), findsOneWidget);

    // Começar agora leva para Criar conta.
    router.go('/inicio');
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(find.text('Começar agora'), findsOneWidget);
    await tester.ensureVisible(find.text('Começar agora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(router.routeInformationProvider.value.uri.path, '/criar-conta');
    expect(find.byType(RegisterView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);
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
