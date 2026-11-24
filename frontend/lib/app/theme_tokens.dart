import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens do MVP (seção 3 da especificação) com suporte completo ao modo escuro.
abstract final class AppColors {
  /// Estado global sincronizado pelo `ThemeController` e pelo `AppThemeScope`.
  static bool isDark = false;

  /// Leitor opcional do escopo herdado de tema, registrado por `AppThemeScope` / `ThemeController`.
  static bool? Function(BuildContext context)? scopeReader;

  /// Lê o brilho atual do escopo de tema (ou [Theme] em testes isolados),
  /// subscrevendo o widget a trocas imediatas de tema.
  static bool watchDark(BuildContext context) {
    final scoped = scopeReader?.call(context);
    final dark = scoped ?? (Theme.of(context).brightness == Brightness.dark);
    isDark = dark;
    return dark;
  }

  // Cores institucionais fixas (símbolo, acentos e cartões hero).
  static const forest = Color(0xFF113E32);
  static const forestHover = Color(0xFF0B2D24);
  static const mint = Color(0xFF4AD295);
  static const mintHover = Color(0xFF3CC286);
  static const lime = Color(0xFFC8F169);
  static const ok = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  // Superfícies e fundos adaptativos.
  static Color get surface => isDark ? const Color(0xFF0B1210) : const Color(0xFFF2F4F3);
  static Color get pageBg => isDark ? const Color(0xFF0B1210) : const Color(0xFFFFFFFF);
  static Color get card => isDark ? const Color(0xFF121E1A) : const Color(0xFFFFFFFF);
  static Color get cardHover => isDark ? const Color(0xFF192A24) : const Color(0xFFF8FAFC);
  static Color get inputFill => isDark ? const Color(0xFF16241F) : const Color(0xFFFFFFFF);
  static Color get cardBorder => isDark ? const Color(0xFF22362E) : Colors.transparent;
  static Color get sage => isDark ? const Color(0xFF182B24) : const Color(0xFFDCE7E2);
  static Color get sageText => isDark ? const Color(0xFFD8EFE5) : forest;
  static Color get sageMuted => isDark ? const Color(0xFF94B8A8) : forest.withValues(alpha: 0.75);
  static Color get dsCard => isDark ? const Color(0xFF16241F) : const Color(0xFFF6F8F7);
  static Color get toastBg => isDark ? const Color(0xFF1D312A) : const Color(0xFF0F172A);

  // Ações primárias e texto institucional (alto contraste sobre fundo claro ou escuro).
  static Color get primaryBg => isDark ? const Color(0xFF185746) : forest;
  static Color get primaryHover => isDark ? const Color(0xFF1F6B57) : forestHover;
  static Color get heroBg => isDark ? const Color(0xFF0F352B) : forest;
  static Color get brandText => isDark ? mint : forest;

  // Tipografia e neutros adaptativos.
  static Color get ink => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get muted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// Legendas pequenas (11px): contraste AA em ambos os modos (seção 12).
  static Color get caption => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

  static Color get slate100 => isDark ? const Color(0xFF1C2D27) : const Color(0xFFF1F5F9);
  static Color get slate200 => isDark ? const Color(0xFF263B34) : const Color(0xFFE2E8F0);
  static Color get slate300 => isDark ? const Color(0xFF365148) : const Color(0xFFCBD5E1);
  static Color get slate600 => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static Color get slate700 => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

  // Tons semânticos (pills, alertas e botões de perigo).
  static Color get emerald50 => isDark ? const Color(0xFF103326) : const Color(0xFFECFDF5);
  static Color get emerald700 => isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
  static Color get red50 => isDark ? const Color(0xFF35161B) : const Color(0xFFFEF2F2);
  static Color get red200 => isDark ? const Color(0xFF6B252E) : const Color(0xFFFECACA);
  static Color get red300 => isDark ? const Color(0xFF993542) : const Color(0xFFFCA5A5);
  static Color get red600 => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get red700 => isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
  static Color get amber50 => isDark ? const Color(0xFF332510) : const Color(0xFFFFFBEB);
  static Color get amber700 => isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);

  static const _chartLight = [
    forest, mint, Color(0xFF8FBFA9), lime,
    Color(0xFF2C6E57), Color(0xFFB7D3C6), Color(0xFF6B8F80), Color(0xFF1E5A47),
  ];

  static const _chartDark = [
    mint, lime, Color(0xFF5EEAD4), Color(0xFF38BDF8),
    Color(0xFF86EFAC), Color(0xFFA7F3D0), Color(0xFF34D399), Color(0xFF2DD4BF),
  ];

  /// Paleta das séries categóricas (rosca de modalidades).
  static List<Color> get chart => isDark ? _chartDark : _chartLight;
}

