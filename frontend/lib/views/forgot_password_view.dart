import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../widgets/app_error_banner.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  bool _codeRequested = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_emailController.text.trim().isEmpty) return;
    final authVm = context.read<AuthViewModel>();
    final ok = await authVm.requestPasswordRecovery(email: _emailController.text);
    if (ok && mounted) {
      setState(() => _codeRequested = true);
      if (authVm.demoRecoveryCode != null) {
        _codigoController.text = authVm.demoRecoveryCode!;
      }
    }
  }

  Future<void> _resetPassword() async {
    final authVm = context.read<AuthViewModel>();
    final ok = await authVm.confirmPasswordReset(
      email: _emailController.text,
      codigo: _codigoController.text,
      novaSenha: _novaSenhaController.text,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida com sucesso! Faça login.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperação de Senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recuperar acesso por e-mail',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A API Flask gera um código temporário e aciona o serviço de envio de e-mail.',
                  ),
                  const SizedBox(height: 20),
                  if (authVm.errorMessage != null)
                    AppErrorBanner(
                      message: authVm.errorMessage!,
                      onDismiss: authVm.clearMessages,
                    ),
                  if (authVm.successMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authVm.successMessage!,
                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
                          ),
                          if (authVm.demoRecoveryCode != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Código (modo demonstração local): ${authVm.demoRecoveryCode}',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                          ],
                        ],
                      ),
                    ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail cadastrado',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: authVm.isLoading ? null : _requestCode,
                    icon: const Icon(Icons.send),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(authVm.isLoading ? 'Enviando...' : 'Enviar código de recuperação'),
                    ),
                  ),
                  if (_codeRequested) ...[
                    const Divider(height: 32),
                    TextField(
                      controller: _codigoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Código de 6 dígitos',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _novaSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nova senha (letras e números)',
                        prefixIcon: Icon(Icons.lock_reset),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: authVm.isLoading ? null : _resetPassword,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Redefinir Senha'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
