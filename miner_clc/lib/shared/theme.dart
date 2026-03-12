import 'package:flutter/material.dart';

class MinerColors {
  static const background = Color(0xFF4A4A4A);
  static const sidebar = Color(0xFF2E2E2E);
  static const button = Color(0xFF1E1E1E);
  static const text = Colors.white;
  static const textWithAlpha = Color.fromARGB(180, 255, 255, 255);
  static const accent = Color(0xFF4A90D9);

  static const card = Color(0xFF3B3B3B);
  static const border = Color(0xFF5A5A5A);

  static const ok = Color(0xFF2ECC71);
  static const warn = Color(0xFFF1C40F);
  static const danger = Color(0xFFE74C3C);
}

ThemeData buildMinerTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: MinerColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: MinerColors.accent,
      secondary: MinerColors.accent,
      surface: MinerColors.card,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: MinerColors.text,
      displayColor: MinerColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MinerColors.sidebar,
      foregroundColor: MinerColors.text,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: MinerColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MinerColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MinerColors.button,
        foregroundColor: MinerColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MinerColors.button,
      labelStyle: const TextStyle(color: MinerColors.text),
      hintStyle: TextStyle(color: MinerColors.text.withValues(alpha: 0.65)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MinerColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MinerColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MinerColors.accent, width: 2),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(MinerColors.sidebar),
      dataRowColor: WidgetStatePropertyAll(MinerColors.card),
      headingTextStyle: const TextStyle(
        color: MinerColors.text,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: const TextStyle(color: MinerColors.text),
      dividerThickness: 0.8,
    ),
  );
}

