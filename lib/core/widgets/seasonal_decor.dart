import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/seasonal_theme.dart';

/// Carries the current season down the tree so any surface can dress for it.
///
/// The alternative — every widget reading a provider — would drag Riverpod into
/// `core/widgets` and make the decoration impossible to preview in isolation.
class SeasonalDecorScope extends InheritedWidget {
  const SeasonalDecorScope({
    super.key,
    required this.event,
    required super.child,
  });

  final SeasonalEvent event;

  static SeasonalEvent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SeasonalDecorScope>()?.event ??
      SeasonalEvent.none;

  @override
  bool updateShouldNotify(SeasonalDecorScope oldWidget) =>
      oldWidget.event != event;
}

/// The season's decoration, drawn along the top and bottom of every page.
///
/// Colour alone does not feel like an occasion. Lanterns that sway, stars that
/// breathe and confetti that drifts do — and because they are painted rather
/// than fetched, they cost one animation and no bytes.
///
/// Two rules keep it from becoming a nuisance: it never intercepts a touch,
/// and it stops entirely when the system asks for reduced motion.
class SeasonalDecor extends StatefulWidget {
  const SeasonalDecor({super.key, required this.event, required this.child});

  final SeasonalEvent event;
  final Widget child;

  @override
  State<SeasonalDecor> createState() => _SeasonalDecorState();
}

