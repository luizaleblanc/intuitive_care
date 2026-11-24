import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/ui/ui.dart';
import '../../shared/utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/painel_viewmodel.dart';
import '../app_shell.dart' show ShellActions;
import 'user_avatar.dart' show UserChip;

/// Barra superior do shell com título da página, busca global, exportação e chip do usuário.
class ShellTopbar extends StatefulWidget {
  final String rota;
  final String titulo;
  final String subtitulo;

  const ShellTopbar({
    super.key,
    required this.rota,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  State<ShellTopbar> createState() => _ShellTopbarState();
}

class _ShellTopbarState extends State<ShellTopbar> {
  bool _exportando = false;

  String _subtituloAtual(BuildContext context) {
    if (widget.rota != '/painel') return widget.subtitulo;
    final p = context.watch<PainelViewModel>().painel?.periodo;
    return p != null ? '${widget.subtitulo} · ${fmtPeriodo(p.ano, p.trimestre)}' : widget.subtitulo;
  }

  void _buscarGlobal(BuildContext context, String query) {
    final termo = query.trim();
    if (termo.isEmpty) return;
    // Códigos de conta (2 a 5 dígitos) levam ao plano de contas; demais buscas, às operadoras.
    if (RegExp(r'^\d{2,5}$').hasMatch(termo) && termo.startsWith(RegExp('[34]'))) {
      context.go('/despesas?conta=$termo');
    } else {
      context.go('/operadoras?q=${Uri.encodeQueryComponent(termo)}');
    }
  }

  Future<void> _executarExportacao(Future<void> Function() exportar) async {
    setState(() => _exportando = true);
    try {
      await exportar();
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final user = context.watch<AuthViewModel>().currentUser;
    final acoes = context.watch<ShellActions>();
    // Exportação é exclusiva do perfil Administrador (permissão dados.exportar).
    final mostrarExportar = widget.rota != '/perfil' &&
        acoes.exportar != null &&
        (user?.pode('dados.exportar') ?? false);
    final subtitulo = _subtituloAtual(context);

    return SizedBox(
      height: AppLayout.topbar,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(widget.titulo,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.pageTitle()),
                ),
                const SizedBox(height: 2),
                Text(subtitulo,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(14, color: AppColors.muted)),
              ],
            ),
          ),
          SearchInput(
            value: '',
            width: 300,
            placeholder: 'Buscar operadora, CNPJ, conta...',
            onChanged: (_) {},
            onSubmitted: (q) => _buscarGlobal(context, q),
          ),
          if (mostrarExportar) ...[
            const SizedBox(width: 12),
            AppButton(
              'Exportar',
              variant: ButtonVariant.secondary,
              icon: LucideIcons.download,
              loading: _exportando,
              loadingLabel: 'Exportando...',
              onPressed: () => _executarExportacao(acoes.exportar!),
            ),
          ],
          const SizedBox(width: 12),
          if (user != null) UserChip(nome: user.nome, perfil: user.perfil, foto: user.foto),
        ],
      ),
    );
  }
}
