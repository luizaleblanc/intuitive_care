import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/ui/ui.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/app_shell.dart';
import '../views/despesas_view.dart';
import '../views/home_view.dart';
import '../views/login_view.dart';
import '../views/operadoras_view.dart';
import '../views/painel_view.dart';
import '../views/password_reset_views.dart';
import '../views/perfil_view.dart';
import '../views/register_view.dart';

const _rotasSoVisitante = {'/login', '/cadastro', '/esqueci-senha'};
const _rotasPublicas = {'/', '/redefinir-senha', ..._rotasSoVisitante};

/// Rotas do MVP (seção 6): públicas (/ e /login) e autenticadas dentro do AppShell.
GoRouter buildRouter(AuthViewModel auth) => GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        final rota = state.matchedLocation;
        if (auth.status == AuthStatus.initializing) return null;
        final logado = auth.status == AuthStatus.authenticated;
        if (!logado && !_rotasPublicas.contains(rota)) return '/login';
        if (logado && _rotasSoVisitante.contains(rota)) return '/painel';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeView()),
        GoRoute(path: '/login', builder: (_, s) => LoginView(emailInicial: s.extra as String?)),
        GoRoute(path: '/cadastro', builder: (_, _) => const RegisterView()),
        GoRoute(path: '/esqueci-senha', builder: (_, _) => const ForgotPasswordView()),
        GoRoute(
          path: '/redefinir-senha',
          builder: (_, s) => ResetPasswordView(token: s.uri.queryParameters['token']),
        ),
        ShellRoute(
          builder: (context, state, child) => ListenableBuilder(
            listenable: auth,
            builder: (context, _) {
              if (auth.status == AuthStatus.initializing) {
                return const Scaffold(body: LoadingBlock(label: 'Restaurando sessão...'));
              }
              return AppShell(location: state.matchedLocation, child: child);
            },
          ),
          routes: [
            GoRoute(path: '/painel', pageBuilder: (_, s) => _fade(s, const PainelView())),
            GoRoute(
              path: '/operadoras',
              pageBuilder: (_, s) => _fade(s, OperadorasView(buscaInicial: s.uri.queryParameters['q'])),
            ),
            GoRoute(
              path: '/despesas',
              pageBuilder: (_, s) => _fade(s, DespesasView(contaDestacada: s.uri.queryParameters['conta'])),
            ),
            GoRoute(path: '/perfil', pageBuilder: (_, s) => _fade(s, const PerfilView())),
          ],
        ),
      ],
    );

/// Transição "fade-up" (opacidade + 8px) do protótipo.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, _, c) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.01), end: Offset.zero).animate(anim),
          child: c,
        ),
      ),
    );
