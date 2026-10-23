import 'package:flutter/material.dart';

/// Design tokens mirrored from greenrev-web/tailwind.config.ts so the app and
/// the website read as one product.
class AppTheme {
  /// Bundled from assets/fonts — same face the website loads ("bauserif").
  static const String fontFamily = 'Bauserif';

  static const Color background = Color(0xFF050606);
  static const Color obsidian = Color(0xFF030404);
  static const Color cardBg = Color(0xFF0C0D0D);
  static const Color forest = Color(0xFF0B2B1B);
  static const Color emerald = Color(0xFF10B981);
  static const Color accent = Color(0xFFA3E635);
  static const Color accentDark = Color(0xFF4E7A06);
  static const Color textMain = Colors.white;
  static const Color textSubtle = Color(0xFFA0AAB2);
  static const Color goldAccent = Color(0xFFC7A43D);
  static const Color danger = Color(0xFFF87171);

  /// Hairline borders — web uses border-white/5 and border-white/10.
  static Color get hairline => Colors.white.withValues(alpha: 0.05);
  static Color get border => Colors.white.withValues(alpha: 0.10);

  static ThemeData get darkTheme {
    final base = ThemeData.dark().textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: textMain,
          displayColor: textMain,
        );

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      cardColor: cardBg,
      splashColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: textSubtle,
        surface: cardBg,
        error: danger,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      dividerColor: Colors.white10,
      textTheme: base.copyWith(
        displayLarge: base.displayLarge?.copyWith(fontSize: 48, height: 1.0, letterSpacing: -1),
        displayMedium: base.displayMedium?.copyWith(fontSize: 40, height: 1.0, letterSpacing: -0.5),
        displaySmall: base.displaySmall?.copyWith(fontSize: 32, height: 1.05),
        headlineMedium: base.headlineMedium?.copyWith(fontSize: 26, height: 1.1),
        titleLarge: base.titleLarge?.copyWith(fontSize: 20),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: base.bodyMedium?.copyWith(color: textSubtle, fontSize: 14, height: 1.45),
        bodySmall: base.bodySmall?.copyWith(color: textSubtle, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textMain,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.4,
        ),
        iconTheme: IconThemeData(color: textMain, size: 20),
      ),
      // Web primary CTA: white pill, black uppercase micro-label, turns accent on press.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return Colors.white.withValues(alpha: 0.5);
            if (states.contains(WidgetState.pressed)) return accent;
            return Colors.white;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.black),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20, horizontal: 28)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 11,
          )),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 11,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white54,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 10,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16),
        labelStyle: const TextStyle(color: textSubtle),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? accent : Colors.white24,
        ),
        suffixIconColor: Colors.white24,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accent)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: danger)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: danger)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111313),
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0C0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: obsidian,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // Helper styling methods

  /// Web glass card: bg-white/[0.02] border-white/5 rounded-3xl.
  static BoxDecoration glassBoxDecoration({
    Color? color,
    double radius = 24.0,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.06),
        width: borderWidth,
      ),
    );
  }

  static BoxDecoration accentGlowDecoration({
    Color glowColor = accent,
    double radius = 24.0,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.12),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
    );
  }
}
