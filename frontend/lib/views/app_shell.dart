import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../shared/brand/brand.dart';
import '../shared/ui/ui.dart';
import '../shared/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/painel_viewmodel.dart';

/// Ações da Topbar registradas pela página ativa (ex.: "Exportar" do Colaborador).
class ShellActions extends ChangeNotifier {
  Future<void> Function()? _exportar;
  Future<void> Function()? get exportar => _exportar;

  void registrarExportacao(Future<void> Function()? acao) {
    _exportar = acao;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

class _Pagina {
  final String rota;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final String menu;
  const _Pagina(this.rota, this.titulo, this.subtitulo, this.icone, this.menu);
}

const _paginas = [
  _Pagina('/painel', 'Painel Geral', 'Dashboard ANS & ETL', LucideIcons.layoutDashboard, 'Painel Geral'),
  _Pagina('/explorar', 'Explorar dados', 'Período, filtros avançados e gráficos personalizados',
      LucideIcons.chartNoAxesCombined, 'Explorar dados'),
  _Pagina('/operadoras', 'Operadoras ANS', 'Catálogo de operadoras com registro na ANS', LucideIcons.building2,
      'Operadoras ANS'),
  _Pagina('/despesas', 'Despesas Contábeis', 'Demonstrações contábeis e despesas assistenciais', LucideIcons.receipt,
      'Despesas Contábeis'),
  _Pagina('/perfil', 'Configurações de Perfil', 'Dados pessoais, foto e preferências', LucideIcons.userCog,
      'Configurações de Perfil'),
];

/// Sidebar 260px + Topbar + conteúdo. Desktop-only: abaixo de 1280px rola na horizontal.
class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final pagina = _paginas.firstWhere((p) => location.startsWith(p.rota), orElse: () => _paginas.first);
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
                _Sidebar(ativa: pagina.rota),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppLayout.margin, 28, AppLayout.margin, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Topbar(pagina: pagina),
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

class _Sidebar extends StatelessWidget {
  final String ativa;
  const _Sidebar({required this.ativa});

  @override
  Widget build(BuildContext context) => Container(
        width: AppLayout.sidebar,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.slate200.withValues(alpha: 0.7))),
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
              for (final p in _paginas.where((p) => p.rota != '/perfil')) _Item(pagina: p, ativa: ativa == p.rota),
            ]),
            _grupo('CONTA', [_Item(pagina: _paginas.last, ativa: ativa == _paginas.last.rota)]),
          ],
        ),
      );

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

class _Item extends StatefulWidget {
  final _Pagina pagina;
  final bool ativa;
  const _Item({required this.pagina, required this.ativa});

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
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
              color: ativa ? AppColors.forest : (_hover ? AppColors.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(widget.pagina.icone, size: 17, color: cor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.pagina.menu,
                      overflow: TextOverflow.ellipsis, style: AppText.sans(14, weight: FontWeight.w500, color: cor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Topbar extends StatefulWidget {
  final _Pagina pagina;
  const _Topbar({required this.pagina});

  @override
  State<_Topbar> createState() => _TopbarState();
}

class _TopbarState extends State<_Topbar> {
  bool _exportando = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final acoes = context.watch<ShellActions>();
    // Exportação é exclusiva do perfil Administrador (permissão dados.exportar).
    final mostrarExportar = widget.pagina.rota != '/perfil' &&
        acoes.exportar != null &&
        (user?.pode('dados.exportar') ?? false);

    var subtitulo = widget.pagina.subtitulo;
    if (widget.pagina.rota == '/painel') {
      final p = context.watch<PainelViewModel>().painel?.periodo;
      if (p != null) subtitulo = '$subtitulo · ${fmtPeriodo(p.ano, p.trimestre)}';
    }

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
                  child: Text(widget.pagina.titulo,
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
            onSubmitted: (q) {
              final termo = q.trim();
              if (termo.isEmpty) return;
              // Códigos de conta (2 a 5 dígitos) levam ao plano de contas; demais buscas, às operadoras.
              if (RegExp(r'^\d{2,5}$').hasMatch(termo) && termo.startsWith(RegExp('[34]'))) {
                context.go('/despesas?conta=$termo');
              } else {
                context.go('/operadoras?q=${Uri.encodeQueryComponent(termo)}');
              }
            },
          ),
          if (mostrarExportar) ...[
            const SizedBox(width: 12),
            AppButton(
              'Exportar',
              variant: ButtonVariant.secondary,
              icon: LucideIcons.download,
              loading: _exportando,
              loadingLabel: 'Exportando...',
              onPressed: () async {
                setState(() => _exportando = true);
                try {
                  await acoes.exportar!();
                } finally {
                  if (mounted) setState(() => _exportando = false);
                }
              },
            ),
          ],
          const SizedBox(width: 12),
          if (user != null) _UserChip(nome: user.nome, perfil: user.perfil, foto: user.foto),
        ],
      ),
    );
  }
}

class _UserChip extends StatefulWidget {
  final String nome;
  final String perfil;
  final String? foto;
  const _UserChip({required this.nome, required this.perfil, this.foto});

  @override
  State<_UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<_UserChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Abrir perfil de ${widget.nome}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: () => context.go('/perfil'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: _hover ? AppShadows.lift : AppShadows.card,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(nome: widget.nome, foto: widget.foto, size: 32),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.nome, style: AppText.sans(14, weight: FontWeight.w600, height: 1.2)),
                      Text(widget.perfil, style: AppText.sans(11, color: AppColors.caption, height: 1.2)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Avatar com foto (data URL) ou iniciais em Mint sobre Forest.
class Avatar extends StatelessWidget {
  final String nome;
  final String? foto;
  final double size;
  final double radius;
  final Color bg;
  final Color fg;

  const Avatar({
    super.key,
    required this.nome,
    this.foto,
    this.size = 32,
    this.radius = 999,
    this.bg = AppColors.forest,
    this.fg = AppColors.mint,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodificar(foto);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                color: bg,
                alignment: Alignment.center,
                child: Text(iniciais(nome),
                    style: size > 60
                        ? AppText.display(size * 0.31, color: fg)
                        : AppText.sans(size * 0.37, weight: FontWeight.w700, color: fg)),
              ),
      ),
    );
  }

  static final _cache = <String, dynamic>{};

  static dynamic _decodificar(String? foto) {
    if (foto == null || !foto.startsWith('data:image')) return null;
    return _cache.putIfAbsent(foto, () {
      try {
        return base64Decode(foto.substring(foto.indexOf(',') + 1));
      } catch (_) {
        return null;
      }
    });
  }
}
