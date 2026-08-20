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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 168,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: phase,
                builder:
                    (context, _) => CustomPaint(
                      painter: _BottomDecorPainter(
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

/// The band along the bottom: a skyline, a garland, dunes.
class _BottomDecorPainter extends CustomPainter {
  const _BottomDecorPainter({
    required this.event,
    required this.colour,
    required this.phase,
  });

  final SeasonalEvent event;
  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    switch (event) {
      case SeasonalEvent.none:
        return;
      case SeasonalEvent.ramadan:
      case SeasonalEvent.lastTenNights:
        _skyline(canvas, size);
      case SeasonalEvent.eidFitr:
        _skyline(canvas, size);
      case SeasonalEvent.eidAdha:
        _dunes(canvas, size);
    }
  }

  /// Domes and minarets, drifting very slowly sideways like a parallax layer.
  void _skyline(Canvas canvas, Size size) {
    final drift = math.sin(phase * 2 * math.pi) * 6;
    final base = size.height;
    final path = Path()..moveTo(-20, base);

    var x = -20.0 + drift;
    var index = 0;
    while (x < size.width + 40) {
      final width = 46.0 + (index % 3) * 16;
      final domeRadius = width * 0.34;
      final domeTop = base - 34 - (index % 2) * 12;

      path
        ..lineTo(x, domeTop + domeRadius)
        ..arcToPoint(
          Offset(x + domeRadius * 2, domeTop + domeRadius),
          radius: Radius.circular(domeRadius),
        )
        ..lineTo(x + domeRadius * 2, base);

      if (index.isEven) {
        final minaret = x + width - 6;
        path
          ..moveTo(minaret, base)
          ..lineTo(minaret, domeTop - 22)
          ..lineTo(minaret + 5, domeTop - 22)
          ..lineTo(minaret + 5, base)
          ..close()
          ..moveTo(x + domeRadius * 2, base);
      }

      x += width;
      index++;
    }

    path
      ..lineTo(size.width + 40, base)
      ..close();

    canvas.drawPath(path, Paint()..color = colour.withValues(alpha: 0.12));
  }

  /// Two soft dunes for the days of Adha.
  void _dunes(Canvas canvas, Size size) {
    final drift = math.sin(phase * 2 * math.pi) * 8;

    for (var layer = 0; layer < 2; layer++) {
      final height = 34.0 + layer * 22;
      final path =
          Path()
            ..moveTo(-40, size.height)
            ..quadraticBezierTo(
              size.width * 0.25 + drift * (layer + 1),
              size.height - height,
              size.width * 0.55,
              size.height - height * 0.55,
            )
            ..quadraticBezierTo(
              size.width * 0.85 - drift * (layer + 1),
              size.height - height * 1.2,
              size.width + 40,
              size.height - height * 0.3,
            )
            ..lineTo(size.width + 40, size.height)
            ..close();

      canvas.drawPath(
        path,
        Paint()..color = colour.withValues(alpha: layer == 0 ? 0.16 : 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BottomDecorPainter old) =>
      old.phase != phase || old.event != event || old.colour != colour;
}

/// A thin seasonal flourish drawn over the top edge of the floating nav bar.
///
/// The bar is the one surface on screen at all times, so giving it the
/// season's character is what makes the whole app feel dressed rather than one
/// screen wearing a banner.
class SeasonalNavFlourish extends StatelessWidget {
  const SeasonalNavFlourish({super.key, required this.event});

  final SeasonalEvent event;

  @override
  Widget build(BuildContext context) {
    final palette = SeasonalTheme.paletteFor(event);
    if (palette == null) {
      return const SizedBox(height: 6);
    }

    return SizedBox(
      height: 16,
      width: double.infinity,
      child: CustomPaint(
        painter: _NavFlourishPainter(event: event, colour: palette.ornament),
      ),
    );
  }
}

class _NavFlourishPainter extends CustomPainter {
  const _NavFlourishPainter({required this.event, required this.colour});

  final SeasonalEvent event;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    // A hairline along the very top, shared by every season, so the ribbon is
    // always anchored to the bar rather than hovering over it.
    canvas.drawLine(
      Offset(size.width * 0.08, 1),
      Offset(size.width * 0.92, 1),
      Paint()
        ..shader = LinearGradient(
          colors: [
            colour.withValues(alpha: 0),
            colour.withValues(alpha: 0.75),
            colour.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
        ..strokeWidth = 1.2,
    );

    final fill = Paint()..color = colour.withValues(alpha: 0.55);

    switch (event) {
      case SeasonalEvent.none:
        return;

      // Little lanterns hanging down into the bar.
      case SeasonalEvent.ramadan:
      case SeasonalEvent.lastTenNights:
        const count = 7;
        for (var i = 0; i < count; i++) {
          final x = size.width * ((i + 0.5) / count);
          final drop = i.isEven ? 5.0 : 8.0;
          canvas
            ..drawLine(
              Offset(x, 1),
              Offset(x, drop),
              Paint()
                ..color = colour.withValues(alpha: 0.45)
                ..strokeWidth = 0.9,
            )
            ..drawPath(
              Path()
                ..moveTo(x - 2.6, drop)
                ..lineTo(x + 2.6, drop)
                ..lineTo(x + 3.6, drop + 4)
                ..lineTo(x + 2, drop + 7)
                ..lineTo(x - 2, drop + 7)
                ..lineTo(x - 3.6, drop + 4)
                ..close(),
              i.isEven
                  ? fill
                  : (Paint()..color = colour.withValues(alpha: 0.3)),
            );
        }

      // Pennants, alternating weight.
      case SeasonalEvent.eidFitr:
        const count = 11;
        for (var i = 0; i < count; i++) {
          final x = size.width * ((i + 0.5) / count);
          canvas.drawPath(
            Path()
              ..moveTo(x - 4, 1)
              ..lineTo(x + 4, 1)
              ..lineTo(x, 9)
              ..close(),
            Paint()..color = colour.withValues(alpha: i.isEven ? 0.5 : 0.26),
          );
        }

      // A scalloped valance, like the edge of a tent.
      case SeasonalEvent.eidAdha:
        const scallops = 14;
        final width = size.width / scallops;
        final path = Path()..moveTo(0, 1);
        for (var i = 0; i < scallops; i++) {
          path.arcToPoint(
            Offset(width * (i + 1), 1),
            radius: Radius.circular(width * 0.55),
            clockwise: false,
          );
        }
        canvas.drawPath(path, Paint()..color = colour.withValues(alpha: 0.28));
    }
  }

  @override
  bool shouldRepaint(covariant _NavFlourishPainter old) =>
      old.event != event || old.colour != colour;
}
