import 'package:flutter/material.dart';

import '../../app/theme.dart';

Future<T?> showSideDrawer<T>(BuildContext context, {required WidgetBuilder builder, double width = 480}) {
  final dark = AppColors.watchDark(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withValues(alpha: dark ? 0.6 : 0.3),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: AppColors.card,
        elevation: 24,
        child: SizedBox(width: width, height: double.infinity, child: builder(ctx)),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Linha "rótulo à esquerda, valor à direita".
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.sans(14, color: AppColors.muted)),
        Text(value, style: AppText.sans(14, weight: FontWeight.w700)),
      ],
    );
  }
}
