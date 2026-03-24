import 'package:flutter/material.dart';

class AppPalette {
  static const shellBackground = Color(0xFF1A0815);
  static const shellBackgroundDeep = Color(0xFF2B0E22);
  static const background = Color(0xFF170813);
  static const panel = Color(0xFF26111E);
  static const panelStrong = Color(0xFF351827);
  static const line = Color(0xFF5E2E46);

  static const rose = Color(0xFFFF5E95);
  static const peach = Color(0xFFFFA86B);
  static const gold = Color(0xFFFFD36F);
  static const plum = Color(0xFF7F3F73);
  static const mint = Color(0xFFC9F5D2);
  static const danger = Color(0xFFFF6F7E);
  static const text = Color(0xFFFFF6FA);
  static const muted = Color(0xFFD8B4C7);

  // Compatibility aliases for existing screens.
  static const cyan = rose;
  static const teal = peach;
  static const orange = gold;
}

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.rose,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      colorScheme: scheme.copyWith(
        primary: AppPalette.rose,
        secondary: AppPalette.gold,
        tertiary: AppPalette.peach,
        surface: AppPalette.panel,
      ),
      scaffoldBackgroundColor: AppPalette.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppPalette.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppPalette.peach.withValues(alpha: 0.10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: const TextStyle(color: AppPalette.muted),
        hintStyle: TextStyle(color: AppPalette.muted.withValues(alpha: 0.76)),
        prefixIconColor: AppPalette.rose,
        suffixIconColor: AppPalette.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppPalette.peach.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.rose, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppPalette.rose,
          disabledBackgroundColor: AppPalette.plum.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.text,
          side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.24)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.gold),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.panelStrong,
        contentTextStyle: const TextStyle(color: AppPalette.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        side: BorderSide(color: AppPalette.peach.withValues(alpha: 0.20)),
        selectedColor: AppPalette.rose.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppPalette.rose,
        unselectedItemColor: AppPalette.muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.rose,
      ),
    );
  }
}
