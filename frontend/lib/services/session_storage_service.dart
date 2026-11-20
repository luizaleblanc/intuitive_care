import 'package:shared_preferences/shared_preferences.dart';

/// Armazena apenas o token de sessão localmente para restaurar login ativo.
/// Nenhuma regra de negócio ou persistência substituta é feita no dispositivo.
class SessionStorageService {
  static const _tokenKey = 'intuitive_care_jwt_token';
  static const _themeKey = 'intuitive_care_theme';

  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {
      // Ignora falhas de storage em ambientes de teste sem plataforma nativa.
    }
  }

  Future<String?> readToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<void> saveTheme(String tema) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, tema == 'escuro' ? 'escuro' : 'claro');
    } catch (_) {}
  }

  Future<String?> readTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final valor = prefs.getString(_themeKey);
      if (valor == null) return null;
      return valor == 'escuro' ? 'escuro' : 'claro';
    } catch (_) {
      return null;
    }
  }
}
