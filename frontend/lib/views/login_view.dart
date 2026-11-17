import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../shared/brand/brand.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/exporter.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Login (/login) — duas colunas no desktop, só formulário no mobile (seção 7.2).
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrar = false;
  String? _erro;

  /// Contas de demonstração do MVP (exibidas apenas em desenvolvimento).
  static const _demo = [
    ('admin@intuitivecare.com.br', 'Admin@2025', 'Administrador', LucideIcons.shieldCheck),
    ('consumidor@intuitivecare.com.br', 'Consulta@2025', 'Consumidor', LucideIcons.eye),
  ];

  @override
  void initState() {
    super.initState();
    // Mensagem de sessão expirada vinda do AuthViewModel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = context.read<AuthViewModel>().errorMessage;
      if (msg != null && mounted) setState(() => _erro = msg);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _erro = null);
    if (_email.text.trim().isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Informe e-mail e senha.');
      return;
    }
    final vm = context.read<AuthViewModel>();
    final ok = await vm.login(email: _email.text, senha: _senha.text);
    if (!mounted) return;
    if (ok) {
      context.go('/painel');
    } else {
      final msg = vm.errorMessage ?? '';
      setState(() => _erro = msg.contains('inválidos') || msg.contains('incorret')
          ? 'E-mail ou senha incorretos.'
          : (msg.isEmpty ? 'E-mail ou senha incorretos.' : msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop) const Expanded(child: _PainelForest()),
          Expanded(child: _formulario(context, desktop)),
        ],
      ),
    );
  }

  Widget _formulario(BuildContext context, bool desktop) {
    final loading = context.watch<AuthViewModel>().isLoading;
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 20 : 40, vertical: 24),
        child: Column(
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(LucideIcons.arrowLeft, size: 15, color: AppColors.muted),
                  label: Text('Página inicial', style: AppText.sans(14, weight: FontWeight.w500, color: AppColors.muted)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => abrirNovaAba('design-system.html'),
                  child: Text('Design System', style: AppText.sans(14, weight: FontWeight.w500, color: AppColors.muted)),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!desktop) ...[
                            const FittedBox(child: LogoHorizontal(size: 40)),
                            const SizedBox(height: 32),
                          ],
                          Semantics(header: true, child: Text('Entrar', style: AppText.pageTitle())),
                          const SizedBox(height: 4),
                          Text('Use seu e-mail corporativo e senha.', style: AppText.sans(14, color: AppColors.muted)),
                          const SizedBox(height: 32),
                          LabeledField(
                            label: 'E-mail',
                            child: PillTextField(
                              controller: _email,
                              label: 'E-mail',
                              hint: 'nome@intuitivecare.com.br',
                              icon: LucideIcons.mail,
                              height: 48,
                              error: _erro != null,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username, AutofillHints.email],
                              onSubmitted: (_) => _entrar(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          LabeledField(
                            label: 'Senha',
                            trailing: InkWell(
                              onTap: () {},
                              child: Text('Esqueci a senha',
                                  style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.forest)),
                            ),
                            child: PillTextField(
                              controller: _senha,
                              label: 'Senha',
                              hint: 'Sua senha',
                              icon: LucideIcons.lock,
                              height: 48,
                              obscure: !_mostrar,
                              error: _erro != null,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _entrar(),
                              suffix: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: AppIconButton(
                                  icon: _mostrar ? LucideIcons.eyeOff : LucideIcons.eye,
                                  label: _mostrar ? 'Ocultar senha' : 'Mostrar senha',
                                  size: 32,
                                  onPressed: () => setState(() => _mostrar = !_mostrar),
                                ),
                              ),
                            ),
                          ),
                          if (_erro != null) ...[
                            const SizedBox(height: 16),
                            ErrorBox(_erro!),
                          ],
                          const SizedBox(height: 16),
                          AppButton(
                            'Entrar',
                            size: ButtonSize.lg,
                            expand: true,
                            loading: loading,
                            loadingLabel: 'Entrando...',
                            onPressed: _entrar,
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 32),
                            _AcessosDemo(
                              contas: _demo,
                              onFill: (email, senha) => setState(() {
                                _email.text = email;
                                _senha.text = senha;
                                _erro = null;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PainelForest extends StatelessWidget {
  const _PainelForest();

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: AppColors.forest),
        child: Stack(
          children: [
            Positioned(
              right: -96,
              top: -96,
              child: Container(
                width: 384,
                height: 384,
                decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.1), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.go('/'),
                    child: const LogoHorizontal(negative: true, size: 40),
                  ),
                  const Spacer(),
                  const Mark(size: 120, bg: null, strokeWidth: 1.8),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Do arquivo da ANS ao painel, '),
                        TextSpan(text: 'sem planilha no meio.', style: TextStyle(color: AppColors.mint)),
                      ]),
                      style: AppText.display(34, color: Colors.white).copyWith(height: 1.25),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Text(
                      'Extração, tratamento e análise de operadoras e despesas assistenciais em um só lugar.',
                      style: AppText.sans(16, color: Colors.white.withValues(alpha: 0.7), height: 1.5),
                    ),
                  ),
                  const Spacer(),
                  Text('Intuitive Care · Controle e Tratamento de dados',
                      style: AppText.sans(12, color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AcessosDemo extends StatelessWidget {
  final List<(String, String, String, IconData)> contas;
  final void Function(String email, String senha) onFill;
  const _AcessosDemo({required this.contas, required this.onFill});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.dsCard, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACESSOS DE DEMONSTRAÇÃO', style: AppText.sans(12, weight: FontWeight.w700, color: AppColors.muted, spacing: 12 * 0.08)),
            const SizedBox(height: 12),
            for (final c in contas) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onFill(c.$1, c.$2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: AppColors.forest, shape: BoxShape.circle),
                          child: Icon(c.$4, size: 14, color: AppColors.mint),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.$3, style: AppText.sans(14, weight: FontWeight.w600)),
                              Text('${c.$1} · ${c.$2}',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.mono(11, weight: FontWeight.w400, color: AppColors.caption)),
                            ],
                          ),
                        ),
                        Text('Preencher', style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.forest)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
}
