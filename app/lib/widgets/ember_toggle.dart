import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

// Flutter take on the "Skeuomorphic Toggle — Shader" design: a recessed capsule that fills with
// flowing ember plasma and drifting sparks when on, and a glossy lit knob that springs across.
class EmberToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? onIcon, offIcon;
  final String semanticLabel;
  final double width;
  const EmberToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.onIcon,
    this.offIcon,
    this.width = 62,
  });
  @override
  State<EmberToggle> createState() => _EmberToggleState();
}

class _EmberToggleState extends State<EmberToggle> with TickerProviderStateMixin {
  late final _pos = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);
  late final _time = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  static const _spring = SpringDescription(mass: 1, stiffness: 420, damping: 24);

  @override
  void initState() {
    super.initState();
    _syncFlow();
  }

  @override
  void didUpdateWidget(EmberToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (MediaQuery.of(context).disableAnimations) {
        _pos.value = widget.value ? 1 : 0;
      } else {
        _pos.animateWith(SpringSimulation(_spring, _pos.value, widget.value ? 1 : 0, _pos.velocity));
      }
      _syncFlow();
    }
  }

  void _syncFlow() {
    if (widget.value) {
      _time.repeat();
    } else {
      _time.stop();
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = w * .58;
    return Semantics(
      toggled: widget.value,
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 50 && (v > 0) != widget.value) widget.onChanged(v > 0);
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pos, _time]),
          builder: (_, _) {
            final p = _pos.value;
            final icon = widget.value ? widget.onIcon : widget.offIcon;
            final knob = h - 8;
            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _TogglePainter(p.clamp(-.1, 1.1), _time.value, C.p))),
                  if (icon != null)
                    Positioned(
                      left: 4 + (w - knob - 8) * p.clamp(0, 1),
                      top: 4,
                      width: knob,
                      height: knob,
                      child: Icon(icon, size: knob * .55, color: Color.lerp(const Color(0xFF8A6A55), C.p.ember, p.clamp(0, 1))),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TogglePainter extends CustomPainter {
  final double p, t;
  final Palette pal;
  _TogglePainter(this.p, this.t, this.pal);

  @override
  void paint(Canvas canvas, Size s) {
    final on = p.clamp(0.0, 1.0);
    final r = s.height / 2;
    final track = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r));
    final dark = pal.brightness == Brightness.dark;

    // recessed trough
    final dormantTop = dark ? const Color(0xFF120A06) : const Color(0xFFD9C6B0);
    final dormantBottom = dark ? const Color(0xFF2A1B12) : const Color(0xFFEFE2D2);
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [dormantTop, dormantBottom],
        ).createShader(track.outerRect),
    );

    // plasma: flowing ember gradient, faded in with the knob position
    if (on > 0) {
      canvas.save();
      canvas.clipRRect(track);
      final shift = t * s.width * 2;
      final plasma = LinearGradient(
        colors: [pal.ember, pal.accent, const Color(0xFFFFD27A), pal.accent, pal.ember],
        stops: const [0, .3, .5, .7, 1],
        tileMode: TileMode.repeated,
      ).createShader(Rect.fromLTWH(-shift, 0, s.width * 2, s.height));
      canvas.drawRRect(
        track,
        Paint()
          ..shader = plasma
          ..color = Colors.white.withValues(alpha: on),
      );
      // drifting sparks
      for (var i = 0; i < 5; i++) {
        final ph = (t * (1.2 + i * .37) + i * .23) % 1.0;
        final x = -6 + (s.width + 12) * ph;
        final y = s.height * (.3 + .4 * ((math.sin(i * 12.9 + t * 6.28) + 1) / 2));
        final fade = math.sin(ph * math.pi);
        canvas.drawCircle(Offset(x, y), 1.1 + .6 * (i % 2), Paint()..color = Colors.white.withValues(alpha: .85 * fade * on));
      }
      // inner shading keeps it reading as a recess
      canvas.drawRRect(
        track,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: .35), Colors.transparent, Colors.white.withValues(alpha: .12)],
            stops: const [0, .45, 1],
          ).createShader(track.outerRect),
      );
      canvas.restore();
    }

    // rim: soft dark edge, glowing accent edge when on
    canvas.drawRRect(
      track.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: dark ? .55 : .18),
    );
    if (on > 0) {
      canvas.drawRRect(
        track.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = pal.accent.withValues(alpha: .55 * on)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // knob: lit sphere with drop shadow and specular highlight
    final kd = s.height - 8;
    final c = Offset(4 + kd / 2 + (s.width - kd - 8) * p, s.height / 2);
    canvas.drawCircle(
      c.translate(0, 2),
      kd / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final kr = Rect.fromCircle(center: c, radius: kd / 2);
    canvas.drawCircle(
      c,
      kd / 2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          radius: .95,
          colors: [Color(0xFFFFFDF8), Color(0xFFF1E3D2), Color(0xFFC9B19A)],
          stops: [0, .55, 1],
        ).createShader(kr),
    );
    canvas.drawCircle(
      c.translate(-kd * .16, -kd * .2),
      kd * .14,
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_TogglePainter o) => o.p != p || o.t != t || o.pal != pal;
}
