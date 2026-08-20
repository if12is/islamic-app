import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/seasonal_theme.dart';
import '../theme/design_tokens.dart';

/// The big seasonal illustration: a rosette, a skyline, and hanging lanterns.
///
/// It is drawn, not photographed. A picture of a mosque is somebody's mosque —
/// a silhouette is everyone's, it weighs nothing, it recolours itself for the
/// season, and it stays sharp on any screen.
class SeasonalHeroArt extends StatefulWidget {
  const SeasonalHeroArt({
    super.key,
    required this.event,
    this.height = 300,
    this.animate = true,
    this.tint,
    this.silhouette,
  });

  final SeasonalEvent event;
  final double height;
  final bool animate;

  /// Accent for the rosette, lanterns and lit windows.
  final Color? tint;

  /// The skyline's own colour; defaults to the darkest ink.
  final Color? silhouette;

  @override
  State<SeasonalHeroArt> createState() => _SeasonalHeroArtState();
}

class _SeasonalHeroArtState extends State<SeasonalHeroArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
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
    final tokens = context.tokens;
    final palette = SeasonalTheme.paletteFor(widget.event);
    final accent = widget.tint ?? palette?.ornament ?? tokens.goldBright;
    // Always the darkest ink the theme owns, so the skyline belongs to the
    // palette rather than being a colour of its own.
    final dark =
        widget.silhouette ??
        Color.lerp(tokens.ink, Colors.black, tokens.isDark ? 0.0 : 0.15)!;

    final still = MediaQuery.disableAnimationsOf(context) || !widget.animate;
    final phase =
        still ? const AlwaysStoppedAnimation<double>(0.3) : _controller;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: phase,
          builder:
              (context, _) => CustomPaint(
                painter: _HeroArtPainter(
                  accent: accent,
                  silhouette: dark,
                  phase: phase.value,
                  event: widget.event,
                ),
              ),
        ),
      ),
    );
  }
}

class _HeroArtPainter extends CustomPainter {
  const _HeroArtPainter({
    required this.accent,
    required this.silhouette,
    required this.phase,
    required this.event,
  });

  final Color accent;
  final Color silhouette;
  final double phase;
  final SeasonalEvent event;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.92;

