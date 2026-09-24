import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF2D5BE3);
  static const Color primaryDark = Color(0xFF1A3DA8);
  // Deepened from the original #00C49A — same family, less "neon startup
  // mint", more jewel-toned. Every screen already using AppTheme.accent
  // (referral, chips, dividers) picks this up automatically.
  static const Color accent = Color(0xFF0DAA8C);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF43A047);

  // Muted gold — reserved for genuinely premium/exclusive moments (unlock
  // states, premium badges, ratings). Used sparingly on purpose: a color
  // that means "premium" everywhere it appears loses that meaning if it's
  // used as generic decoration.
  static const Color premium = Color(0xFFC9962E);
  static const Color premiumLight = Color(0xFFE8C877);

  static const Color surfaceLight = Color(0xFFF8F9FE);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  static const Color surfaceDark = Color(0xFF0F1117);
  static const Color cardDark = Color(0xFF1A1D27);
  static const Color borderDark = Color(0xFF2A2D3E);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surfaceLight,
      error: error,
    ),
    scaffoldBackgroundColor: surfaceLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: cardLight,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
      labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceLight,
      selectedColor: primary.withOpacity(0.1),
      labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surfaceDark,
      error: error,
    ),
    scaffoldBackgroundColor: surfaceDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: cardDark,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderDark, thickness: 1),
  );

  // ── Theme-aware helpers ────────────────────────────────────────────────
  // A handful of screens were built assuming a permanent dark background
  // (hardcoded Colors.white/white54/white30 etc.), which breaks the moment
  // the app is actually in light mode. These helpers give a single place to
  // resolve the right color for the CURRENT theme instead of repeating
  // "Theme.of(context).brightness == Brightness.dark ? a : b" everywhere.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBg(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? cardDark : cardLight;

  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  /// Primary text — white in dark mode, near-black in light mode.
  static Color textMain(BuildContext context) =>
      isDark(context) ? Colors.white : textPrimary;

  /// Secondary/muted text — readable on both a dark navy and a light surface.
  static Color textMuted(BuildContext context) =>
      isDark(context) ? Colors.white54 : textSecondary;

  /// A quiet card fill for flat cards that used to assume a dark backdrop
  /// (e.g. Colors.white.withOpacity(0.05)) — tuned to read on either theme.
  static Color subtleFill(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.06)
      : Colors.black.withOpacity(0.035);

  static Color subtleBorder(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.10)
      : Colors.black.withOpacity(0.08);

  static Color faintIcon(BuildContext context) =>
      isDark(context) ? Colors.white30 : const Color(0xFFC7CCD6);

  /// Consistent "lifted card" shadow. Dark UIs generally read better with
  /// borders/lightness for depth rather than drop shadows, so this is a
  /// no-op in dark mode by design — not a missing case.
  static List<BoxShadow> elevation(
    BuildContext context, {
    double strength = 1,
  }) => isDark(context)
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05 * strength),
            blurRadius: 18 * strength,
            offset: Offset(0, 6 * strength),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03 * strength),
            blurRadius: 4 * strength,
            offset: Offset(0, 1 * strength),
          ),
        ];
}
