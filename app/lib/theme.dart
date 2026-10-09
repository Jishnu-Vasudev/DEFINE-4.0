import 'package:flutter/material.dart';

// Same palette as the admin console so the product feels like one system.
class C {
  static const bg = Color(0xFF0B0F14);
  static const panel = Color(0xFF121821);
  static const panel2 = Color(0xFF18202B);
  static const line = Color(0xFF243042);
  static const text = Color(0xFFE6EDF5);
  static const muted = Color(0xFF8A99AD);
  static const accent = Color(0xFF34D3A6);
  static const accentInk = Color(0xFF04261C);
  static const warn = Color(0xFFF5B84B);
  static const danger = Color(0xFFFF4D5E);
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.accentInk,
      secondary: C.accent,
      surface: C.panel,
      onSurface: C.text,
      error: C.danger,
    ),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.text),
    ),
    dividerColor: C.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panel2,
      hintStyle: const TextStyle(color: C.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.accent),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: C.text,
        side: const BorderSide(color: C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.panel2,
      contentTextStyle: TextStyle(color: C.text),
    ),
  );
}

Color avatarColor(String s) {
  const colors = [
    Color(0xFF2B6CB0),
    Color(0xFF8E44AD),
    Color(0xFFD35400),
    Color(0xFF16A085),
    Color(0xFFC0392B),
    Color(0xFF2C3E50),
    Color(0xFF7D6608),
  ];
  return colors[s.codeUnits.fold(0, (a, b) => a + b) % colors.length];
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
