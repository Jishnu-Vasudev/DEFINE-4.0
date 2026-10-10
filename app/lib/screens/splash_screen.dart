import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'channels_screen.dart';
import 'join_screen.dart';

// Shows the logo bloom for at least ~1.4 s (and until local state is loaded), then fades to the app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _minDone = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1400), () => setState(() => _minDone = true));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final Widget child = !(s.ready && _minDone)
        ? const SplashScreen(key: ValueKey('splash'))
        : s.loggedIn
        ? const ChannelsScreen(key: ValueKey('channels'))
        : const JoinScreen(key: ValueKey('join'));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .6, curve: Curves.easeOutBack),
    );
    final glow = CurvedAnimation(
      parent: _c,
      curve: const Interval(.2, 1, curve: Curves.easeOut),
    );
    final word = CurvedAnimation(
      parent: _c,
      curve: const Interval(.45, 1, curve: Curves.easeOutCubic),
    );
    return Scaffold(
      backgroundColor: C.bg,
      body: EmberBackdrop(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: .6 + .4 * logoIn.value,
                  child: Opacity(
                    opacity: logoIn.value.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: C.ember.withValues(alpha: .55 * glow.value),
                            blurRadius: 30 + 40 * glow.value,
                            spreadRadius: 4 * glow.value,
                          ),
                        ],
                      ),
                      child: const Logo(size: 128),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                ClipRect(
                  child: Transform.translate(
                    offset: Offset(0, 28 * (1 - word.value)),
                    child: Opacity(
                      opacity: word.value,
                      child: Text(
                        'Bunny Hop',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, color: C.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: word.value,
                  child: Text('Your team, one press away', style: TextStyle(color: C.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
