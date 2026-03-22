import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple-tarzı minimalist tasarım sistemi
class AppTheme {
  AppTheme._();

  // ── Renk Paleti ─────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color surfaceAlt = Color(0xFFF2F2F7);
  static const Color titleColor = Color(0xFF1D1D1F);
  static const Color bodyColor = Color(0xFF6E6E73);
  static const Color hintColor = Color(0xFFAEAEB2);
  static const Color border = Color(0xFFD2D2D7);
  static const Color divider = Color(0xFFE5E5EA);
  static const Color accent = Color(0xFFE53935);
  static const Color accentLight = Color(0xFFFF6B35);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);

  // ── Gradient ────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Gölge ───────────────────────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0x0A000000), // black 4%
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0x0F000000), // black 6%
          blurRadius: 16,
          offset: const Offset(0, 2),
        ),
      ];

  // ── ThemeData ───────────────────────────────────────
  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentLight,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: titleColor,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w700,
          fontSize: 34,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: bodyColor,
          fontSize: 17,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: bodyColor,
          fontSize: 15,
          height: 1.5,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: hintColor,
          fontSize: 13,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
        iconTheme: const IconThemeData(color: titleColor, size: 22),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: hintColor),
        prefixIconColor: hintColor,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}
