import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';

class GlassAccentTokens {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final List<Color> darkBgGradient;
  final List<Color> lightBgGradient;

  const GlassAccentTokens({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.darkBgGradient,
    required this.lightBgGradient,
  });

  static GlassAccentTokens forPreset(GlassThemeAccentPreset preset) {
    switch (preset) {
      case GlassThemeAccentPreset.royalNebula:
        return const GlassAccentTokens(
          primary: Color(0xFF6366F1), // Indigo 500
          secondary: Color(0xFF8B5CF6), // Violet 500
          tertiary: Color(0xFF06B6D4), // Cyan 500
          darkBgGradient: <Color>[
            Color(0xFF060B19), // Deep Navy
            Color(0xFF0F1B3D), // Royal Midnight Blue
            Color(0xFF1E1B4B), // Deep Cosmic Purple
          ],
          lightBgGradient: <Color>[
            Color(0xFFEEF2FF),
            Color(0xFFE0E7FF),
            Color(0xFFF3E8FF),
          ],
        );
      case GlassThemeAccentPreset.cyberCyan:
        return const GlassAccentTokens(
          primary: Color(0xFF0EA5E9), // Sky 500
          secondary: Color(0xFF3B82F6), // Blue 500
          tertiary: Color(0xFF2DD4BF), // Teal 400
          darkBgGradient: <Color>[
            Color(0xFF040D1A),
            Color(0xFF0C2442),
            Color(0xFF172554),
          ],
          lightBgGradient: <Color>[
            Color(0xFFF0F9FF),
            Color(0xFFE0F2FE),
            Color(0xFFDBEAFE),
          ],
        );
      case GlassThemeAccentPreset.amethystGlow:
        return const GlassAccentTokens(
          primary: Color(0xFFA855F7), // Purple 500
          secondary: Color(0xFFEC4899), // Pink 500
          tertiary: Color(0xFF6366F1), // Indigo 500
          darkBgGradient: <Color>[
            Color(0xFF0D071A),
            Color(0xFF1E1038),
            Color(0xFF311042),
          ],
          lightBgGradient: <Color>[
            Color(0xFFFAF5FF),
            Color(0xFFF3E8FF),
            Color(0xFFFCE7F3),
          ],
        );
      case GlassThemeAccentPreset.emeraldAurora:
        return const GlassAccentTokens(
          primary: Color(0xFF10B981), // Emerald 500
          secondary: Color(0xFF06B6D4), // Cyan 500
          tertiary: Color(0xFF6366F1), // Indigo 500
          darkBgGradient: <Color>[
            Color(0xFF041318),
            Color(0xFF0A2636),
            Color(0xFF132A4A),
          ],
          lightBgGradient: <Color>[
            Color(0xFFECFDF5),
            Color(0xFFE0F2FE),
            Color(0xFFEEF2FF),
          ],
        );
    }
  }
}

class GlassTheme {
  static ThemeData buildDarkTheme(ThemeSettings settings) {
    final tokens = GlassAccentTokens.forPreset(settings.accentPreset);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: Brightness.dark,
      primary: tokens.primary,
      secondary: tokens.secondary,
      tertiary: tokens.tertiary,
      surface: const Color(0xFF0F172A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF070C1B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primary, width: 1.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B132B).withValues(alpha: 0.92),
        indicatorColor: tokens.primary.withValues(alpha: 0.28),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData buildLightTheme(ThemeSettings settings) {
    final tokens = GlassAccentTokens.forPreset(settings.accentPreset);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: Brightness.light,
      primary: tokens.primary,
      secondary: tokens.secondary,
      tertiary: tokens.tertiary,
      surface: const Color(0xFFF8FAFC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFEEF2FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.78),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.primary.withValues(alpha: 0.18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primary.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.primary, width: 1.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        indicatorColor: tokens.primary.withValues(alpha: 0.18),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static BoxDecoration backgroundDecoration({
    required BuildContext context,
    required ThemeSettings settings,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = GlassAccentTokens.forPreset(settings.accentPreset);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark ? tokens.darkBgGradient : tokens.lightBgGradient,
      ),
    );
  }
}
