import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/theme.dart';
import '../shared/brand/brand.dart';
import '../shared/ui/ui.dart';

/// Página inicial (/) — limpa, centralizada, sem dados nem números (seção 7.1).
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  static const _beneficios = [
    ('Confiança', 'Cada registro é validado antes de chegar até você. Sem retrabalho, sem dúvida.'),
    ('Clareza', 'Operadoras e despesas organizadas para você entender em segundos, não em horas.'),
    ('Tempo', 'O trabalho repetitivo fica com a gente. A análise que gera valor fica com você.'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 640;
    final pad = mobile ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // minWidth infinito força a coluna a ocupar toda a largura (o Scaffold afrouxa a restrição),
            // mantendo o conteúdo centralizado em vez de colado à esquerda.
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height, minWidth: double.infinity),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, mobile ? 40 : 72, pad, 64),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.mint.withValues(alpha: dark ? 0.22 : 0.18),
                                  blurRadius: 80,
                                  spreadRadius: 30,
                                ),
                              ],
                            ),
                          ),
                          const Mark(size: 132, strokeWidth: 2),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('intuitivecare',
                          style: AppText.display(mobile ? 32 : 40, color: AppColors.brandText)),
                      const SizedBox(height: 4),
                      Text('CONTROLE E TRATAMENTO DE DADOS',
                          softWrap: false,
                          style: AppText.sans(11, weight: FontWeight.w600, color: AppColors.muted, spacing: 11 * 0.2)),
                      const SizedBox(height: 48),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 768),
                        child: Semantics(
                          header: true,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Pare de tratar planilhas.\n'),
                                TextSpan(text: 'Comece a tomar decisões.', style: TextStyle(color: AppColors.brandText)),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: AppText.display(mobile ? 32 : 48).copyWith(height: 1.12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 576),
                        child: Text(
                          'Os dados da saúde suplementar chegam brutos, fragmentados e difíceis de confiar. '
                          'A Intuitive Care entrega tudo limpo, validado e pronto para você enxergar o que importa.',
                          textAlign: TextAlign.center,
                          style: AppText.sans(17, color: AppColors.muted, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 36),
                      AppButton(
                        'Começar agora',
                        size: ButtonSize.lg,
                        iconRight: LucideIcons.arrowRight,
                        onPressed: () => context.go('/login'),
                      ),
                      const SizedBox(height: 16),
                      Text('Acesso para administradores e analistas.',
                          style: AppText.sans(12, color: AppColors.muted)),
                      const SizedBox(height: 80),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 896),
                        child: Flex(
                          direction: mobile ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _beneficios.length; i++) ...[
                              if (i > 0) const SizedBox(width: 40, height: 40),
                              _Beneficio(_beneficios[i].$1, _beneficios[i].$2, expand: !mobile),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Intuitive Care · Controle e Tratamento de dados',
                      style: AppText.sans(12, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  final String titulo;
  final String texto;
  final bool expand;
  const _Beneficio(this.titulo, this.texto, {required this.expand});

  @override
  Widget build(BuildContext context) {
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 16),
        Text(titulo, style: AppText.display(18, weight: FontWeight.w700, color: AppColors.brandText)),
        const SizedBox(height: 8),
        Text(texto, style: AppText.sans(14, color: AppColors.muted, height: 1.6)),
      ],
    );
    return expand ? Expanded(child: conteudo) : SizedBox(width: double.infinity, child: conteudo);
  }
}
