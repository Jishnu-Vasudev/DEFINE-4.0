import 'package:flutter/material.dart';

import '../theme.dart';

// Logo with two radar rings pulsing outward, as on the design concept.
class RadarLogo extends StatefulWidget {
  const RadarLogo({super.key});
  @override
  State<RadarLogo> createState() => _RadarLogoState();
}

class _RadarLogoState extends State<RadarLogo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (final offset in [0.0, 0.5])
              if (!still) _ring(((_c.value + offset) % 1.0)),
            child!,
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: C.ember.withValues(alpha: .45), blurRadius: 40, spreadRadius: 2)],
          ),
          child: const Logo(size: 112),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final eased = Curves.easeOutCubic.transform(t);
    return Container(
      width: 112 + 88 * eased,
      height: 112 + 88 * eased,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: C.accent.withValues(alpha: (1 - t) * .55), width: 1.5),
      ),
    );
  }
}
