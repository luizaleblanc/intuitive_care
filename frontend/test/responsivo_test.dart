import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/app/router.dart';
import 'package:intuitive_care_app/app/theme.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/shared/ui/ui.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/views/app_shell.dart';
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
      expect(find.text('Design System'), findsNothing);
    });

    testWidgets('Login sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const LoginView(), largura);
      ignorarFontes(tester);
      expect(find.text('Entrar'), findsWidgets);
      expect(find.text('Design System'), findsNothing);
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
    expect(find.text('Idioma'), findsNothing);
    expect(find.text('Exportar como'), findsNothing);
    expect(find.text('Exportar planilha'), findsNothing);
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
    expect(find.text('Idioma'), findsNothing);
    expect(find.text('Exportar como'), findsOneWidget);
    expect(find.text('Exportar planilha'), findsOneWidget);
    expect(find.text('Resumo semanal por e-mail'), findsNothing);
    expect(find.text('Avisar quando houver novos dados da ANS'), findsNothing);
    expect(find.text('Sistema'), findsNothing);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
  });

  testWidgets('Tema oferece apenas Claro e Escuro e aplica dark mode imediatamente em toda a aplicação',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      AppColors.isDark = false;
      tester.view.reset();
    });

    final salvos = <Map<String, dynamic>>[];
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/me') && req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          salvos.add(body);
          final prefs = Map<String, dynamic>.from((body['preferencias'] as Map?) ?? {});
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'usuario': {
                'id': 1,
                'nome': body['nome'] ?? 'Luiza Ferraz',
                'email': body['email'] ?? 'luiza@x.com',
                'perfil': 'COLABORADOR',
                'permissoes': ['painel.ver', 'perfil.editar_proprio'],
                'preferencias': {'tema': prefs['tema'] ?? 'claro'},
              },
            })),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'token': 'jwt',
            'usuario': {
              'id': 1,
              'nome': 'Luiza Ferraz',
              'email': 'luiza@x.com',
              'perfil': 'COLABORADOR',
              'permissoes': ['painel.ver', 'perfil.editar_proprio'],
              'preferencias': {'tema': 'claro'},
            },
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: _SessaoMemoria()),
    );
    await auth.login(email: 'luiza@x.com', senha: '123');
    final theme = ThemeController(inicial: 'claro');
    final toast = ToastController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: toast),
        ],
        child: AnimatedBuilder(
          animation: theme,
          builder: (_, _) {
            AppColors.isDark = theme.isDark;
            return MaterialApp(
              theme: buildAppTheme(dark: false),
              darkTheme: buildAppTheme(dark: true),
              themeMode: theme.themeMode,
              themeAnimationDuration: Duration.zero,
              home: const Scaffold(body: SingleChildScrollView(child: PerfilView())),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(find.text('Sistema'), findsNothing);
    expect(theme.isDark, isFalse);
    expect(AppColors.isDark, isFalse);
    expect(AppColors.surface, const Color(0xFFF2F4F3));

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(theme.isDark, isTrue);
    expect(AppColors.isDark, isTrue);
    expect(AppColors.surface, const Color(0xFF0B1210));
    expect(AppColors.card, const Color(0xFF121E1A));
    expect(salvos, isNotEmpty);
    expect((salvos.last['preferencias'] as Map)['tema'], 'escuro');

    // Home e Login também renderizam em dark mode sem overflow.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: buildAppTheme(dark: false),
          darkTheme: buildAppTheme(dark: true),
          themeMode: ThemeMode.dark,
          home: const HomeView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(find.text('Começar agora'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: buildAppTheme(dark: false),
          darkTheme: buildAppTheme(dark: true),
          themeMode: ThemeMode.dark,
          home: const LoginView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorarFontes(tester);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('Logout em dark mode e novo login em conta clara mantêm tema consistente sem quebrar layout',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      AppColors.isDark = false;
      tester.view.reset();
    });

    var usuarioAtual = {
      'id': 1,
      'nome': 'Luiza Ferraz',
      'email': 'luiza@x.com',
      'perfil': 'COLABORADOR',
      'permissoes': ['painel.ver', 'perfil.editar_proprio'],
      'preferencias': {'tema': 'escuro'},
    };
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/logout')) {
          return http.Response.bytes(utf8.encode(jsonEncode({'mensagem': 'ok'})), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'token': 'jwt', 'usuario': usuarioAtual})),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: _SessaoMemoria()),
    );
    await auth.login(email: 'luiza@x.com', senha: '123');
    final theme = ThemeController(inicial: 'escuro');
    final toast = ToastController();
    final router = buildRouter(auth);
    addTearDown(router.dispose);

    auth.addListener(() {
      final u = auth.currentUser;
      if (u != null) theme.aplicar(u.preferencias.tema, persistir: false);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: toast),
          ChangeNotifierProvider(create: (_) => ShellActions()),
        ],
        child: AnimatedBuilder(
          animation: theme,
          builder: (_, _) {
            AppColors.isDark = theme.isDark;
            return MaterialApp.router(
              theme: buildAppTheme(dark: false),
              darkTheme: buildAppTheme(dark: true),
              themeMode: theme.themeMode,
              themeAnimationDuration: Duration.zero,
              routerConfig: router,
              builder: (_, child) => AppThemeScope(
                isDark: theme.isDark,
                child: ToastOverlay(controller: toast, child: child ?? const SizedBox()),
              ),
            );
          },
        ),
      ),
    );
    router.go('/perfil');
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(theme.isDark, isTrue);
    expect(AppColors.isDark, isTrue);
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar saída'));
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    // Após logout, redirecionou limpo para /login sem erro e preservando dark mode íntegro.
    expect(find.byType(LoginView), findsOneWidget);
    expect(theme.isDark, isTrue);
    expect(AppColors.isDark, isTrue);
    expect(AppColors.pageBg, const Color(0xFF0B1210));

    // Novo login em conta com tema claro: alterna atomicamente sem estado híbrido.
    usuarioAtual = {
      'id': 2,
      'nome': 'Admin',
      'email': 'admin@x.com',
      'perfil': 'ADMIN',
      'permissoes': ['painel.ver', 'perfil.editar_proprio'],
      'preferencias': {'tema': 'claro'},
    };
    await auth.login(email: 'admin@x.com', senha: '123');
    router.go('/perfil');
    await tester.pumpAndSettle();
    ignorarFontes(tester);

    expect(theme.isDark, isFalse);
    expect(AppColors.isDark, isFalse);
    expect(AppColors.surface, const Color(0xFFF2F4F3));
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
