import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/senha.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'auth_layout.dart';

/// Pedido do link de redefinição (/esqueci-senha).
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _email = TextEditingController();
  String? _erro;
  String? _enviado;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!emailValido(_email.text)) return;
    setState(() {
      _erro = null;
      _enviado = null;
    });
    final vm = context.read<AuthViewModel>();
    final ok = await vm.requestPasswordRecovery(email: _email.text);
    if (!mounted) return;
    setState(() {
      _enviado = ok ? vm.successMessage : null;
      _erro = ok ? null : vm.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthViewModel>().isLoading;
    return AuthLayout(
      titulo: 'Esqueci a senha',
      subtitulo: 'Informe seu e-mail para receber o link de redefinição.',
      children: [
        LabeledField(
          label: 'E-mail',
          child: PillTextField(
            controller: _email,
            label: 'E-mail',
            hint: 'nome@email.com',
            icon: LucideIcons.mail,
            height: 48,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _enviar(),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 16),
          ErrorBox(_erro!),
        ],
        if (_enviado != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(12)),
              child: Text(_enviado!, style: AppText.sans(14, color: AppColors.emerald700)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          'Enviar link',
          size: ButtonSize.lg,
          expand: true,
          loading: loading,
          loadingLabel: 'Enviando...',
          onPressed: emailValido(_email.text) ? _enviar : null,
        ),
      ],
    );
  }
}

/// Definição da nova senha a partir do link do e-mail (/redefinir-senha?token=...).
class ResetPasswordView extends StatefulWidget {
  final String? token;
  const ResetPasswordView({super.key, this.token});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  String? _erro;

  bool get _temToken => (widget.token ?? '').isNotEmpty;
  bool get _senhasDiferentes => _confirmar.text.isNotEmpty && _confirmar.text != _senha.text;
  bool get _valido => _temToken && senhaValida(_senha.text) && _confirmar.text == _senha.text;

  @override
  void initState() {
    super.initState();
    _senha.addListener(() => setState(() {}));
    _confirmar.addListener(() => setState(() {}));
    if (!_temToken) _erro = 'Link de redefinição inválido.';
  }

  @override
  void dispose() {
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    if (!_valido) return;
    setState(() => _erro = null);
    final vm = context.read<AuthViewModel>();
    final toast = context.read<ToastController>();
    final ok = await vm.confirmPasswordReset(token: widget.token!, novaSenha: _senha.text);
    if (!mounted) return;
    if (ok) {
      toast.show('Senha redefinida. Faça login.');
      context.go('/login');
    } else {
      setState(() => _erro = vm.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthViewModel>().isLoading;
    return AuthLayout(
      titulo: 'Nova senha',
      subtitulo: 'Ao salvar, as sessões abertas serão encerradas.',
      children: [
        CampoSenha(controller: _senha, label: 'Nova senha', hint: 'Crie uma senha'),
        const SizedBox(height: 8),
        ForcaSenha(_senha.text),
        const SizedBox(height: 16),
        CampoSenha(
          controller: _confirmar,
          label: 'Confirmar senha',
          hint: 'Repita a senha',
          erro: _senhasDiferentes,
          onSubmitted: (_) => _redefinir(),
        ),
        if (_senhasDiferentes) ...[
          const SizedBox(height: 6),
          Text('As senhas não conferem.', style: AppText.sans(12, color: AppColors.red700)),
        ],
        if (_erro != null) ...[
          const SizedBox(height: 16),
          ErrorBox(_erro!),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.go('/esqueci-senha'),
            child: Text('Solicitar novo link',
                style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.brandText)),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          'Salvar nova senha',
          size: ButtonSize.lg,
          expand: true,
          loading: loading,
          loadingLabel: 'Salvando...',
          onPressed: _valido ? _redefinir : null,
        ),
      ],
    );
  }
}
