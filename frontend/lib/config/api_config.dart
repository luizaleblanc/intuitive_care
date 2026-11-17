import 'package:flutter/foundation.dart';

/// Configuração centralizada da URL base da API REST Flask.
///
/// Permite sobrescrita via `--dart-define=API_URL=http://SEU_IP:5000/api`.
class ApiConfig {
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    // No emulador Android, localhost aponta para o próprio dispositivo;
    // 10.0.2.2 redireciona para a máquina host onde o Flask está rodando.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    if (kIsWeb) {
      // Em desenvolvimento (flutter run -d chrome) o app roda em outra porta: usa a API Flask local.
      final host = Uri.base.host;
      if ((host == 'localhost' || host == '127.0.0.1') && Uri.base.port != 5000) {
        return 'http://localhost:5000/api';
      }
      return '${Uri.base.origin}/api';
    }
    return 'http://localhost:5000/api';
  }
}
