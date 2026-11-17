import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/session_storage_service.dart';

class AuthSessionResult {
  final String token;
  final UserModel user;
  final String message;

  const AuthSessionResult({
    required this.token,
    required this.user,
    required this.message,
  });
}

class PasswordRecoveryResult {
  final String message;
  final bool emailSent;
  final String? provider;
  final String? demoCode;

  const PasswordRecoveryResult({
    required this.message,
    required this.emailSent,
    this.provider,
    this.demoCode,
  });
}

/// Repositório responsável por intermediar autenticação e sessão entre ViewModel e AuthService.
class AuthRepository {
  final ApiClient _apiClient;
  final AuthService _authService;
  final SessionStorageService _storageService;

  AuthRepository({
    required ApiClient apiClient,
    required AuthService authService,
    required SessionStorageService storageService,
  })  : _apiClient = apiClient,
        _authService = authService,
        _storageService = storageService;

  Future<UserModel?> restoreSession() async {
    final token = await _storageService.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    _apiClient.setAuthToken(token);
    try {
      final res = await _authService.fetchAuthenticatedUser();
      final userMap = res['usuario'] as Map<String, dynamic>?;
      if (userMap == null) {
        await clearLocalSession();
        return null;
      }
      return UserModel.fromJson(userMap);
    } catch (_) {
      await clearLocalSession();
      return null;
    }
  }

  Future<AuthSessionResult> login({
    required String email,
    required String senha,
  }) async {
    final res = await _authService.login(email: email, senha: senha);
    final token = (res['token'] ?? '').toString();
    final user = UserModel.fromJson(res['usuario'] as Map<String, dynamic>);
    _apiClient.setAuthToken(token);
    await _storageService.saveToken(token);
    return AuthSessionResult(
      token: token,
      user: user,
      message: (res['mensagem'] ?? 'Login efetuado').toString(),
    );
  }

  Future<AuthSessionResult> register({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final res = await _authService.register(nome: nome, email: email, senha: senha);
    final token = (res['token'] ?? '').toString();
    final user = UserModel.fromJson(res['usuario'] as Map<String, dynamic>);
    _apiClient.setAuthToken(token);
    await _storageService.saveToken(token);
    return AuthSessionResult(
      token: token,
      user: user,
      message: (res['mensagem'] ?? 'Cadastro efetuado').toString(),
    );
  }

  Future<UserModel> refreshUser() async {
    final res = await _authService.fetchAuthenticatedUser();
    return UserModel.fromJson(res['usuario'] as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> campos) async {
    final res = await _authService.updateProfile(campos);
    return UserModel.fromJson(res['usuario'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _apiClient.setAuthToken(null);
    await _storageService.clearToken();
  }

  Future<PasswordRecoveryResult> forgotPassword({required String email}) async {
    final res = await _authService.forgotPassword(email: email);
    return PasswordRecoveryResult(
      message: (res['mensagem'] ?? '').toString(),
      emailSent: res['email_enviado'] == true,
      provider: res['provedor_email']?.toString(),
      demoCode: res['codigo_demonstracao']?.toString(),
    );
  }

  Future<String> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    final res = await _authService.resetPassword(
      email: email,
      codigo: codigo,
      novaSenha: novaSenha,
    );
    return (res['mensagem'] ?? 'Senha redefinida com sucesso.').toString();
  }
}
