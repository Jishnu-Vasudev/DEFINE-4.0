import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Ember palette from the Relay logo: espresso surfaces, warm cream text, ember-orange accent.
// Two variants; [C.dark] flips them and the app rebuilds. The admin console uses the dark tokens.
class Palette {
  final Color bg, panel, panel2, line, text, muted, accent, ember, accentInk, warn, danger, glassEdge, mine;
  final Brightness brightness;
  const Palette({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.ember,
    required this.accentInk,
    required this.warn,
    required this.danger,
    required this.glassEdge,
    required this.mine,
    required this.brightness,
  });
}

const darkPalette = Palette(
  bg: Color(0xFF1B110B),
  panel: Color(0xFF26180F),
  panel2: Color(0xFF342216),
  line: Color(0xFF4A3223),
  text: Color(0xFFFFF6EA),
  muted: Color(0xFFC4AA94),
  accent: Color(0xFFFF9A3D),
  ember: Color(0xFFE85D18),
  accentInk: Color(0xFF2A1105),
  warn: Color(0xFFFFD27A),
  danger: Color(0xFFFF5D4F),
  glassEdge: Color(0x24FFE0B8),
  mine: Color(0xFF6A3415),
  brightness: Brightness.dark,
);

// Cream "daylight" variant from the design concept; accent darkened for contrast on cream.
const lightPalette = Palette(
  bg: Color(0xFFF6EBDD),
  panel: Color(0xFFFFFAF3),
  panel2: Color(0xFFF0E1CE),
  line: Color(0xFFE2CDB4),
  text: Color(0xFF3B2417),
  muted: Color(0xFF7A604D),
  accent: Color(0xFFD9570F),
  ember: Color(0xFFB8430A),
  accentInk: Color(0xFFFFF8F0),
  warn: Color(0xFF9A6A00),
  danger: Color(0xFFC62F22),
  glassEdge: Color(0x337A4B24),
  mine: Color(0xFFFFD9B8),
  brightness: Brightness.light,
);

class C {
  static Palette p = darkPalette;
  static bool get dark => p.brightness == Brightness.dark;
  static Color get bg => p.bg;
  static Color get panel => p.panel;
  static Color get panel2 => p.panel2;
  static Color get line => p.line;
  static Color get text => p.text;
  static Color get muted => p.muted;
  static Color get accent => p.accent;
  static Color get ember => p.ember;
  static Color get accentInk => p.accentInk;
  static Color get warn => p.warn;
  static Color get danger => p.danger;
  static Color get mine => p.mine;
}

// Glass surface used for cards, the composer and sheets.
BoxDecoration glass({double radius = 20, bool bright = false}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: C.dark ? .07 : .5),
      Colors.white.withValues(alpha: C.dark ? .02 : .2),
    ],
  ),
  color: C.panel.withValues(alpha: .7),
  border: Border.all(color: bright ? C.accent.withValues(alpha: .45) : C.p.glassEdge),
  boxShadow: [BoxShadow(color: C.dark ? const Color(0x66000000) : const Color(0x1F6B4123), blurRadius: 30, offset: const Offset(0, 14))],
);

// Warm radial glow behind every screen, as on the logo.
class EmberBackdrop extends StatelessWidget {
  final Widget child;
  const EmberBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(0.6, -1.1), radius: 1.3, colors: [Color(0x33E85D18), Color(0x00E85D18)]),
    ),
    child: child,
  );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.cover, semanticLabel: 'Bunny Hop'),
  );
}

// Small glass icon button used in headers.
class RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 40,
      decoration: glass(radius: 14),
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, size: 20), padding: EdgeInsets.zero),
    ),
  );
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: C.p.brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: C.accent, brightness: C.p.brightness).copyWith(
      primary: C.accent,
      onPrimary: C.accentInk,
      secondary: C.ember,
      surface: C.panel,
      onSurface: C.text,
      error: C.danger,
      surfaceContainerHighest: C.panel2,
    ),
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: C.bg)},
    ),
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      systemOverlayStyle: C.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      backgroundColor: Colors.transparent,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -.2),
    ),
    dividerColor: C.line,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.accent,
      selectionColor: C.accent.withValues(alpha: .35),
      selectionHandleColor: C.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panel2.withValues(alpha: .7),
      hintStyle: TextStyle(color: C.muted),
      labelStyle: TextStyle(color: C.muted),
      prefixIconColor: C.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: C.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: C.accent,
        foregroundColor: C.accentInk,
        disabledBackgroundColor: C.panel2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: C.text,
        side: BorderSide(color: C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: C.panel,
      dragHandleColor: C.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: C.panel),
    listTileTheme: ListTileThemeData(iconColor: C.muted),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.panel2,
      contentTextStyle: TextStyle(color: C.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

Color avatarColor(String s) {
  const colors = [
    Color(0xFFB4532A),
    Color(0xFF8A5A2B),
    Color(0xFFA23B2C),
    Color(0xFF6E4A8E),
    Color(0xFF2F7A6B),
    Color(0xFF9C6B1E),
    Color(0xFF4F6B8A),
  ];
  return colors[s.codeUnits.fold(0, (a, b) => a + b) % colors.length];
}

String channelTitle(Map<String, dynamic> ch, String? me) {
  if (ch['kind'] != 'dm') return ch['name'] ?? '';
  final names = (ch['name'] as String? ?? '').split(' & ');
  return names.firstWhere((n) => n != me, orElse: () => names.first);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
