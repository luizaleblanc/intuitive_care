import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intuitive_care_app/repositories/auth_repository.dart';
import 'package:intuitive_care_app/services/api_client.dart';
import 'package:intuitive_care_app/services/auth_service.dart';
import 'package:intuitive_care_app/services/session_storage_service.dart';
import 'package:intuitive_care_app/shared/ui/ui.dart';
import 'package:intuitive_care_app/viewmodels/auth_viewmodel.dart';
import 'package:intuitive_care_app/views/home_view.dart';
import 'package:intuitive_care_app/views/login_view.dart';
import 'package:intuitive_care_app/views/password_reset_views.dart';
import 'package:intuitive_care_app/views/register_view.dart';
import 'package:provider/provider.dart';

/// Critério 11 do MVP: Página inicial e Login sem rolagem horizontal em 360px.
/// Qualquer RenderFlex overflow vira exceção e reprova o teste.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> renderizar(WidgetTester tester, Widget tela, double largura) async {
    tester.view.physicalSize = Size(largura, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = ApiClient();
    final auth = AuthViewModel(
      AuthRepository(apiClient: client, authService: AuthService(client), storageService: SessionStorageService()),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: auth, child: MaterialApp(home: tela)),
    );
    await tester.pump();
  }

  // google_fonts não tem as fontes offline: ignora só esse erro, mantendo overflow como falha.
  void ignorarFontes(WidgetTester tester) {
    final e = tester.takeException();
    if (e != null && !e.toString().contains('GoogleFonts')) throw e as Object;
  }

  for (final largura in [360.0, 1440.0]) {
    testWidgets('Página inicial sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const HomeView(), largura);
      ignorarFontes(tester);
      expect(find.text('Começar agora'), findsOneWidget);
      expect(find.text('Design System'), findsOneWidget);
    });

    testWidgets('Login sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const LoginView(), largura);
      ignorarFontes(tester);
      expect(find.text('Entrar'), findsWidgets);
      // Painel Forest só aparece a partir de 1024px.
      expect(find.textContaining('sem planilha no meio.', findRichText: true), largura >= 1024 ? findsOneWidget : findsNothing);
    });

    testWidgets('Cadastro sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const RegisterView(), largura);
      ignorarFontes(tester);
      expect(find.text('Criar conta'), findsWidgets);
      final botao = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Criar conta'));
      expect(botao.onPressed, isNull);
    });

    testWidgets('Reset de senha sem overflow em ${largura.toInt()}px', (tester) async {
      await renderizar(tester, const ForgotPasswordView(), largura);
      ignorarFontes(tester);
      await renderizar(tester, const ResetPasswordView(), largura);
      ignorarFontes(tester);
      expect(find.text('Link de redefinição inválido.'), findsOneWidget);
    });
  }
}
