import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repositories/auth_repository.dart';
import 'repositories/despesa_repository.dart';
import 'repositories/estatistica_repository.dart';
import 'repositories/operadora_repository.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/despesa_service.dart';
import 'services/estatistica_service.dart';
import 'services/operadora_service.dart';
import 'services/session_storage_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/despesa_viewmodel.dart';
import 'viewmodels/operadora_viewmodel.dart';
import 'views/login_view.dart';
import 'views/main_shell_view.dart';
import 'views/splash_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final storageService = SessionStorageService();

  final authRepository = AuthRepository(
    apiClient: apiClient,
    authService: AuthService(apiClient),
    storageService: storageService,
  );
  final operadoraRepository = OperadoraRepository(OperadoraService(apiClient));
  final despesaRepository = DespesaRepository(DespesaService(apiClient));
  final estatisticaRepository = EstatisticaRepository(EstatisticaService(apiClient));

  runApp(
    IntuitiveCareApp(
      apiClient: apiClient,
      authRepository: authRepository,
      operadoraRepository: operadoraRepository,
      despesaRepository: despesaRepository,
      estatisticaRepository: estatisticaRepository,
    ),
  );
}

class IntuitiveCareApp extends StatelessWidget {
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final OperadoraRepository operadoraRepository;
  final DespesaRepository despesaRepository;
  final EstatisticaRepository estatisticaRepository;

  const IntuitiveCareApp({
    super.key,
    required this.apiClient,
    required this.authRepository,
    required this.operadoraRepository,
    required this.despesaRepository,
    required this.estatisticaRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) {
            final vm = AuthViewModel(authRepository)..initializeSession();
            apiClient.onUnauthorized = vm.handleSessionExpired;
            return vm;
          },
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (_) => DashboardViewModel(estatisticaRepository),
        ),
        ChangeNotifierProvider<OperadoraViewModel>(
          create: (_) => OperadoraViewModel(operadoraRepository),
        ),
        ChangeNotifierProvider<DespesaViewModel>(
          create: (_) => DespesaViewModel(despesaRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Intuitive Care',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF059669),
          brightness: Brightness.light,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authStatus = context.select<AuthViewModel, AuthStatus>((vm) => vm.status);

    switch (authStatus) {
      case AuthStatus.initializing:
        return const SplashView();
      case AuthStatus.unauthenticated:
        return const LoginView();
      case AuthStatus.authenticated:
        return const MainShellView();
    }
  }
}