class _SeasonalDecorState extends State<SeasonalDecor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    if (widget.event != SeasonalEvent.none) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SeasonalDecor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event == SeasonalEvent.none) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SeasonalTheme.paletteFor(widget.event);
    if (palette == null) {
      return widget.child;
    }

    final still = MediaQuery.disableAnimationsOf(context);
    final phase =
        still ? const AlwaysStoppedAnimation<double>(0.22) : _controller;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 132,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: phase,
                builder:
                    (context, _) => CustomPaint(
                      painter: _TopDecorPainter(
                        event: widget.event,
                        colour: palette.ornament,
                        phase: phase.value,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hanging things at the top: lanterns, stars, confetti, palms.
class _TopDecorPainter extends CustomPainter {
  const _TopDecorPainter({
    required this.event,
    required this.colour,
    required this.phase,
  });

  final SeasonalEvent event;
  final Color colour;

  /// 0 to 1, looping.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    switch (event) {
      case SeasonalEvent.none:
        return;
      case SeasonalEvent.ramadan:
        _lanterns(canvas, size, count: 4, sway: 0.05);
      case SeasonalEvent.lastTenNights:
        _lanterns(canvas, size, count: 5, sway: 0.07);
        _twinkle(canvas, size);
      case SeasonalEvent.eidFitr:
        _garland(canvas, size);
        _confetti(canvas, size);
      case SeasonalEvent.eidAdha:
        _palms(canvas, size);
    }
  }

  /// Lanterns on cords, each swaying at its own pace so the row never looks
  /// like one object moving.
  void _lanterns(
    Canvas canvas,
    Size size, {
    required int count,
    required double sway,
  }) {
    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final x = size.width * t;
      final drop = 26.0 + (i.isEven ? 22 : 0) + (i % 3) * 9;
      final angle =
          math.sin((phase * 2 * math.pi) + i * 1.4) * sway * (1 + i % 2 * 0.4);

      canvas
        ..save()
        ..translate(x, 0)
        ..rotate(angle);

      final paint =
          Paint()
            ..color = colour.withValues(alpha: 0.55)
            ..strokeWidth = 1.1;
      canvas.drawLine(Offset.zero, Offset(0, drop), paint);

      final width = 15.0 + (i % 3) * 3;
      final height = width * 1.5;
      final body =
          Path()
            ..moveTo(-width * 0.34, drop)
            ..lineTo(width * 0.34, drop)
            ..lineTo(width * 0.5, drop + height * 0.24)
            ..lineTo(width * 0.5, drop + height * 0.78)
            ..lineTo(width * 0.3, drop + height)
            ..lineTo(-width * 0.3, drop + height)
            ..lineTo(-width * 0.5, drop + height * 0.78)
            ..lineTo(-width * 0.5, drop + height * 0.24)
            ..close();

      canvas
        ..drawPath(body, Paint()..color = colour.withValues(alpha: 0.20))
        ..drawPath(
          body,
          Paint()
            ..color = colour.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        )
        // The light inside, breathing.
        ..drawCircle(
          Offset(0, drop + height * 0.55),
          width * 0.2,
          Paint()
            ..color = colour.withValues(
              alpha:
                  0.30 + 0.28 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi + i)),
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..restore();
    }
  }

  /// Stars that fade in and out, seeded so they never jump between frames.
  void _twinkle(Canvas canvas, Size size) {
    final random = math.Random(11);
    for (var i = 0; i < 18; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.85;
      final beat = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 2 + i);
      canvas.drawCircle(
        Offset(x, y),
        1.1 + beat * 1.3,
        Paint()..color = colour.withValues(alpha: 0.18 + beat * 0.34),
      );
    }
  }

  /// A hanging garland of small flags for the Eid.
  void _garland(Canvas canvas, Size size) {
    final base = 46.0;
    final sag = 18 + math.sin(phase * 2 * math.pi) * 3;
    final path =
        Path()
          ..moveTo(0, base)
          ..quadraticBezierTo(size.width / 2, base + sag, size.width, base);

    canvas.drawPath(
      path,
      Paint()
        ..color = colour.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    const flags = 11;
    for (var i = 0; i <= flags; i++) {
      final t = i / flags;
      final x = size.width * t;
      // Quadratic curve at t, for the flag's anchor.
      final y =
          (1 - t) * (1 - t) * (base) +
          2 * (1 - t) * t * (base + sag) +
          t * t * (base);

      canvas.drawPath(
        Path()
          ..moveTo(x - 6, y)
          ..lineTo(x + 6, y)
          ..lineTo(x, y + 15)
          ..close(),
        Paint()..color = colour.withValues(alpha: i.isEven ? 0.32 : 0.18),
      );
    }
  }

  /// Eid confetti, drifting down and sideways.
  void _confetti(Canvas canvas, Size size) {
    final random = math.Random(5);
    for (var i = 0; i < 22; i++) {
      final baseX = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.8;
      final y = ((phase * speed + random.nextDouble()) % 1) * size.height;
      final x = baseX + math.sin(phase * 2 * math.pi + i) * 10;
      final tilt = phase * 2 * math.pi + i;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(tilt)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 6, height: 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = colour.withValues(alpha: 0.55),
        )
        ..restore();
    }
  }

  /// Palm fronds leaning in from the corners, moving as if in a light wind.
  void _palms(Canvas canvas, Size size) {
    for (final side in [-1.0, 1.0]) {
      final origin = Offset(side < 0 ? 0 : size.width, 6);
      final wind = math.sin(phase * 2 * math.pi) * 0.06 * side;

      for (var i = 0; i < 4; i++) {
        final spread = 0.34 + i * 0.24;
        final length = 74.0 - i * 8;
        final angle = side < 0 ? spread + wind : math.pi - spread + wind;
        final tip = origin + Offset(math.cos(angle), math.sin(angle)) * length;
        final control =
            origin +
            Offset(math.cos(angle - 0.4 * side), math.sin(angle - 0.4 * side)) *
                (length * 0.6);

        canvas.drawPath(
          Path()
            ..moveTo(origin.dx, origin.dy)
            ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy),
          Paint()
            ..color = colour.withValues(alpha: 0.38)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopDecorPainter old) =>
      old.phase != phase || old.event != event || old.colour != colour;
}

/// The season, worn by the floating nav bar itself.
///
/// Dangling objects over the bar looked like something had fallen on it. What
/// works is treating the bar's own top edge: a light that travels along it in
/// Ramadan, stars that breathe in the last ten nights, confetti crossing it for
/// Fitr, a woven border for Adha. It moves, so the bar feels alive, and it
/// never leaves the edge, so it always belongs to the bar.
class SeasonalNavFlourish extends StatefulWidget {
  const SeasonalNavFlourish({super.key, required this.event});

  final SeasonalEvent event;

  @override
  State<SeasonalNavFlourish> createState() => _SeasonalNavFlourishState();
}

class _SeasonalNavFlourishState extends State<SeasonalNavFlourish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (widget.event != SeasonalEvent.none) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SeasonalNavFlourish oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event == SeasonalEvent.none) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SeasonalTheme.paletteFor(widget.event);
    if (palette == null) {
      return const SizedBox(height: 6);
    }

    final still = MediaQuery.disableAnimationsOf(context);
    final phase =
        still ? const AlwaysStoppedAnimation<double>(0.3) : _controller;

    return SizedBox(
      height: 12,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: phase,
          builder:
              (context, _) => CustomPaint(
                painter: _NavFlourishPainter(
                  event: widget.event,
                  colour: palette.ornament,
                  phase: phase.value,
                ),
              ),
        ),
      ),
    );
  }
}

