import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import 'app_buttons.dart';

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBox(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.red50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 15, color: AppColors.red700),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: AppText.sans(14, color: AppColors.red700))),
            if (onRetry != null)
              AppButton('Tentar novamente', size: ButtonSize.sm, variant: ButtonVariant.secondary, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class LoadingBlock extends StatelessWidget {
  final String label;
  final double height;
  const LoadingBlock({super.key, this.label = 'Carregando...', this.height = 240});

  @override
  Widget build(BuildContext context) {
    AppColors.watchDark(context);
    return SizedBox(
      height: height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spinner(size: 18),
            const SizedBox(width: 10),
            Text(label, style: AppText.sans(14, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// Toast centralizado embaixo, some em 2,2s (seção 8).
class ToastController extends ChangeNotifier {
  String? _message;
  bool _error = false;
  Timer? _timer;

  String? get message => _message;
  bool get isError => _error;

  void show(String message, {bool error = false}) {
    _message = message;
    _error = error;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      _message = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ToastOverlay extends StatelessWidget {
  final ToastController controller;
  final Widget child;
  const ToastOverlay({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.watchDark(context);
    return Stack(
      children: [
        child,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final msg = controller.message;
            return Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: msg == null
                      ? const SizedBox.shrink()
                      : Center(
                          key: ValueKey(msg),
                          child: Semantics(
                            liveRegion: true,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.toastBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: dark ? Border.all(color: AppColors.slate200) : null,
                                  boxShadow: AppShadows.lift,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(controller.isError ? LucideIcons.circleAlert : LucideIcons.circleCheck,
                                        size: 16, color: controller.isError ? AppColors.red300 : AppColors.mint),
                                    const SizedBox(width: 8),
                                    Text(msg, style: AppText.sans(14, weight: FontWeight.w500, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
