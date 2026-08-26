import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// The Al-Fajr symbol: the sun clearing the open mushaf.
///
/// Drawn rather than loaded. The mark is a circle and a six-point polygon on a
/// 120-unit square, so a painter is both smaller than any bitmap and sharp at
/// every size — and, unlike an asset, it can take its colours from the theme,
/// which is what lets one widget serve the cream screens and the night ones.
///
/// The geometry is the same as `scripts/brand_assets.py`, which renders the
/// launcher and status-bar icons. Change one and change the other.
class FajrMark extends StatelessWidget {
  const FajrMark({
    super.key,
    this.size = 48,
    this.book,
    this.sun,
    this.monochrome = false,
  });

  final double size;

  /// Defaults to the theme's brand green and gold.
  final Color? book;
  final Color? sun;

  /// One flat colour, with the kerf cut so the two shapes stay countable.
  ///
  /// This is what the mark looks like in a status bar or on a themed icon: not
  /// a second palette, but the same drawing with the colour taken away.
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bookColour = book ?? tokens.brand;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FajrMarkPainter(
          book: bookColour,
          sun: monochrome ? bookColour : (sun ?? tokens.gold),
          kerf: monochrome,
        ),
      ),
    );
  }
}

/// The numbers the mark is made of.
///
/// Public so a test can hold them against the approved drawing. They are the
/// same values `scripts/brand_assets.py` renders the launcher and status-bar
/// icons from — if these two ever disagree, the app ships two logos.
class FajrMarkGeometry {
  FajrMarkGeometry._();

  /// The square everything below is described on.
  static const double units = 120;

  static const Offset sunCentre = Offset(60, 58);
  static const double sunRadius = 26;

  /// The open mushaf: one band whose top edge dips at the gutter.
  static const List<Offset> bookPoints = [
    Offset(12, 60),
    Offset(60, 74),
    Offset(108, 60),
    Offset(108, 78),
    Offset(60, 92),
    Offset(12, 78),
  ];

  /// The gap cut between the disc and the band when both are one colour.
  static const double kerfWidth = 8;
}

class _FajrMarkPainter extends CustomPainter {
  const _FajrMarkPainter({
    required this.book,
    required this.sun,
    required this.kerf,
  });

  final Color book;
  final Color sun;
  final bool kerf;

  static const double units = FajrMarkGeometry.units;
  static const Offset sunCentre = FajrMarkGeometry.sunCentre;
  static const double sunRadius = FajrMarkGeometry.sunRadius;
  static const List<Offset> bookPoints = FajrMarkGeometry.bookPoints;
  static const double kerfWidth = FajrMarkGeometry.kerfWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / units;
    canvas.save();
    canvas.scale(scale);

    final bookPath = Path()..addPolygon(bookPoints, true);

    if (kerf) {
      // A layer, so the kerf can be cleared out of the sun before the book is
      // laid over it. Erasing straight onto the canvas would take the screen
      // behind it away too.
      canvas.saveLayer(const Rect.fromLTWH(0, 0, units, units), Paint());
    }

    canvas.drawCircle(sunCentre, sunRadius, Paint()..color = sun);

    if (kerf) {
      // The gap runs along the book's top edge. In one flat colour the disc
      // and the band would otherwise touch and read as a single lump — this
      // is what keeps the notification icon legible at 24 px.
      canvas.drawPath(
        Path()..addPolygon(bookPoints.sublist(0, 3), false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kerfWidth
          ..strokeJoin = StrokeJoin.miter
          ..blendMode = BlendMode.clear,
      );
    }

    canvas.drawPath(bookPath, Paint()..color = book);

    if (kerf) {
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FajrMarkPainter old) =>
      old.book != book || old.sun != sun || old.kerf != kerf;
}

/// The mark with the name under it — the vertical lockup from the identity.
///
/// Below 96 logical pixels wide the Latin line goes first and the Arabic
/// second, because a wordmark too small to read is noise rather than a name.
class FajrLockup extends StatelessWidget {
  const FajrLockup({super.key, this.markSize = 96});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final showLatin = markSize >= 64;
    final showArabic = markSize >= 40;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FajrMark(size: markSize),
        if (showArabic) ...[
          SizedBox(height: markSize * 0.18),
          Text(
            'الفجر',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppTextStyles.displayFamily,
              fontSize: markSize * 0.42,
              height: 1,
              fontWeight: FontWeight.w600,
              color: tokens.brand,
            ),
          ),
        ],
        if (showLatin) ...[
          SizedBox(height: markSize * 0.16),
          // Letter spacing is added after every glyph, the last one included,
          // so a tracked word carries a trailing gap and hangs left of centre.
          // Padding the leading edge by the same amount puts it back.
          Padding(
            padding: EdgeInsets.only(left: markSize * 0.105 * 0.44),
            child: Text(
              'FAJR',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: AppTextStyles.bodyFamily,
                fontSize: markSize * 0.105,
                fontWeight: FontWeight.w600,
                // Tracking is part of the wordmark, not a flourish.
                letterSpacing: markSize * 0.105 * 0.44,
                color: tokens.gold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
