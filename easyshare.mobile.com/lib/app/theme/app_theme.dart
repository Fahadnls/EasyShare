import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color ink = Color(0xFF09111F);
  static const Color paper = Color(0xFFF4F9FF);
  static const Color paperStrong = Color(0xFFFFFFFF);
  static const Color sky = Color(0xFF39A9F1);
  static const Color skySoft = Color(0xFFDDF2FF);
  static const Color deepBlue = Color(0xFF1653B1);
  static const Color midnight = Color(0xFF1D2A3B);

  static ThemeData get light {
    final base = GoogleFonts.spaceGroteskTextTheme();
    final textTheme = base.copyWith(
      displaySmall: GoogleFonts.archivoBlack(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.08,
        color: ink,
      ),
      headlineMedium: GoogleFonts.archivo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: ink,
      ),
      headlineSmall: GoogleFonts.archivo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.55,
        color: ink,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: ink,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.45,
        color: ink.withValues(alpha: 0.72),
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: ink,
      ),
    );

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: sky,
      onPrimary: paperStrong,
      secondary: Color(0xFFFFB300),
      onSecondary: paperStrong,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: paperStrong,
      onSurface: ink,
      primaryContainer: skySoft,
      onPrimaryContainer: ink,
      secondaryContainer: Color(0xFFFFF2CC),
      onSecondaryContainer: ink,
      tertiary: deepBlue,
      onTertiary: paperStrong,
      tertiaryContainer: Color(0xFFD9E7FF),
      onTertiaryContainer: ink,
      surfaceContainerHighest: Color(0xFFEAF4FF),
      onSurfaceVariant: midnight,
      outline: Color(0xFFB6CADF),
      outlineVariant: Color(0xFFD5E4F2),
      inverseSurface: midnight,
      onInverseSurface: paperStrong,
      inversePrimary: skySoft,
      shadow: Color(0x1F000000),
      scrim: Color(0x52000000),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: paperStrong,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD5E4F2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepBlue,
          foregroundColor: paperStrong,
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: deepBlue,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperStrong,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD5E4F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD5E4F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: deepBlue, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: midnight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: paperStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: colorScheme.outlineVariant,
    );
  }
}
