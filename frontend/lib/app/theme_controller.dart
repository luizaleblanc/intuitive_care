import 'package:flutter/material.dart';

import '../services/session_storage_service.dart';
import 'theme_tokens.dart';

/// Controlador reativo de tema da aplicação (apenas 'claro' ou 'escuro').
class ThemeController extends ChangeNotifier {
  final SessionStorageService? _storage;
  String _tema;

  ThemeController({SessionStorageService? storage, String inicial = 'claro'})
      : _storage = storage,
        _tema = normalizarTema(inicial) {
    AppColors.scopeReader ??= AppThemeScope.maybeOf;
    AppColors.isDark = _tema == 'escuro';
  }

  static String normalizarTema(String? valor) => valor == 'escuro' ? 'escuro' : 'claro';

  String get tema => _tema;
  bool get isDark => _tema == 'escuro';
  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> restaurar() async {
    final salvo = await _storage?.readTheme();
    if (salvo != null) aplicar(salvo, persistir: false);
  }

  void aplicar(String? novoTema, {bool persistir = true}) {
    final normalizado = normalizarTema(novoTema);
    final mudou = normalizado != _tema || AppColors.isDark != (normalizado == 'escuro');
    _tema = normalizado;
    AppColors.isDark = _tema == 'escuro';
    if (persistir) _storage?.saveTheme(_tema);
    if (mudou) notifyListeners();
  }
}

/// Escopo herdado que propaga o modo escuro de forma síncrona (sem atraso do AnimatedTheme).
class AppThemeScope extends InheritedWidget {
  final bool isDark;
  const AppThemeScope({super.key, required this.isDark, required super.child});

  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.isDark;

  @override
  InheritedElement createElement() {
    AppColors.scopeReader ??= maybeOf;
    return super.createElement();
  }

  @override
  bool updateShouldNotify(covariant AppThemeScope oldWidget) => oldWidget.isDark != isDark;
}
