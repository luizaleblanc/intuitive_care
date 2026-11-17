import 'api_client.dart';

/// Serviço de comunicação HTTP com os endpoints de autenticação da API Flask.
class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<Map<String, dynamic>> register({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final res = await _client.post('/auth/register', body: {
      'nome': nome,
      'email': email,
      'senha': senha,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final res = await _client.post('/auth/login', body: {
      'email': email,
      'senha': senha,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> fetchAuthenticatedUser() async {
    final res = await _client.get('/auth/me');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> campos) async {
    final res = await _client.put('/auth/me', body: campos);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final res = await _client.post('/auth/forgot-password', body: {'email': email});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    final res = await _client.post('/auth/reset-password', body: {
      'email': email,
      'codigo': codigo,
      'nova_senha': novaSenha,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}
