import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/islamic_ornaments.dart';
import '../../data/services/quran_local_service.dart';

/// The cover: the surah's name in naskh, inside a mihrab, on tilework.
///
/// Two covers came before this. An eight-pointed star, the same on every
/// surah — a picture of nothing in particular. Then the name in the display
/// face over a brush-stroke wash with two leafy sprigs, which read as a
/// greeting card rather than a Mushaf: the ornament of a gift shop, not of a
/// mosque.
///
/// This borrows from where Quranic lettering actually lives. The ground is
/// the eight-fold star-and-cross lattice of mosque tiling, drawn as a pattern
/// rather than shipped as an image — offline, sharp at any size, recoloured by
/// the theme, and owed to no one. It fades toward the middle so it frames the
/// name instead of running through it. The name sits in a pointed arch, in
/// the Mushaf's own face, with the surah's number of verses beneath: the
/// facts a surah heading in a printed Mushaf gives, and nothing invented.
class SurahCoverArt extends StatelessWidget {
  const SurahCoverArt({super.key, required this.size, required this.info});

  final double size;
  final QuranSurahInfo info;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;
    final isArabic = language == 'ar';

    // Deep green in both themes: it is a tile, not a card, and a tile does
    // not turn pale in daylight. The cream is whichever of the two themes'
    // warm whites is not the page behind it.
    final top =
        Color.lerp(tokens.brandDeep, tokens.brand, tokens.isDark ? 0.28 : 0.5)!;
    final bottom =
        tokens.isDark
            ? Color.lerp(tokens.brandDeep, Colors.black, 0.35)!
            : tokens.brandDeep;
    final cream = tokens.isDark ? tokens.ink : tokens.ground;
    final gold = tokens.goldBright;

    final verses = localizeDigitsFor(language, '${info.versesCount}');
    final meta = [
      context.tr(info.isMeccan ? 'surah_type_meccan' : 'surah_type_medinan'),
      '$verses ${context.tr(_versesKey(info.versesCount, isArabic))}',
    ].join(' · ');

