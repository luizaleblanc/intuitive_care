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

  /// Nunca restaura login automaticamente: descarta eventual token antigo e exige entrada manual.
  Future<UserModel?> restoreSession() async {
    await clearLocalSession();
    return null;
  }

  Future<AuthSessionResult> login({
    required String email,
    required String senha,
  }) async {
    final res = await _authService.login(email: email, senha: senha);
    final token = (res['token'] ?? '').toString();
    final user = UserModel.fromJson(res['usuario'] as Map<String, dynamic>);
    _apiClient.setAuthToken(token);
    // Sessão mantida apenas em memória: ao reabrir o sistema, cai sempre na tela de login.
    await _storageService.clearToken();
    return AuthSessionResult(
      token: token,
      user: user,
      message: (res['mensagem'] ?? 'Login efetuado').toString(),
    );
  }

  /// Cria a conta sem abrir sessão: o usuário entra pela tela de login.
  Future<String> register({
    required String nome,
    required String email,
    required String senha,
    String? cargo,
  }) async {
    final res = await _authService.register(nome: nome, email: email, senha: senha, cargo: cargo);
    return (res['mensagem'] ?? 'Cadastro efetuado').toString();
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

  Future<String> forgotPassword({required String email}) async {
    final res = await _authService.forgotPassword(email: email);
    return (res['mensagem'] ?? '').toString();
  }

  Future<String> resetPassword({
    required String token,
    required String novaSenha,
  }) async {
    final res = await _authService.resetPassword(token: token, novaSenha: novaSenha);
    return (res['mensagem'] ?? 'Senha redefinida com sucesso.').toString();
  }
}