class _NavFlourishPainter extends CustomPainter {
  const _NavFlourishPainter({
    required this.event,
    required this.colour,
    required this.phase,
  });

  final SeasonalEvent event;
  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.07;
    final line = Rect.fromLTWH(inset, 3, size.width - inset * 2, 2);

    // The hairline every season shares, fading out at both ends so it reads as
    // part of the bar's edge rather than a rule drawn across it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(line, const Radius.circular(1)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            colour.withValues(alpha: 0),
            colour.withValues(alpha: 0.45),
            colour.withValues(alpha: 0),
          ],
        ).createShader(line),
    );

    switch (event) {
      case SeasonalEvent.none:
        return;

      // A lantern's light travelling along the edge.
      case SeasonalEvent.ramadan:
        final x = line.left + line.width * ((phase * 1.0) % 1);
        canvas.drawCircle(
          Offset(x, line.center.dy),
          9,
          Paint()
            ..color = colour.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(
          Offset(x, line.center.dy),
          2.2,
          Paint()..color = colour,
        );

      // Stars along the edge, breathing out of step with each other.
      case SeasonalEvent.lastTenNights:
        const count = 13;
        for (var i = 0; i < count; i++) {
          final x = line.left + line.width * ((i + 0.5) / count);
          final beat = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 1.6 + i);
          canvas.drawCircle(
            Offset(x, line.center.dy),
            0.8 + beat * 1.6,
            Paint()..color = colour.withValues(alpha: 0.2 + beat * 0.55),
          );
        }

      // Confetti crossing the edge, each piece on its own loop.
      case SeasonalEvent.eidFitr:
        const count = 10;
        for (var i = 0; i < count; i++) {
          final offset = (phase * (0.6 + i % 3 * 0.25) + i / count) % 1;
          final x = line.left + line.width * offset;
          final tilt = phase * 2 * math.pi + i;

          canvas
            ..save()
            ..translate(x, line.center.dy)
            ..rotate(tilt)
            ..drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: 5, height: 2.4),
                const Radius.circular(1.2),
              ),
              Paint()..color = colour.withValues(alpha: i.isEven ? 0.7 : 0.4),
            )
            ..restore();
        }

      // A woven border, like the edge of a rug, shifting slowly along.
      case SeasonalEvent.eidAdha:
        final path = Path();
        const step = 14.0;
        final shift = (phase * step * 2) % (step * 2);
        for (var x = line.left - step * 2; x < line.right + step; x += step) {
          final start = x + shift;
          path
            ..moveTo(start, line.center.dy - 3)
            ..quadraticBezierTo(
              start + step / 2,
              line.center.dy + 3,
              start + step,
              line.center.dy - 3,
            );
        }
        canvas
          ..save()
          ..clipRect(line.inflate(4))
          ..drawPath(
            path,
            Paint()
              ..color = colour.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3,
          )
          ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NavFlourishPainter old) =>
      old.event != event || old.colour != colour || old.phase != phase;
}
