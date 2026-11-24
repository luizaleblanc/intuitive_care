import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/utils/formatters.dart';

/// Chip clicável com avatar, nome e perfil do usuário autenticado na topbar.
class UserChip extends StatefulWidget {
  final String nome;
  final String perfil;
  final String? foto;

  const UserChip({super.key, required this.nome, required this.perfil, this.foto});

  @override
  State<UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<UserChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    return Semantics(
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(999),
              border: dark ? Border.all(color: AppColors.cardBorder) : null,
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
                child: Text(
                  iniciais(nome),
                  style: size > 60
                      ? AppText.display(size * 0.31, color: fg)
                      : AppText.sans(size * 0.37, weight: FontWeight.w700, color: fg),
                ),
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
