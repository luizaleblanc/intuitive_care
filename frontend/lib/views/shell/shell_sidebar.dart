import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../shared/brand/brand.dart';

/// Metadados das rotas autenticadas exibidas na navegação lateral e na topbar.
class ShellPage {
  final String rota;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final String menu;

  const ShellPage(this.rota, this.titulo, this.subtitulo, this.icone, this.menu);

  static const List<ShellPage> todas = [
    ShellPage('/painel', 'Painel Geral', 'Dashboard ANS & ETL', LucideIcons.layoutDashboard, 'Painel Geral'),
    ShellPage(
      '/explorar',
      'Explorar dados',
      'Período, filtros avançados e gráficos personalizados',
      LucideIcons.chartNoAxesCombined,
      'Explorar dados',
    ),
    ShellPage(
      '/operadoras',
      'Operadoras ANS',
      'Catálogo de operadoras com registro na ANS',
      LucideIcons.building2,
      'Operadoras ANS',
    ),
    ShellPage(
      '/despesas',
      'Despesas Contábeis',
      'Demonstrações contábeis e despesas assistenciais',
      LucideIcons.receipt,
      'Despesas Contábeis',
    ),
    ShellPage(
      '/perfil',
      'Configurações de Perfil',
      'Dados pessoais, foto e preferências',
      LucideIcons.userCog,
      'Configurações de Perfil',
    ),
  ];

  static ShellPage fromLocation(String location) =>
      todas.firstWhere((p) => location.startsWith(p.rota), orElse: () => todas.first);
}

/// Barra lateral fixa de 260px com logotipo e grupos de navegação do shell.
class ShellSidebar extends StatelessWidget {
  final String ativa;

  const ShellSidebar({super.key, required this.ativa});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Container(
      width: AppLayout.sidebar,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(right: BorderSide(color: AppColors.slate200.withValues(alpha: 0.8))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => context.go('/painel'),
                child: const FittedBox(fit: BoxFit.scaleDown, child: LogoHorizontal(size: 36)),
              ),
            ),
          ),
          _grupo('MENU', [
            for (final p in ShellPage.todas.where((p) => p.rota != '/perfil'))
              _SidebarItem(pagina: p, ativa: ativa == p.rota),
          ]),
          _grupo('CONTA', [
            _SidebarItem(pagina: ShellPage.todas.last, ativa: ativa == ShellPage.todas.last.rota),
          ]),
        ],
      ),
    );
  }

  Widget _grupo(String rotulo, List<Widget> itens) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(rotulo, style: AppText.eyebrow(color: AppColors.caption)),
            ),
            for (final i in itens) Padding(padding: const EdgeInsets.only(bottom: 4), child: i),
          ],
        ),
      );
}

class _SidebarItem extends StatefulWidget {
  final ShellPage pagina;
  final bool ativa;

  const _SidebarItem({required this.pagina, required this.ativa});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    final ativa = widget.ativa;
    final cor = ativa ? Colors.white : (_hover ? AppColors.ink : AppColors.slate600);
    return Semantics(
      selected: ativa,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => context.go(widget.pagina.rota),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ativa ? AppColors.primaryBg : (_hover ? AppColors.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(widget.pagina.icone, size: 17, color: cor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.pagina.menu,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(14, weight: FontWeight.w500, color: cor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
