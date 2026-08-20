import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// The drawn symbols the app uses in place of a stock icon set.
///
/// Material's icon font has no Kaaba, no misbaha and no eight-point star, and
/// downloading images would break the one promise this app makes — that it
/// works with no network at all. So the motifs are paths: they scale to any
/// size, take a colour from the tokens, and cost nothing to ship.
enum Motif {
  kaaba,
  mosque,
  openBook,
  beads,
  lantern,
  crescentStar,
  star8,
  prayerRug,
}

/// One motif, drawn inside a circle.
class MotifIcon extends StatelessWidget {
  const MotifIcon({
    super.key,
    required this.motif,
    this.size = 44,
    this.color,
    this.background,
    this.padding = 0.26,
  });

  final Motif motif;
  final double size;
  final Color? color;
  final Color? background;

  /// Share of the circle left empty around the drawing.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = color ?? tokens.brand;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? foreground.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * padding * 0.5),
        child: CustomPaint(
          painter: MotifPainter(motif: motif, color: foreground),
        ),
      ),
    );
  }
}

/// Paints a [Motif] to fill the given box.
class MotifPainter extends CustomPainter {
  const MotifPainter({
    required this.motif,
    required this.color,
    this.strokeWidth = 1.6,
  });

  final Motif motif;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final line =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round;