    _rosette(
      canvas,
      Offset(size.width / 2, baseline - size.height * 0.42),
      size.width * 0.40,
    );
    _skyline(canvas, size, baseline);
    _lanterns(canvas, size);
  }

  /// A rosette behind the skyline: rings of petals, the way an arabesque
  /// medallion is built up from a repeated unit.
  void _rosette(Canvas canvas, Offset centre, double radius) {
    final stroke =
        Paint()
          ..color = accent.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = accent.withValues(alpha: 0.05),
    );

    for (final ring in [1.0, 0.78, 0.54]) {
      final r = radius * ring;
      canvas.drawCircle(centre, r, stroke);

      final petals = ring > 0.9 ? 24 : (ring > 0.7 ? 16 : 10);
      for (var i = 0; i < petals; i++) {
        final angle = (i / petals) * 2 * math.pi + phase * 0.12 * ring;
        final outer = centre + Offset(math.cos(angle), math.sin(angle)) * r;
        final inner =
            centre + Offset(math.cos(angle), math.sin(angle)) * (r * 0.82);

        // Each petal is a lens: two arcs meeting at a point.
        final petal =
            Path()
              ..moveTo(inner.dx, inner.dy)
              ..quadraticBezierTo(
                outer.dx + math.cos(angle + math.pi / 2) * r * 0.07,
                outer.dy + math.sin(angle + math.pi / 2) * r * 0.07,
                outer.dx,
                outer.dy,
              )
              ..quadraticBezierTo(
                outer.dx + math.cos(angle - math.pi / 2) * r * 0.07,
                outer.dy + math.sin(angle - math.pi / 2) * r * 0.07,
                inner.dx,
                inner.dy,
              );
        canvas.drawPath(petal, stroke);
      }
    }

    // A slow, gentle halo so the medallion breathes.
    final beat = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    canvas.drawCircle(
      centre,
      radius * 0.30,
      Paint()
        ..color = accent.withValues(alpha: 0.06 + beat * 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  /// Domes, minarets and an arcade — with the windows lit.
  void _skyline(Canvas canvas, Size size, double baseline) {
    final centre = size.width / 2;
    final unit = size.width * 0.07;
    final body = Paint()..color = silhouette;
    final light = Paint()..color = accent;

    // Two small flanking domes, drawn first so the main hall sits over them.
    for (final side in [-1.0, 1.0]) {
      final x = centre + side * unit * 4.4;
      final domeRadius = unit * 1.15;
      final top = baseline - unit * 2.6;
      canvas
        ..drawCircle(Offset(x, top), domeRadius, body)
        ..drawRect(
          Rect.fromLTRB(x - domeRadius, top, x + domeRadius, baseline),
          body,
        );
      _finial(canvas, Offset(x, top - domeRadius), unit * 0.5, body);
    }

    // Minarets: shaft, two balconies, a cap and a finial.
    for (final side in [-1.0, 1.0]) {
      final x = centre + side * unit * 3.05;
      final top = baseline - unit * 7.2;
      final half = unit * 0.42;

      canvas.drawRect(Rect.fromLTRB(x - half, top, x + half, baseline), body);

      for (final level in [0.28, 0.58]) {
        final y = top + (baseline - top) * level;
        canvas.drawRect(
          Rect.fromLTRB(x - half * 1.9, y, x + half * 1.9, y + unit * 0.28),
          body,
        );
      }

      canvas.drawPath(
        Path()
          ..moveTo(x - half * 1.35, top)
          ..lineTo(x + half * 1.35, top)
          ..lineTo(x, top - unit * 1.15)
          ..close(),
        body,
      );
      _finial(canvas, Offset(x, top - unit * 1.15), unit * 0.42, body);

      // Lit windows up the shaft.
      for (var i = 0; i < 4; i++) {
        final y = top + unit * (1.5 + i * 1.15);
        if (y > baseline - unit * 0.6) {
          break;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, y),
              width: half * 0.9,
              height: unit * 0.6,
            ),
            Radius.circular(unit * 0.3),
          ),
          light,
        );
      }
    }

    // The main hall: a big dome on a drum, over an arcade.
    final domeRadius = unit * 2.0;
    final domeTop = baseline - unit * 4.4;
    canvas
      ..drawCircle(Offset(centre, domeTop), domeRadius, body)
      ..drawRect(
        Rect.fromLTRB(
          centre - domeRadius,
          domeTop,
          centre + domeRadius,
          baseline,
        ),
        body,
      );
    _finial(canvas, Offset(centre, domeTop - domeRadius), unit * 0.62, body);

    // The doorway, arched and lit.
    final door = Rect.fromLTRB(
      centre - unit * 0.85,
      baseline - unit * 2.3,
      centre + unit * 0.85,
      baseline,
    );
    canvas.drawPath(_arch(door), light);

    // The arcade either side of it.
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        final x = centre + side * unit * (1.55 + i * 1.05);
        final window = Rect.fromCenter(
          center: Offset(x, baseline - unit * 0.95),
          width: unit * 0.62,
          height: unit * 1.5,
        );
        canvas.drawPath(_arch(window), light);
      }
    }

    // A row of small lit windows around the drum.
    for (var i = -2; i <= 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centre + i * unit * 0.78, domeTop + unit * 0.75),
            width: unit * 0.34,
            height: unit * 0.7,
          ),
          Radius.circular(unit * 0.17),
        ),
        light,
      );
    }
  }

  /// The crescent-topped spike that finishes a dome or a minaret.
  void _finial(Canvas canvas, Offset base, double height, Paint paint) {
    canvas.drawRect(
      Rect.fromLTRB(
        base.dx - height * 0.12,
        base.dy - height,
        base.dx + height * 0.12,
        base.dy + 1,
      ),
      paint,
    );

    final centre = Offset(base.dx, base.dy - height * 1.35);
    final radius = height * 0.42;
    final full =
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius));
    final cut =
        Path()..addOval(
          Rect.fromCircle(
            center: centre.translate(radius * 0.45, -radius * 0.1),
            radius: radius * 0.9,
          ),
        );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      Paint()..color = accent,
    );
  }

  Path _arch(Rect rect) {
    final shoulder = rect.top + rect.height * 0.45;
    return Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, shoulder)
      ..quadraticBezierTo(rect.left, rect.top, rect.center.dx, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, shoulder)
      ..lineTo(rect.right, rect.bottom)
      ..close();
  }

  /// Lanterns hanging into the frame from the top corner, each on its own cord
  /// and swinging at its own pace.
  void _lanterns(Canvas canvas, Size size) {
    const drops = [0.16, 0.30, 0.50];
    const widths = [0.055, 0.070, 0.092];

    for (var i = 0; i < drops.length; i++) {
      final x = size.width * (0.72 + i * 0.10);
      final cord = size.height * drops[i];
      final width = size.width * widths[i];
      final swing = math.sin(phase * 2 * math.pi + i * 1.1) * 0.045;

      canvas
        ..save()
        ..translate(x, 0)
        ..rotate(swing);

      final cordPaint =
          Paint()
            ..color = accent.withValues(alpha: 0.5)
            ..strokeWidth = 1;
      canvas.drawLine(Offset.zero, Offset(0, cord), cordPaint);

      final height = width * 1.55;
      final half = width / 2;

      // Cap, body, base — the fanous shape.
      canvas.drawPath(
        Path()
          ..moveTo(-half * 0.5, cord)
          ..lineTo(half * 0.5, cord)
          ..lineTo(half, cord + height * 0.2)
          ..lineTo(half, cord + height * 0.78)
          ..lineTo(half * 0.55, cord + height)
          ..lineTo(-half * 0.55, cord + height)
          ..lineTo(-half, cord + height * 0.78)
          ..lineTo(-half, cord + height * 0.2)
          ..close(),
        Paint()..color = accent.withValues(alpha: 0.30),
      );

      canvas.drawPath(
        Path()
          ..moveTo(-half * 0.5, cord)
          ..lineTo(half * 0.5, cord)
          ..lineTo(half, cord + height * 0.2)
          ..lineTo(half, cord + height * 0.78)
          ..lineTo(half * 0.55, cord + height)
          ..lineTo(-half * 0.55, cord + height)
          ..lineTo(-half, cord + height * 0.78)
          ..lineTo(-half, cord + height * 0.2)
          ..close(),
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );

      // The lattice on the glass.
      for (var row = 1; row < 4; row++) {
        final y = cord + height * (row / 4);
        canvas.drawLine(
          Offset(-half * 0.9, y),
          Offset(half * 0.9, y),
          Paint()
            ..color = accent.withValues(alpha: 0.35)
            ..strokeWidth = 0.8,
        );
      }

      final glow = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 1.4 + i);
      canvas
        ..drawCircle(
          Offset(0, cord + height * 0.5),
          width * 0.28,
          Paint()
            ..color = accent.withValues(alpha: 0.35 + glow * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroArtPainter old) =>
      old.phase != phase ||
      old.accent != accent ||
      old.silhouette != silhouette ||
      old.event != event;
}

/// The four corner flourishes that frame a card.
///
/// A quarter-rosette in each corner is the oldest trick in Islamic book
/// decoration: it marks the page as something to dwell on without adding a box.
class CardCorners extends StatelessWidget {
  const CardCorners({super.key, this.color, this.inset = 6, this.size = 26});

  final Color? color;
  final double inset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CornerPainter(
          colour: color ?? context.tokens.gold,
          inset: inset,
          extent: size,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.colour,
    required this.inset,
    required this.extent,
  });

  final Color colour;
  final double inset;
  final double extent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = colour.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final dot = Paint()..color = colour.withValues(alpha: 0.7);

    final corners = <(Offset, double, double)>[
      (Offset(inset, inset), 1, 1),
      (Offset(size.width - inset, inset), -1, 1),
      (Offset(inset, size.height - inset), 1, -1),
      (Offset(size.width - inset, size.height - inset), -1, -1),
    ];

    for (final (origin, dx, dy) in corners) {
      canvas
        ..drawPath(
          Path()
            ..moveTo(origin.dx + dx * extent, origin.dy)
            ..quadraticBezierTo(
              origin.dx,
              origin.dy,
              origin.dx,
              origin.dy + dy * extent,
            ),
          stroke,
        )
        ..drawPath(
          Path()
            ..moveTo(origin.dx + dx * extent * 0.55, origin.dy + dy * 5)
            ..quadraticBezierTo(
              origin.dx + dx * 5,
              origin.dy + dy * 5,
              origin.dx + dx * 5,
              origin.dy + dy * extent * 0.55,
            ),
          stroke,
        )
        ..drawCircle(Offset(origin.dx + dx * extent, origin.dy), 1.8, dot)
        ..drawCircle(Offset(origin.dx, origin.dy + dy * extent), 1.8, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.colour != colour || old.extent != extent;
}
