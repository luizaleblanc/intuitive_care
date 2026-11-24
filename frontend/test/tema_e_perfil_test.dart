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
import 'package:intuitive_care_app/views/perfil_view.dart';
import 'package:provider/provider.dart';

/// Testes de permissões visíveis no Perfil, alternância Claro/Escuro e consistência pós-logout.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // google_fonts não tem as fontes offline: ignora só esse erro, mantendo overflow como falha.
  void ignorarFontes(WidgetTester tester) {
    final e = tester.takeException();
    if (e != null && !e.toString().contains('GoogleFonts')) throw e as Object;
  }

  http.Response jsonOk(Map<String, dynamic> body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

  AuthViewModel criarAuth(MockClient mock) {
    final client = ApiClient(httpClient: mock);
    return AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: _SessaoMemoria()),
    );
  }

  Future<void> pumpComTema(
    WidgetTester tester, {
    required AuthViewModel auth,
    required ThemeController theme,
    required ToastController toast,
    RouterConfig<Object>? router,
  }) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: toast),
          if (router != null) ChangeNotifierProvider(create: (_) => ShellActions()),
        ],
        child: AnimatedBuilder(
          animation: theme,
          builder: (_, _) {
            AppColors.isDark = theme.isDark;
            return router == null
                ? MaterialApp(
                    theme: buildAppTheme(dark: false),
                    darkTheme: buildAppTheme(dark: true),
                    themeMode: theme.themeMode,
                    themeAnimationDuration: Duration.zero,
                    home: const Scaffold(body: SingleChildScrollView(child: PerfilView())),
                  )
                : MaterialApp.router(
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
  }

  testWidgets('PerfilView oculta exportação/alertas para Colaborador e remove botões redundantes de foto',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<AuthViewModel> logarPerfil(String perfil, List<String> permissoes) async {
      final vm = criarAuth(MockClient((_) async => jsonOk({
            'token': 'jwt',
            'usuario': {
              'id': 1,
              'nome': 'Luiza Ferraz',
              'email': 'luiza@x.com',
              'perfil': perfil,
              'permissoes': permissoes,
            },
          })));
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
    final auth = criarAuth(MockClient((req) async {
      if (req.url.path.endsWith('/auth/me') && req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        salvos.add(body);
        final prefs = Map<String, dynamic>.from((body['preferencias'] as Map?) ?? {});
        return jsonOk({
          'usuario': {
            'id': 1,
            'nome': body['nome'] ?? 'Luiza Ferraz',
            'email': body['email'] ?? 'luiza@x.com',
            'perfil': 'COLABORADOR',
            'permissoes': ['painel.ver', 'perfil.editar_proprio'],
            'preferencias': {'tema': prefs['tema'] ?? 'claro'},
          },
        });
      }
      return jsonOk({
        'token': 'jwt',
        'usuario': {
          'id': 1,
          'nome': 'Luiza Ferraz',
          'email': 'luiza@x.com',
          'perfil': 'COLABORADOR',
          'permissoes': ['painel.ver', 'perfil.editar_proprio'],
          'preferencias': {'tema': 'claro'},
        },
      });
    }));

    await auth.login(email: 'luiza@x.com', senha: '123');
    final theme = ThemeController(inicial: 'claro');
    final toast = ToastController();

    await pumpComTema(tester, auth: auth, theme: theme, toast: toast);
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
    for (final (tela, textoEsperado, matcher) in [
      (const HomeView(), 'Começar agora', findsOneWidget),
      (const LoginView(), 'Entrar', findsWidgets),
    ]) {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            theme: buildAppTheme(dark: false),
            darkTheme: buildAppTheme(dark: true),
            themeMode: ThemeMode.dark,
            home: tela,
          ),
        ),
      );
      await tester.pumpAndSettle();
      ignorarFontes(tester);
      expect(find.text(textoEsperado), matcher);
    }
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
    final auth = criarAuth(MockClient((req) async {
      if (req.url.path.endsWith('/auth/logout')) return jsonOk({'mensagem': 'ok'});
      return jsonOk({'token': 'jwt', 'usuario': usuarioAtual});
    }));

    await auth.login(email: 'luiza@x.com', senha: '123');
    final theme = ThemeController(inicial: 'escuro');
    final toast = ToastController();
    final router = buildRouter(auth);
    addTearDown(router.dispose);

    auth.addListener(() {
      final u = auth.currentUser;
      if (u != null) theme.aplicar(u.preferencias.tema, persistir: false);
    });

    await pumpComTema(tester, auth: auth, theme: theme, toast: toast, router: router);
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
