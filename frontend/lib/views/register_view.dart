import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/senha.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'auth_layout.dart';

/// Cadastro (/cadastro): toda conta nova entra com o perfil Colaborador.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _cargo = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  bool _aceite = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    for (final c in [_nome, _email, _senha, _confirmar]) {
      c.addListener(_atualizar);
    }
  }

  void _atualizar() => setState(() {});

  @override
  void dispose() {
    for (final c in [_nome, _email, _cargo, _senha, _confirmar]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _senhasDiferentes => _confirmar.text.isNotEmpty && _confirmar.text != _senha.text;

  bool get _valido =>
      _nome.text.trim().length >= 3 &&
      emailValido(_email.text) &&
      senhaValida(_senha.text) &&
      _confirmar.text == _senha.text &&
      _aceite;

  Future<void> _cadastrar() async {
    if (!_valido) return;
    setState(() => _erro = null);
    final vm = context.read<AuthViewModel>();
    final toast = context.read<ToastController>();
    final email = _email.text.trim();
    final ok = await vm.register(nome: _nome.text, email: email, senha: _senha.text, cargo: _cargo.text);
    if (!mounted) return;
    if (ok) {
      toast.show('Conta criada. Faça login para continuar.');
      context.go('/login', extra: email);
    } else {
      setState(() => _erro = vm.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthViewModel>().isLoading;
    return AuthLayout(
      titulo: 'Criar conta',
      subtitulo: 'Seu acesso começa com o perfil Colaborador.',
      children: [
        LabeledField(
          label: 'Nome completo',
          child: PillTextField(
            controller: _nome,
            label: 'Nome completo',
            hint: 'Seu nome',
            icon: LucideIcons.user,
            height: 48,
            autofillHints: const [AutofillHints.name],
          ),
        ),
        const SizedBox(height: 16),
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
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Cargo (opcional)',
          child: PillTextField(
            controller: _cargo,
            label: 'Cargo',
            hint: 'Ex.: Analista de Negócios',
            icon: LucideIcons.briefcase,
            height: 48,
          ),
        ),
        const SizedBox(height: 16),
        CampoSenha(controller: _senha, label: 'Senha', hint: 'Crie uma senha'),
        const SizedBox(height: 8),
        ForcaSenha(_senha.text),
        const SizedBox(height: 16),
        CampoSenha(
          controller: _confirmar,
          label: 'Confirmar senha',
          hint: 'Repita a senha',
          erro: _senhasDiferentes,
          onSubmitted: (_) => _cadastrar(),
        ),
        if (_senhasDiferentes) ...[
          const SizedBox(height: 6),
          Text('As senhas não conferem.', style: AppText.sans(12, color: AppColors.red700)),
        ],
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _aceite,
          onChanged: (v) => setState(() => _aceite = v ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.primaryBg,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Li e aceito os termos de uso.', style: AppText.sans(14)),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 8),
          ErrorBox(_erro!),
        ],
        const SizedBox(height: 16),
        AppButton(
          'Criar conta',
          size: ButtonSize.lg,
          expand: true,
          loading: loading,
          loadingLabel: 'Criando conta...',
          onPressed: _valido ? _cadastrar : null,
        ),
      ],
    );
  }
}
