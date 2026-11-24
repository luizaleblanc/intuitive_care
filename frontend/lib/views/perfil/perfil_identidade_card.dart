import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../models/user_model.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../app_shell.dart';

class PerfilIdentidadeCard extends StatelessWidget {
  final UserModel usuario;
  final String nomeAtual;
  final String? foto;
  final bool enviandoFoto;
  final VoidCallback onEscolherFoto;

  const PerfilIdentidadeCard({
    super.key,
    required this.usuario,
    required this.nomeAtual,
    required this.foto,
    required this.enviandoFoto,
    required this.onEscolherFoto,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final u = usuario;
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 96,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Container(color: AppColors.heroBg),
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.15), shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.card, width: 4),
                          ),
                          child: Avatar(
                            nome: nomeAtual.isEmpty ? u.nome : nomeAtual,
                            foto: foto,
                            size: 96,
                            radius: 24,
                            bg: AppColors.mint,
                            fg: AppColors.forest,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.card, width: 4),
                            ),
                            child: enviandoFoto
                                ? Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: AppColors.primaryBg, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: const Spinner(size: 16, color: Colors.white),
                                  )
                                : AppIconButton(
                                    icon: LucideIcons.camera,
                                    label: 'Alterar foto (JPG, PNG ou WebP, até 2 MB)',
                                    background: AppColors.primaryBg,
                                    foreground: Colors.white,
                                    onPressed: onEscolherFoto,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.nome, style: AppText.display(24, weight: FontWeight.w700)),
                      Text(u.cargo?.isNotEmpty == true ? u.cargo! : 'Cargo não informado',
                          style: AppText.sans(14, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Pill('ID #${u.id}', tone: PillTone.sage),
                        Pill(u.perfil, tone: u.isAdmin ? PillTone.forest : PillTone.sage),
                        const Pill('Sessão ativa', tone: PillTone.ok, dot: true),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PerfilContaCard extends StatelessWidget {
  final UserModel usuario;
  final String formatoData;
  final bool confirmarSaida;
  final bool saindo;
  final VoidCallback onPedirConfirmacao;
  final VoidCallback onCancelarSaida;
  final VoidCallback onConfirmarSaida;

  const PerfilContaCard({
    super.key,
    required this.usuario,
    required this.formatoData,
    required this.confirmarSaida,
    required this.saindo,
    required this.onPedirConfirmacao,
    required this.onCancelarSaida,
    required this.onConfirmarSaida,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final u = usuario;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Conta', style: AppText.display(15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          InfoRow('Membro desde', fmtMesAno(u.membroDesde)),
          const SizedBox(height: 8),
          InfoRow('Último acesso', fmtData(u.ultimoAcesso, formato: formatoData, hora: true)),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: confirmarSaida
                ? Wrap(spacing: 8, runSpacing: 8, children: [
                    AppButton('Cancelar',
                        size: ButtonSize.sm,
                        variant: ButtonVariant.secondary,
                        onPressed: saindo ? null : onCancelarSaida),
                    AppButton('Confirmar saída',
                        size: ButtonSize.sm,
                        variant: ButtonVariant.dangerSolid,
                        icon: LucideIcons.logOut,
                        loading: saindo,
                        loadingLabel: 'Saindo...',
                        onPressed: onConfirmarSaida),
                  ])
                : AppButton('Encerrar sessão',
                    size: ButtonSize.sm,
                    variant: ButtonVariant.danger,
                    icon: LucideIcons.logOut,
                    onPressed: onPedirConfirmacao),
          ),
        ],
      ),
    );
  }
}