    switch (motif) {
      case Motif.kaaba:
        _kaaba(canvas, size, fill, line);
      case Motif.mosque:
        _mosque(canvas, size, fill);
      case Motif.openBook:
        _openBook(canvas, size, fill, line);
      case Motif.beads:
        _beads(canvas, size, fill);
      case Motif.lantern:
        _lantern(canvas, size, fill, line);
      case Motif.crescentStar:
        _crescentStar(canvas, size, fill);
      case Motif.star8:
        _star8(canvas, size, fill);
      case Motif.prayerRug:
        _prayerRug(canvas, size, fill, line);
    }
  }

  /// A cube with the kiswah band across it.
  void _kaaba(Canvas canvas, Size size, Paint fill, Paint line) {
    final body = Rect.fromLTWH(
      size.width * 0.16,
      size.height * 0.22,
      size.width * 0.68,
      size.height * 0.62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      fill,
    );

    // The band, cut out in the background colour by drawing with blend.
    final band = Rect.fromLTWH(
      body.left,
      body.top + body.height * 0.26,
      body.width,
      body.height * 0.16,
    );
    canvas.drawRect(band, Paint()..blendMode = BlendMode.clear);
    canvas.drawRect(band, Paint()..color = color.withValues(alpha: 0.35));
  }

  /// A dome between two minarets.
  void _mosque(Canvas canvas, Size size, Paint fill) {
    final baseY = size.height * 0.84;
    final centre = size.width / 2;
    final radius = size.width * 0.20;

    canvas
      ..drawCircle(Offset(centre, baseY - radius * 1.5), radius, fill)
      ..drawRect(
        Rect.fromLTRB(
          centre - radius,
          baseY - radius * 1.5,
          centre + radius,
          baseY,
        ),
        fill,
      );

    for (final side in [-1.0, 1.0]) {
      final x = centre + side * size.width * 0.34;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - size.width * 0.05,
            size.height * 0.28,
            x + size.width * 0.05,
            baseY,
          ),
          Radius.circular(size.width * 0.05),
        ),
        fill,
      );
      canvas.drawCircle(
        Offset(x, size.height * 0.26),
        size.width * 0.055,
        fill,
      );
    }

    canvas.drawRect(
      Rect.fromLTRB(size.width * 0.1, baseY, size.width * 0.9, baseY + 2),
      fill,
    );
  }

  /// Two facing pages with a spine.
  void _openBook(Canvas canvas, Size size, Paint fill, Paint line) {
    final centre = Offset(size.width / 2, size.height * 0.54);
    final width = size.width * 0.40;
    final height = size.height * 0.30;

    for (final side in [-1.0, 1.0]) {
      final path =
          Path()
            ..moveTo(centre.dx, centre.dy - height * 0.72)
            ..quadraticBezierTo(
              centre.dx + side * width * 0.55,
              centre.dy - height * 1.05,
              centre.dx + side * width,
              centre.dy - height * 0.5,
            )
            ..lineTo(centre.dx + side * width, centre.dy + height * 0.62)
            ..quadraticBezierTo(
              centre.dx + side * width * 0.55,
              centre.dy + height * 0.2,
              centre.dx,
              centre.dy + height * 0.55,
            )
            ..close();
      canvas.drawPath(path, fill);
    }

    canvas.drawLine(
      Offset(centre.dx, centre.dy - height * 0.72),
      Offset(centre.dx, centre.dy + height * 0.55),
      line..color = color.withValues(alpha: 0.0),
    );
  }

  /// A misbaha: a ring of beads with the imam bead at the bottom.
  void _beads(Canvas canvas, Size size, Paint fill) {
    final centre = Offset(size.width / 2, size.height * 0.46);
    final radius = size.width * 0.32;
    const count = 11;

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i / count) * 2 * math.pi;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * radius,
        size.width * 0.058,
        fill,
      );
    }

    canvas
      ..drawRect(
        Rect.fromCenter(
          center: Offset(centre.dx, centre.dy + radius + size.height * 0.16),
          width: size.width * 0.05,
          height: size.height * 0.16,
        ),
        fill,
      )
      ..drawCircle(
        Offset(centre.dx, centre.dy + radius + size.height * 0.28),
        size.width * 0.075,
        fill,
      );
  }

  /// A hanging fanous.
  void _lantern(Canvas canvas, Size size, Paint fill, Paint line) {
    final centre = size.width / 2;
    final top = size.height * 0.18;
    final bottom = size.height * 0.82;
    final half = size.width * 0.24;

    canvas.drawLine(Offset(centre, 0), Offset(centre, top), line);

    final body =
        Path()
          ..moveTo(centre - half * 0.55, top)
          ..lineTo(centre + half * 0.55, top)
          ..lineTo(centre + half, top + (bottom - top) * 0.28)
          ..lineTo(centre + half, bottom - (bottom - top) * 0.2)
          ..lineTo(centre + half * 0.6, bottom)
          ..lineTo(centre - half * 0.6, bottom)
          ..lineTo(centre - half, bottom - (bottom - top) * 0.2)
          ..lineTo(centre - half, top + (bottom - top) * 0.28)
          ..close();
    canvas.drawPath(body, fill);
  }

  /// Crescent with a star tucked into its opening.
  void _crescentStar(Canvas canvas, Size size, Paint fill) {
    final centre = Offset(size.width * 0.46, size.height / 2);
    final radius = size.width * 0.34;

    final full =
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius));
    final cut =
        Path()..addOval(
          Rect.fromCircle(
            center: centre.translate(radius * 0.42, -radius * 0.12),
            radius: radius * 0.9,
          ),
        );
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), fill);

    _starPath(
      canvas,
      Offset(size.width * 0.78, size.height * 0.36),
      size.width * 0.12,
      5,
      fill,
    );
  }

  /// The rub' el hizb: two squares at 45° to each other, which is how the
  /// eight-point star is actually constructed — a spiky sunburst is not it.
  void _star8(Canvas canvas, Size size, Paint fill) {
    final centre = size.center(Offset.zero);
    final radius = size.width * 0.44;

    Path square(double rotation) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final angle = rotation + i * math.pi / 2;
        final point =
            centre + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path..close();
    }

    final star = Path.combine(
      PathOperation.union,
      square(-math.pi / 2),
      square(-math.pi / 4),
    );

    canvas
      ..drawPath(star, fill)
      ..drawPath(
        star,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      )
      // The small centre opening that gives the motif its lightness.
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          square(-math.pi / 2),
          square(-math.pi / 4),
        ),
        Paint()..color = color.withValues(alpha: 0.0),
      )
      ..drawCircle(centre, radius * 0.22, Paint()..blendMode = BlendMode.clear);
  }

  /// An arched rug: the shape a prayer mat is woven with.
  void _prayerRug(Canvas canvas, Size size, Paint fill, Paint line) {
    final rect = Rect.fromLTWH(
      size.width * 0.20,
      size.height * 0.12,
      size.width * 0.60,
      size.height * 0.76,
    );

    final path =
        Path()
          ..moveTo(rect.left, rect.bottom)
          ..lineTo(rect.left, rect.top + rect.height * 0.32)
          ..quadraticBezierTo(rect.left, rect.top, rect.center.dx, rect.top)
          ..quadraticBezierTo(
            rect.right,
            rect.top,
            rect.right,
            rect.top + rect.height * 0.32,
          )
          ..lineTo(rect.right, rect.bottom)
          ..close();

    canvas
      ..drawPath(path, Paint()..color = color.withValues(alpha: 0.22))
      ..drawPath(path, line);
  }

  void _starPath(
    Canvas canvas,
    Offset centre,
    double radius,
    int points,
    Paint paint, {
    double innerRatio = 0.45,
  }) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? radius : radius * innerRatio;
      final angle = -math.pi / 2 + i * math.pi / points;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MotifPainter old) =>
      old.motif != motif || old.color != color;
}

/// A faint motif watermark for the corner of an important card.
class CardMotif extends StatelessWidget {
  const CardMotif({
    super.key,
    required this.motif,
    this.size = 116,
    this.opacity = 0.06,
  });

  final Motif motif;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: MotifPainter(
            motif: motif,
            color: context.tokens.ink.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
