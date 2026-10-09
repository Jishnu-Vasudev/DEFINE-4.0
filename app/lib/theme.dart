import 'package:flutter/material.dart';

// Palette sampled from the BunnyHop logo: deep blue -> cyan -> green.
class C {
  static const bg = Color(0xFF040B22);
  static const panel = Color(0xFF0A1740);
  static const panel2 = Color(0xFF102252);
  static const line = Color(0xFF1B3270);
  static const text = Color(0xFFEEF5FF);
  static const muted = Color(0xFF8DA2CC); // 6.5:1 on bg, passes AA
  static const blue = Color(0xFF0660F1);
  static const accent = Color(0xFF1ADFFD);
  static const green = Color(0xFF40ECA7);
  static const accentInk = Color(0xFF03142E);
  static const warn = Color(0xFFF5B84B);
  static const danger = Color(0xFFFF4D5E);
}

const brandGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFF002ED6), C.blue, C.accent, C.green],
  stops: [0, .35, .7, 1],
);

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
    dialogTheme: DialogThemeData(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.panel2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.accent),
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
    Color(0xFF0B5ED7),
    Color(0xFF6D4AFF),
    Color(0xFFD9730D),
    Color(0xFF0E9F8A),
    Color(0xFFC0392B),
    Color(0xFF3B5BA5),
    Color(0xFF8A6D0B),
  ];
  return colors[s.codeUnits.fold(0, (a, b) => a + b) % colors.length];
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

// Logo in a soft glow; used by splash, join screen and app bars.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool glow;
  const BrandLogo({super.key, this.size = 96, this.glow = true});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: glow ? [BoxShadow(color: C.accent.withValues(alpha: .35), blurRadius: size * .35, spreadRadius: size * .02)] : null,
    ),
    child: Image.asset('assets/images/logo.png', width: size, height: size, semanticLabel: 'BunnyHop logo'),
  );
}
