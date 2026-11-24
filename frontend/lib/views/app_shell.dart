import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'shell/shell_sidebar.dart';
import 'shell/shell_topbar.dart';

export 'shell/user_avatar.dart' show Avatar;

/// Ações da Topbar registradas pela página ativa (ex.: "Exportar" do Colaborador).
class ShellActions extends ChangeNotifier {
  Future<void> Function()? _exportar;
  Future<void> Function()? get exportar => _exportar;

  void registrarExportacao(Future<void> Function()? acao) {
    _exportar = acao;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

/// Sidebar 260px + Topbar + conteúdo. Desktop-only: abaixo de 1280px rola na horizontal.
class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final pagina = ShellPage.fromLocation(location);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: LayoutBuilder(
        builder: (context, c) {
          final largura = c.maxWidth < AppLayout.minDesktop ? AppLayout.minDesktop : c.maxWidth;
          final conteudo = SizedBox(
            width: largura,
            height: c.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShellSidebar(ativa: pagina.rota),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppLayout.margin, 28, AppLayout.margin, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShellTopbar(rota: pagina.rota, titulo: pagina.titulo, subtitulo: pagina.subtitulo),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          if (c.maxWidth >= AppLayout.minDesktop) return conteudo;
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: conteudo),
          );
        },
      ),
    );
  }
}
