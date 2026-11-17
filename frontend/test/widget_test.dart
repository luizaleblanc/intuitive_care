import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/views/login_view.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LoginView exibe campos de autenticação e links de cadastro/recuperação',
      (WidgetTester tester) async {
    final apiClient = ApiClient();
    final authVm = AuthViewModel(
      AuthRepository(
        apiClient: apiClient,
        authService: AuthService(apiClient),
        storageService: SessionStorageService(),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authVm,
        child: const MaterialApp(home: LoginView()),
      ),
    );

    expect(find.text('Intuitive Care'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar nova conta'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });
}