abstract final class AppShadows {
  static List<BoxShadow> get card => AppColors.isDark
      ? const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x2E000000), blurRadius: 16, offset: Offset(0, 4)),
        ]
      : const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4)),
        ];

  static List<BoxShadow> get lift => AppColors.isDark
      ? const [
          BoxShadow(color: Color(0x52000000), blurRadius: 28, offset: Offset(0, 10)),
        ]
      : const [
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
  static TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        letterSpacing: size >= 20 ? -0.025 * size : 0,
        height: 1.2,
      );

  static TextStyle sans(double size,
          {FontWeight weight = FontWeight.w400, Color? color, double? height, double? spacing}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        height: height,
        letterSpacing: spacing,
      );

  /// Números financeiros, percentuais e anos: algarismos tabulares (mesma largura).
  static TextStyle numeric(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      sans(size, weight: weight, color: color ?? AppColors.ink)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle mono(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? AppColors.brandText);

  static TextStyle heroValue({Color color = Colors.white}) => display(30, color: color);
  static TextStyle pageTitle() => display(28);
  static TextStyle cardTitle({Color? color}) => display(17, weight: FontWeight.w700, color: color ?? AppColors.ink);
  static TextStyle eyebrow({Color? color}) =>
      sans(11, weight: FontWeight.w700, color: color ?? AppColors.muted, spacing: 11 * 0.14);
}

WidgetStateProperty<Color?> _selectColor(Color selected, Color fallback, {Color? disabled}) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return selected;
      if (disabled != null && states.contains(WidgetState.disabled)) return disabled;
      return fallback;
    });

ThemeData buildAppTheme({bool dark = false}) {
  final surface = dark ? const Color(0xFF0B1210) : const Color(0xFFF2F4F3);
  final card = dark ? const Color(0xFF121E1A) : const Color(0xFFFFFFFF);
  final ink = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  final border = dark ? const Color(0xFF263B34) : const Color(0xFFE2E8F0);
  final primary = dark ? AppColors.mint : AppColors.forest;
  final onPrimary = dark ? AppColors.forest : Colors.white;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: AppColors.mint,
    surface: card,
    onSurface: ink,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    canvasColor: card,
    dividerColor: border,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: dark ? AppColors.mint : AppColors.forest,
      selectionColor: const Color(0x554AD295),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: ink),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: dark ? const Color(0xFF0F352B) : AppColors.forest,
      headerForegroundColor: Colors.white,
      dayForegroundColor: _selectColor(onPrimary, ink, disabled: muted.withValues(alpha: 0.45)),
      dayBackgroundColor: _selectColor(primary, Colors.transparent),
      todayForegroundColor: WidgetStatePropertyAll(primary),
      todayBorder: BorderSide(color: primary),
      weekdayStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
      yearForegroundColor: _selectColor(onPrimary, ink),
      yearBackgroundColor: _selectColor(primary, Colors.transparent),
    ),
    popupMenuTheme: PopupMenuThemeData(color: card, surfaceTintColor: Colors.transparent),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: dark ? const Color(0xFF365148) : const Color(0xFFCBD5E1), width: 1.5),
      checkColor: WidgetStatePropertyAll(onPrimary),
      fillColor: _selectColor(primary, Colors.transparent),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(muted.withValues(alpha: dark ? 0.45 : 0.35)),
      radius: const Radius.circular(999),
      thickness: const WidgetStatePropertyAll(6),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1D312A) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        border: dark ? Border.all(color: const Color(0xFF2E4B40)) : null,
      ),
      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
    ),
  );
}