    final radius = BorderRadius.circular(size * 0.11);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _TilePainter(
                    gold: gold,
                    niche: bottom,
                    radius: size * 0.11,
                  ),
                ),
              ),
            ),
            // Inside the arch: its shoulders are at about a third of the
            // height and its foot near the bottom, so the lettering is held
            // there and never crosses the frame, whatever the font does.
            Positioned(
              left: size * 0.25,
              right: size * 0.25,
              top: size * 0.31,
              bottom: size * 0.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isArabic ? 'سُورَةُ' : info.nameEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      fontSize: size * 0.048,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: cream.withValues(alpha: 0.78),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        info.nameAr,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        style: AppTextStyles.quran(
                          context,
                          // Sized off the tile, not fixed: the tile shrinks on
                          // a short screen and the name has to shrink with it.
                          fontSize: size * 0.15,
                          height: 1.45,
                          color: cream,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: size * 0.3,
                    height: size * 0.05,
                    child: CustomPaint(painter: _RulePainter(gold)),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      fontSize: size * 0.042,
                      height: 1.4,
                      color: cream.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Arabic counts verses in two forms here: three to ten take the plural
  /// ("٧ آيات"), everything else the singular ("٢٨٦ آية") — decided by the
  /// last two digits, so 110 is "آيات" like 10. No surah has one or two.
  static String _versesKey(int count, bool isArabic) {
    if (!isArabic) {
      return 'verses_short';
    }
    final lastTwo = count % 100;
    return lastTwo >= 3 && lastTwo <= 10 ? 'verses_plural_few' : 'verses_short';
  }
}

/// The tile behind the name: a star-and-cross lattice fading toward the
/// centre, a pointed arch holding the name, and a hairline border inset from
/// the edge the way a printed Mushaf frames its surah headings.
class _TilePainter extends CustomPainter {
  const _TilePainter({
    required this.gold,
    required this.niche,
    required this.radius,
  });

  final Color gold;

  /// The darker green the arch is filled with, so the name has a quiet ground.
  final Color niche;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & size;

    // The lattice, in its own layer so it can be faded out towards the middle.
    canvas.saveLayer(rect, Paint());
    _lattice(canvas, size, cell: s / 5.5, stroke: math.max(0.8, s * 0.0042));
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.55),
            Colors.black,
          ],
          stops: const [0.25, 0.6, 1.0],
        ).createShader(rect),
    );
    canvas.restore();

    // The frame, inset from the edge.
    final inset = s * 0.045;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(inset),
        Radius.circular(math.max(0, radius - inset)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, s * 0.004)
        ..color = gold.withValues(alpha: 0.45),
    );

    // The arch, filled, then outlined twice.
    final arch = Rect.fromLTWH(s * 0.19, s * 0.12, s * 0.62, s * 0.76);
    final outer = IslamicOrnaments.archPath(arch, pointPixels: s * 0.22);
    canvas.drawPath(outer, Paint()..color = niche.withValues(alpha: 0.78));
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.0075)
        ..color = gold.withValues(alpha: 0.9),
    );
    final innerRect = arch.deflate(s * 0.024);
    canvas.drawPath(
      IslamicOrnaments.archPath(innerRect, pointPixels: s * 0.19),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, s * 0.0035)
        ..color = gold.withValues(alpha: 0.45),
    );

    // A small eight-pointed star under the point of the arch.
    _star(
      canvas,
      Offset(s / 2, arch.top + s * 0.14),
      s * 0.032,
      Paint()..color = gold.withValues(alpha: 0.95),
    );
  }

  /// The star-and-cross of Islamic tilework: eight-pointed stars on a square
  /// grid, each the outline of two squares laid across each other, their
  /// points meeting their neighbours' halfway between. The spaces the stars
  /// leave are the four-armed crosses; they are not drawn, they appear.
  void _lattice(
    Canvas canvas,
    Size size, {
    required double cell,
    required double stroke,
  }) {
    final line =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.miter
          ..color = gold.withValues(alpha: 0.5);
    final fill = Paint()..color = gold.withValues(alpha: 0.07);

    // A star sits on the centre, so the pattern is symmetric about the name.
    final centre = size.center(Offset.zero);
    final reach = (size.longestSide / cell / 2).ceil() + 1;
    final outer = cell / 2;
    // Two squares across each other meet at this radius: cos 45° / cos 22.5°.
    final inner = outer * math.cos(math.pi / 4) / math.cos(math.pi / 8);

    for (var i = -reach; i <= reach; i++) {
      for (var j = -reach; j <= reach; j++) {
        final c = centre + Offset(i * cell, j * cell);
        final star = Path();
        for (var k = 0; k < 16; k++) {
          final angle = k * math.pi / 8;
          final radius = k.isEven ? outer : inner;
          final point = c + Offset(math.cos(angle), math.sin(angle)) * radius;
          if (k == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        star.close();
        canvas
          ..drawPath(star, fill)
          ..drawPath(star, line)
          // A small rosette at the heart of every star.
          ..drawCircle(c, cell * 0.16, line);
      }
    }
  }

  /// An eight-pointed star, filled.
  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi / 2 + i * math.pi / 8;
      final radius = i.isEven ? r : r * 0.55;
      final point = c + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.gold != gold || old.niche != niche || old.radius != radius;
}

/// A hairline with a diamond in the middle, between the name and the facts.
class _RulePainter extends CustomPainter {
  const _RulePainter(this.gold);

  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final d = size.height * 0.22;
    final line =
        Paint()
          ..strokeWidth = math.max(0.8, size.height * 0.05)
          ..color = gold.withValues(alpha: 0.7);
    canvas
      ..drawLine(Offset(0, y), Offset(size.width / 2 - d * 1.8, y), line)
      ..drawLine(
        Offset(size.width / 2 + d * 1.8, y),
        Offset(size.width, y),
        line,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width / 2, y - d)
          ..lineTo(size.width / 2 + d, y)
          ..lineTo(size.width / 2, y + d)
          ..lineTo(size.width / 2 - d, y)
          ..close(),
        Paint()..color = gold,
      );
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.gold != gold;
}
