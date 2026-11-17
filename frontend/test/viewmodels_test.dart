import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intuitive_care_app/models/operadora_model.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/repositories/operadora_repository.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/operadora_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/viewmodels/operadora_viewmodel.dart';

class _InMemorySessionStorage extends SessionStorageService {
  String? _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> clearToken() async => _token = null;
}

void main() {
  group('ViewModels + Repositories + ApiClient Integration', () {
    test('AuthViewModel realiza login, envia Bearer token e executa logout', () async {
      String? capturedAuthHeader;

      final mockHttp = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'mensagem': 'Autenticação realizada com sucesso.',
              'token': 'jwt-token-demo',
              'usuario': {
                'id': 1,
                'nome': 'Analista Teste',
                'email': 'analista@intuitivecare.com.br',
                'perfil': 'ANALISTA',
                'ativo': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response(jsonEncode({'mensagem': 'Logoff realizado.'}), 200);
        }
        return http.Response(jsonEncode({'erro': 'Não encontrado'}), 404);
      });

      final apiClient = ApiClient(httpClient: mockHttp);
      final authVm = AuthViewModel(
        AuthRepository(
          apiClient: apiClient,
          authService: AuthService(apiClient),
          storageService: _InMemorySessionStorage(),
        ),
      );

      final loggedIn = await authVm.login(
        email: 'analista@intuitivecare.com.br',
        senha: 'Senha@123',
      );

      expect(loggedIn, true);
      expect(authVm.isAuthenticated, true);
      expect(authVm.currentUser?.nome, 'Analista Teste');
      expect(apiClient.authToken, 'jwt-token-demo');

      await authVm.logout();
      expect(capturedAuthHeader, 'Bearer jwt-token-demo');
      expect(authVm.isAuthenticated, false);
      expect(authVm.currentUser, isNull);
    });

    test('OperadoraViewModel trata erros HTTP 400 da API Flask', () async {
      final mockHttp = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/operadoras')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'erro': 'CNPJ inválido: dígitos verificadores não conferem.'})),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({'data': [], 'total': 0, 'page': 1, 'limit': 8, 'total_pages': 1}),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockHttp)..setAuthToken('token');
      final opVm = OperadoraViewModel(OperadoraRepository(OperadoraService(apiClient)));

      final ok = await opVm.createOperadora(
        const OperadoraModel(
          registroAns: '999001',
          cnpj: '12345678000199',
          razaoSocial: 'Teste LTDA',
          uf: 'PB',
        ),
      );

      expect(ok, false);
      expect(opVm.errorMessage, contains('CNPJ inválido'));
    });
  });
}
