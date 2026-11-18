import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/theme.dart';
import '../shared/brand/brand.dart';
import '../shared/charts/charts.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/senha.dart';

/// Moldura das telas públicas de conta: painel Forest no desktop e formulário centralizado.
class AuthLayout extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  const AuthLayout({super.key, required this.titulo, required this.subtitulo, required this.children});

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final desktop = largura >= 1024;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop) const Expanded(child: PainelForest()),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: largura < 640 ? 20 : 40, vertical: 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(LucideIcons.arrowLeft, size: 15, color: AppColors.muted),
                        label: Text('Voltar ao login',
                            style: AppText.sans(14, weight: FontWeight.w500, color: AppColors.muted)),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 24),
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
                                  Semantics(header: true, child: Text(titulo, style: AppText.pageTitle())),
                                  const SizedBox(height: 4),
                                  Text(subtitulo, style: AppText.sans(14, color: AppColors.muted)),
                                  const SizedBox(height: 28),
                                  ...children,
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de senha com botão de mostrar/ocultar.
class CampoSenha extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool erro;
  final ValueChanged<String>? onSubmitted;

  const CampoSenha({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.erro = false,
    this.onSubmitted,
  });

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _mostrar = false;

  @override
  Widget build(BuildContext context) => LabeledField(
        label: widget.label,
        child: PillTextField(
          controller: widget.controller,
          label: widget.label,
          hint: widget.hint,
          icon: LucideIcons.lock,
          height: 48,
          obscure: !_mostrar,
          error: widget.erro,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: widget.onSubmitted,
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
      );
}

/// Barra de força e regra da senha.
class ForcaSenha extends StatelessWidget {
  final String senha;
  const ForcaSenha(this.senha, {super.key});

  @override
  Widget build(BuildContext context) {
    final pontos = pontosSenha(senha);
    final cor = pontos <= 1 ? AppColors.danger : (pontos < maxPontosSenha ? AppColors.lime : AppColors.mint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBar(fraction: pontos / maxPontosSenha, height: 6, color: cor),
        const SizedBox(height: 6),
        Text(regraSenha, style: AppText.sans(12, color: AppColors.muted)),
      ],
    );
  }
}

class PainelForest extends StatelessWidget {
  const PainelForest({super.key});

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
