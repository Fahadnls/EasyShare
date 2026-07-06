import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/ui_constants.dart';

class AppTheme {
  static const Color sky = Color(0xFF39A9F1);
  static const Color deepBlue = Color(0xFF1653B1);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF62C2FF),
            onPrimary: Color(0xFF00344F),
            secondary: Color(0xFFFFC247),
            onSecondary: Color(0xFF3E2E00),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            surface: Color(0xFF121B26),
            onSurface: Color(0xFFEDF4FF),
            primaryContainer: Color(0xFF174766),
            onPrimaryContainer: Color(0xFFD8EFFF),
            secondaryContainer: Color(0xFF574500),
            onSecondaryContainer: Color(0xFFFFE08A),
            tertiary: Color(0xFFAEC7FF),
            onTertiary: Color(0xFF002F66),
            tertiaryContainer: Color(0xFF163E75),
            onTertiaryContainer: Color(0xFFD8E4FF),
            surfaceContainerHighest: Color(0xFF253445),
            onSurfaceVariant: Color(0xFFC8D5E3),
            outline: Color(0xFF718398),
            outlineVariant: Color(0xFF33465A),
            inverseSurface: Color(0xFFEDF4FF),
            onInverseSurface: Color(0xFF17212D),
            inversePrimary: deepBlue,
            shadow: Color(0x66000000),
            scrim: Color(0xA6000000),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: sky,
            onPrimary: Colors.white,
            secondary: Color(0xFFFFB300),
            onSecondary: Colors.white,
            error: Color(0xFFB3261E),
            onError: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF09111F),
            primaryContainer: Color(0xFFDDF2FF),
            onPrimaryContainer: Color(0xFF09111F),
            secondaryContainer: Color(0xFFFFF2CC),
            onSecondaryContainer: Color(0xFF09111F),
            tertiary: deepBlue,
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFD9E7FF),
            onTertiaryContainer: Color(0xFF09111F),
            surfaceContainerHighest: Color(0xFFEAF4FF),
            onSurfaceVariant: Color(0xFF1D2A3B),
            outline: Color(0xFFB6CADF),
            outlineVariant: Color(0xFFD5E4F2),
            inverseSurface: Color(0xFF1D2A3B),
            onInverseSurface: Colors.white,
            inversePrimary: Color(0xFFDDF2FF),
            shadow: Color(0x1F000000),
            scrim: Color(0x52000000),
          );

    final base = GoogleFonts.spaceGroteskTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final textColor = scheme.onSurface;
    final textTheme = base.copyWith(
      displaySmall: GoogleFonts.archivoBlack(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.08,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.archivo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.archivo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: textColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: textColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.55,
        color: textColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: textColor,
      ),
    );

    final buttonColor = isDark ? scheme.primary : deepBlue;
    final onButtonColor = isDark ? scheme.onPrimary : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B121B) : Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(kBorderRadius + 8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: onButtonColor,
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: buttonColor, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: buttonColor,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
        ),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}
