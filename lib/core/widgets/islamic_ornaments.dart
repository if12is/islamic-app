import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn Islamic decoration, shared by the seasonal banner and the
/// shareable Ramadan poster.
///
/// Everything is painted rather than shipped as images: it scales to any size,
/// takes no space in the bundle, and picks up the season's colours.
class IslamicOrnaments {
  IslamicOrnaments._();

  /// A crescent, cut out of one circle with another.
  static void crescent(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final full =
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final cut =
        Path()..addOval(
          Rect.fromCircle(
            center: center.translate(radius * 0.42, -radius * 0.16),
            radius: radius * 0.92,
          ),
        );

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      Paint()..color = color,
    );
  }

  /// A hanging fanous: cord, cap, body with a light inside, and a base.
  static void lantern(
    Canvas canvas, {
    required Offset top,
    required double width,
    required double cordLength,
    required Color color,
  }) {
    final stroke =
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, width * 0.035);
    final fill = Paint()..color = color.withValues(alpha: 0.22);

    final bodyTop = top.dy + cordLength;
    final bodyHeight = width * 1.25;
    final left = top.dx - width / 2;

    canvas.drawLine(top, Offset(top.dx, bodyTop), stroke);

    final cap = Rect.fromLTWH(
      left + width * 0.2,
      bodyTop,
      width * 0.6,
      width * 0.11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, Radius.circular(width * 0.05)),
      stroke,
    );

    final body =
        Path()
          ..moveTo(left + width * 0.16, bodyTop + width * 0.13)
          ..lineTo(left + width * 0.84, bodyTop + width * 0.13)
          ..lineTo(left + width, bodyTop + bodyHeight * 0.55)
          ..lineTo(left + width * 0.84, bodyTop + bodyHeight)
          ..lineTo(left + width * 0.16, bodyTop + bodyHeight)
          ..lineTo(left, bodyTop + bodyHeight * 0.55)
          ..close();

    canvas
      ..drawPath(body, fill)
      ..drawPath(body, stroke)
      ..drawCircle(
        Offset(top.dx, bodyTop + bodyHeight * 0.55),
        width * 0.12,
        Paint()..color = color.withValues(alpha: 0.55),
      );

    final base = Rect.fromLTWH(
      left + width * 0.28,
      bodyTop + bodyHeight,
      width * 0.44,
      width * 0.09,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(width * 0.045)),
      stroke,
    );
  }

  /// A scatter of small stars, seeded so it never flickers between frames.
  static void stars(
    Canvas canvas,
    Size size,
    Color color, {
    int count = 26,
    int seed = 7,
  }) {
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    final random = math.Random(seed);

    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 1.6 + 0.6,
        paint,
      );
    }
  }

  /// The pointed arch that frames a poster: two arcs meeting at a point over
  /// straight sides.
  ///
  /// [pointPixels] fixes the height of the pointed head in logical pixels.
  /// Pass it whenever the frame can grow tall — a fraction of the height turns
  /// a long poster's arch into a dome.
  static Path archPath(
    Rect bounds, {
    double pointHeight = 0.34,
    double? pointPixels,
  }) {
    final apex = Offset(bounds.center.dx, bounds.top);
    final headHeight = pointPixels ?? bounds.height * pointHeight;
    final shoulder = bounds.top + headHeight;
    final control =
        pointPixels != null
            ? bounds.top + headHeight * 0.27
            : bounds.top + bounds.height * 0.06;

    return Path()
      ..moveTo(bounds.left, bounds.bottom)
      ..lineTo(bounds.left, shoulder)
      ..quadraticBezierTo(bounds.left, control, apex.dx, apex.dy)
      ..quadraticBezierTo(bounds.right, control, bounds.right, shoulder)
      ..lineTo(bounds.right, bounds.bottom)
      ..close();
  }

  /// A repeating lattice of four-petal shapes, used inside the arch frame.
  static void lattice(
    Canvas canvas,
    Rect bounds,
    Color color, {
    double cell = 46,
  }) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    for (var y = bounds.top; y < bounds.bottom; y += cell) {
      for (var x = bounds.left; x < bounds.right; x += cell) {
        final center = Offset(x + cell / 2, y + cell / 2);
        final petal = Path();

        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          final tip =
              center + Offset(math.cos(angle), math.sin(angle)) * (cell * 0.42);
          final left =
              center +
              Offset(math.cos(angle - 0.8), math.sin(angle - 0.8)) *
                  (cell * 0.2);
          final right =
              center +
              Offset(math.cos(angle + 0.8), math.sin(angle + 0.8)) *
                  (cell * 0.2);

          petal
            ..moveTo(center.dx, center.dy)
            ..quadraticBezierTo(left.dx, left.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(right.dx, right.dy, center.dx, center.dy);
        }

        canvas.drawPath(petal, paint);
      }
    }
  }
}
