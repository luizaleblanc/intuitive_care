import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens do MVP (seção 3 da especificação).
abstract final class AppColors {
  static const forest = Color(0xFF113E32);
  static const forestHover = Color(0xFF0B2D24);
  static const mint = Color(0xFF4AD295);
  static const mintHover = Color(0xFF3CC286);
  static const lime = Color(0xFFC8F169);
  static const surface = Color(0xFFF2F4F3);
  static const card = Color(0xFFFFFFFF);
  static const sage = Color(0xFFDCE7E2);
  static const ok = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  /// Legendas pequenas (11px): tom mais escuro para contraste AA (seção 12).
  static const caption = Color(0xFF475569);

  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald700 = Color(0xFF047857);
  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const red300 = Color(0xFFFCA5A5);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber700 = Color(0xFFB45309);
  static const dsCard = Color(0xFFF6F8F7);

  /// Paleta das séries categóricas (rosca de modalidades).
  static const chart = [
    forest,
    mint,
    Color(0xFF8FBFA9),
    lime,
    Color(0xFF2C6E57),
    Color(0xFFB7D3C6),
    Color(0xFF6B8F80),
    Color(0xFF1E5A47),
  ];
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const lift = [
    BoxShadow(color: Color(0x2E113E32), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

abstract final class AppLayout {
  static const sidebar = 260.0;
  static const topbar = 64.0;
  static const gutter = 24.0;
  static const margin = 40.0;
  static const minDesktop = 1280.0;
  static const cardRadius = 16.0;
}

/// Estilos tipográficos (seção 3.3).
abstract final class AppText {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: size >= 20 ? -0.025 * size : 0,
        height: 1.2,
      );

  static TextStyle sans(double size,
          {FontWeight weight = FontWeight.w400, Color color = AppColors.ink, double? height, double? spacing}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

  static TextStyle mono(double size, {FontWeight weight = FontWeight.w600, Color color = AppColors.forest}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);

  static TextStyle heroValue({Color color = Colors.white}) => display(30, color: color);
  static TextStyle pageTitle() => display(28);
  static TextStyle cardTitle({Color color = AppColors.ink}) => display(17, weight: FontWeight.w700, color: color);
  static TextStyle eyebrow({Color color = AppColors.muted}) =>
      sans(11, weight: FontWeight.w700, color: color, spacing: 11 * 0.14);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      secondary: AppColors.mint,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.forest,
      selectionColor: Color(0x554AD295),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
      textStyle: AppText.sans(12, weight: FontWeight.w500, color: Colors.white),
    ),
  );
}
