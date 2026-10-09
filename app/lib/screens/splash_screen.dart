import 'package:flutter/material.dart';

import '../theme.dart';

// Shown while the local DB opens; main.dart keeps it up for at least ~1.6 s so it never flashes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  late final _scale = Tween(begin: .7, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
  late final _fade = CurvedAnimation(parent: _c, curve: const Interval(0, .7, curve: Curves.easeOut));
  late final _text = CurvedAnimation(parent: _c, curve: const Interval(.4, 1, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFF0B2A6B), C.bg]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(scale: _scale, child: const BrandLogo(size: 150)),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _text,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => brandGradient.createShader(r),
                      child: const Text(
                        'BunnyHop',
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: .5, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Talk anywhere. Hop phone to phone.', style: TextStyle(color: C.muted, fontSize: 15)),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 3, backgroundColor: C.line)),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
