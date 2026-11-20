import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'repositories/analitico_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/operadora_repository.dart';
import 'services/analitico_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/operadora_service.dart';
import 'services/session_storage_service.dart';
import 'shared/ui/ui.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/contas_viewmodel.dart';
import 'viewmodels/explorar_viewmodel.dart';
import 'viewmodels/operadoras_viewmodel.dart';
import 'viewmodels/painel_viewmodel.dart';
import 'views/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final storage = SessionStorageService();
  final themeController = ThemeController(storage: storage);
  await themeController.restaurar();

  final apiClient = ApiClient();
  final authRepository = AuthRepository(
    apiClient: apiClient,
    authService: AuthService(apiClient),
    storageService: storage,
  );
  final authVm = AuthViewModel(authRepository);
  apiClient.onUnauthorized = authVm.handleSessionExpired;
  authVm.initializeSession();

  final analitico = AnaliticoRepository(AnaliticoService(apiClient));
  runApp(
    IntuitiveCareApp(
      authViewModel: authVm,
      operadoraRepository: OperadoraRepository(OperadoraService(apiClient)),
      analiticoRepository: analitico,
      themeController: themeController,
    ),
  );
}

class IntuitiveCareApp extends StatefulWidget {
  final AuthViewModel authViewModel;
  final OperadoraRepository operadoraRepository;
  final AnaliticoRepository analiticoRepository;
  final ThemeController? themeController;

  const IntuitiveCareApp({
    super.key,
    required this.authViewModel,
    required this.operadoraRepository,
    required this.analiticoRepository,
    this.themeController,
  });

  @override
  State<IntuitiveCareApp> createState() => _IntuitiveCareAppState();
}

class _IntuitiveCareAppState extends State<IntuitiveCareApp> {
  late final GoRouter _router = buildRouter(widget.authViewModel);
  late final _painel = PainelViewModel(widget.analiticoRepository);
  late final _operadoras = OperadorasViewModel(widget.operadoraRepository);
  late final _contas = ContasViewModel(widget.analiticoRepository);
  late final _explorar = ExplorarViewModel(widget.analiticoRepository);
  late final ThemeController _theme = widget.themeController ?? ThemeController();
  final _toast = ToastController();
  final _shell = ShellActions();
  String? _usuarioAnterior;

  void _onAuthChanged() {
    final user = widget.authViewModel.currentUser;
    final atual = user?.email;
    if (atual != _usuarioAnterior) {
      _usuarioAnterior = atual;
      _painel.reset();
      _operadoras.reset();
      _contas.reset();
    }
    if (user != null) {
      _theme.aplicar(user.preferencias.tema);
    }
  }

  @override
  void initState() {
    super.initState();
    _onAuthChanged();
    widget.authViewModel.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authViewModel.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authViewModel),
        ChangeNotifierProvider.value(value: _painel),
        ChangeNotifierProvider.value(value: _operadoras),
        ChangeNotifierProvider.value(value: _contas),
        ChangeNotifierProvider.value(value: _explorar),
        ChangeNotifierProvider.value(value: _theme),
        ChangeNotifierProvider.value(value: _toast),
        ChangeNotifierProvider.value(value: _shell),
      ],
      child: AnimatedBuilder(
        animation: _theme,
        builder: (context, _) {
          AppColors.isDark = _theme.isDark;
          return MaterialApp.router(
            title: 'Intuitive Care',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark: false),
            darkTheme: buildAppTheme(dark: true),
            themeMode: _theme.themeMode,
            themeAnimationDuration: Duration.zero,
            routerConfig: _router,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              AppColors.isDark = _theme.isDark;
              return AppThemeScope(
                isDark: _theme.isDark,
                child: ToastOverlay(controller: _toast, child: child ?? const SizedBox()),
              );
            },
          );
        },
      ),
    );
  }
}
