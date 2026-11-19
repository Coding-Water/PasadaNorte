import 'package:flutter/material.dart';

/// Unified design tokens and light/dark themes for PasadaNorte Web Command Center.
class WebTheme {
  // Core & Accent Palette (2 core + 1 accent + semantic tokens)
  static const Color brandEmerald = Color(0xFF007A37); // 5.47:1 on white
  static const Color brandEmeraldDeep = Color(0xFF065F46);
  static const Color brandMintSurface = Color(0xFFE8F8EF);

  static const Color inkPrimary = Color(0xFF0F172A);
  static const Color inkSecondary = Color(0xFF475569);
  static const Color inkMuted = Color(0xFF64748B); // 4.76:1 on white

  static const Color surfaceCanvas = Color(0xFFF8FAFC);
  static const Color surfaceCard = Colors.white;
  static const Color borderSubtle = Color(0xFFE2E8F0);

  // Semantic Status Tokens
  static const Color amberText = Color(0xFFB45309);
  static const Color amberFill = Color(0xFFFEF3C7);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerSolid = Color(0xFFDC2626);
  static const Color dangerFill = Color(0xFFFEE2E2);
  static const Color infoText = Color(0xFF0369A1);
  static const Color infoFill = Color(0xFFE0F2FE);

  // Dark Mode Tokens
  static const Color darkCanvas = Color(0xFF0B1220);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkInkPrimary = Color(0xFFF8FAFC);
  static const Color darkInkSecondary = Color(0xFFCBD5E1);

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static void toggleTheme() {
    themeModeNotifier.value = themeModeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandEmerald,
        primary: brandEmerald,
        secondary: amberText,
        surface: surfaceCard,
        brightness: Brightness.light,
      ),
      dividerColor: borderSubtle,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandEmerald,
        primary: const Color(0xFF22C55E),
        secondary: const Color(0xFFFCD34D),
        surface: darkCard,
        brightness: Brightness.dark,
      ),
      dividerColor: darkBorder,
    );
  }
}
