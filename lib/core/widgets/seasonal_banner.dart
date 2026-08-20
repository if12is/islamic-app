import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/seasonal_theme.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// The card that appears in Ramadan and on the two Eids.
///
/// Each season gets its **own** picture, not one drawing tinted four ways:
/// Ramadan is a crescent night with a single lantern, the last ten nights are
/// a shaft of light in a dark sky, Fitr is confetti in daylight, and Adha is a
/// dune at dusk. Reusing one composition and swapping the palette is what makes
/// seasonal theming feel like a checkbox rather than an occasion.
class SeasonalBanner extends StatefulWidget {
  const SeasonalBanner({super.key, required this.event, this.hijriDay});

  final SeasonalEvent event;

  /// Day of the month, shown when it is Ramadan.
  final int? hijriDay;

  @override
  State<SeasonalBanner> createState() => _SeasonalBannerState();
}

class _SeasonalBannerState extends State<SeasonalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  @override
  void initState() {
    super.initState();
    if (widget.event != SeasonalEvent.none) {
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
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);
    final phase =
        still ? const AlwaysStoppedAnimation<double>(0.25) : _controller;

    final onCard =
        widget.event == SeasonalEvent.eidFitr ? tokens.ink : Colors.white;

    return Container(
      width: double.infinity,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: AppRadii.lgAll,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: palette.bannerColors,
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: phase,
                builder:
                    (context, _) => CustomPaint(
                      painter: _bannerPainter(
                        widget.event,
                        palette.ornament,
                        phase.value,
                      ),
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 132, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(SeasonalTheme.greetingKey(widget.event)),
                  style: AppTextStyles.display(
                    context,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: onCard,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.tr(SeasonalTheme.subtitleKey(widget.event)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    context,
                    color: onCard.withValues(alpha: 0.78),
                  ),
                ),
                if (widget.hijriDay != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentBright.withValues(alpha: 0.22),
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      AppLocalizations.translate(
                        Localizations.localeOf(context).languageCode,
                        'ramadan_day',
                        replacements: {'day': widget.hijriDay!.toString()},
                      ),
                      style: AppTextStyles.caption(
                        context,
                        color: palette.accentBright,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _bannerPainter(
    SeasonalEvent event,
    Color colour,
    double phase,
  ) {
    switch (event) {
      case SeasonalEvent.ramadan:
        return _CrescentNightPainter(colour: colour, phase: phase);
      case SeasonalEvent.lastTenNights:
        return _NightOfPowerPainter(colour: colour, phase: phase);
      case SeasonalEvent.eidFitr:
        return _FestivePainter(colour: colour, phase: phase);
      case SeasonalEvent.eidAdha:
        return _DuskDunePainter(colour: colour, phase: phase);
      case SeasonalEvent.none:
        return _CrescentNightPainter(colour: colour, phase: phase);
    }
  }
}

/// **Ramadan** — a crescent low on the right, a scatter of stars, and one
/// lantern swinging from the top corner. Quiet, nocturnal, uncrowded.
class _CrescentNightPainter extends CustomPainter {
  const _CrescentNightPainter({required this.colour, required this.phase});

  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.80, size.height * 0.52);
    final radius = size.height * 0.30;

    // The moon glows a little, slowly.
    final beat = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
    canvas.drawCircle(
      centre,
      radius * 1.9,
      Paint()
        ..color = colour.withValues(alpha: 0.06 + beat * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final full =
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius));
    final cut =
        Path()..addOval(
          Rect.fromCircle(
            center: centre.translate(radius * 0.46, -radius * 0.20),
            radius: radius * 0.92,
          ),
        );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      Paint()..color = colour.withValues(alpha: 0.9),
    );

    final random = math.Random(3);
    for (var i = 0; i < 12; i++) {
      final point = Offset(
        random.nextDouble() * size.width * 0.72,
        random.nextDouble() * size.height * 0.75,
      );
      final twinkle = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 1.6 + i);
      canvas.drawCircle(
        point,
        0.9 + twinkle * 0.9,
        Paint()..color = colour.withValues(alpha: 0.12 + twinkle * 0.22),
      );
    }

    // One lantern, on a cord, swinging gently.
    final anchorX = size.width * 0.60;
    final swing = math.sin(phase * 2 * math.pi) * 0.07;
    canvas
      ..save()
      ..translate(anchorX, 0)
      ..rotate(swing);

    const cord = 26.0;
    canvas.drawLine(
      Offset.zero,
      const Offset(0, cord),
      Paint()
        ..color = colour.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );

    const half = 9.0;
    const height = 28.0;
    final body =
        Path()
          ..moveTo(-half * 0.5, cord)
          ..lineTo(half * 0.5, cord)
          ..lineTo(half, cord + height * 0.22)
          ..lineTo(half, cord + height * 0.8)
          ..lineTo(half * 0.55, cord + height)
          ..lineTo(-half * 0.55, cord + height)
          ..lineTo(-half, cord + height * 0.8)
          ..lineTo(-half, cord + height * 0.22)
          ..close();

    canvas
      ..drawPath(body, Paint()..color = colour.withValues(alpha: 0.22))
      ..drawPath(
        body,
        Paint()
          ..color = colour.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      )
      ..drawCircle(
        const Offset(0, cord + height * 0.55),
        3.4,
        Paint()
          ..color = colour.withValues(alpha: 0.4 + beat * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _CrescentNightPainter old) =>
      old.phase != phase || old.colour != colour;
}

/// **The last ten nights** — a shaft of light coming down through a dark sky,
/// and stars thick behind it. No moon, no lantern: the night it points at is
/// the subject.
class _NightOfPowerPainter extends CustomPainter {
  const _NightOfPowerPainter({required this.colour, required this.phase});

  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final apex = Offset(size.width * 0.78, -size.height * 0.35);
    final breathe = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);

    for (var i = 0; i < 3; i++) {
      final spread = size.width * (0.10 + i * 0.07);
      final beam =
          Path()
            ..moveTo(apex.dx, apex.dy)
            ..lineTo(apex.dx - spread, size.height)
            ..lineTo(apex.dx + spread * 0.7, size.height)
            ..close();

      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.16 + breathe * 0.08 - i * 0.04),
              colour.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    final random = math.Random(19);
    for (var i = 0; i < 30; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final twinkle = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 2.2 + i * 0.8);
      canvas.drawCircle(
        point,
        0.7 + twinkle * 1.5,
        Paint()..color = colour.withValues(alpha: 0.14 + twinkle * 0.42),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NightOfPowerPainter old) =>
      old.phase != phase || old.colour != colour;
}

/// **Eid al-Fitr** — daylight: a string of pennants along the top and confetti
/// drifting down. Nothing nocturnal at all; the month is over.
class _FestivePainter extends CustomPainter {
  const _FestivePainter({required this.colour, required this.phase});

  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final sag = 16 + math.sin(phase * 2 * math.pi) * 2.5;
    final string =
        Path()
          ..moveTo(0, 8)
          ..quadraticBezierTo(size.width / 2, 8 + sag, size.width, 4);

    canvas.drawPath(
      string,
      Paint()
        ..color = colour.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    const flags = 9;
    for (var i = 0; i <= flags; i++) {
      final t = i / flags;
      final y = (1 - t) * (1 - t) * 8 + 2 * (1 - t) * t * (8 + sag) + t * t * 4;
      final x = size.width * t;

      canvas.drawPath(
        Path()
          ..moveTo(x - 5, y)
          ..lineTo(x + 5, y)
          ..lineTo(x, y + 13)
          ..close(),
        Paint()..color = colour.withValues(alpha: i.isEven ? 0.55 : 0.30),
      );
    }

    final random = math.Random(7);
    for (var i = 0; i < 16; i++) {
      final baseX = random.nextDouble() * size.width;
      final speed = 0.5 + random.nextDouble() * 0.7;
      final y = ((phase * speed + random.nextDouble()) % 1) * size.height;
      final x = baseX + math.sin(phase * 2 * math.pi + i) * 8;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(phase * 2 * math.pi + i)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 6, height: 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = colour.withValues(alpha: 0.5),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FestivePainter old) =>
      old.phase != phase || old.colour != colour;
}

/// **Eid al-Adha** — a low sun over two dunes, with a sheep standing on the
/// near ridge. Earthbound and warm, where the others are skyward.
class _DuskDunePainter extends CustomPainter {
  const _DuskDunePainter({required this.colour, required this.phase});

  final Color colour;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final sun = Offset(size.width * 0.78, size.height * 0.42);
    final beat = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);

    canvas
      ..drawCircle(
        sun,
        size.height * 0.34,
        Paint()
          ..color = colour.withValues(alpha: 0.08 + beat * 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      )
      ..drawCircle(
        sun,
        size.height * 0.15,
        Paint()..color = colour.withValues(alpha: 0.55),
      );

    // Far dune, then near dune, drifting very slightly against each other.
    final drift = math.sin(phase * 2 * math.pi) * 5;
    for (var layer = 0; layer < 2; layer++) {
      final base = size.height - layer * 14;
      final path =
          Path()
            ..moveTo(-20, size.height)
            ..lineTo(-20, base - 22)
            ..quadraticBezierTo(
              size.width * 0.28 + drift * (layer + 1),
              base - 46 + layer * 10,
              size.width * 0.62,
              base - 18,
            )
            ..quadraticBezierTo(
              size.width * 0.86 - drift,
              base - 34,
              size.width + 20,
              base - 26,
            )
            ..lineTo(size.width + 20, size.height)
            ..close();

      canvas.drawPath(
        path,
        Paint()..color = colour.withValues(alpha: layer == 0 ? 0.14 : 0.22),
      );
    }

    _sheep(canvas, Offset(size.width * 0.66, size.height - 26), 15);
  }

  /// A sheep in silhouette: a woolly body, a head, four legs.
  void _sheep(Canvas canvas, Offset feet, double scale) {
    final paint = Paint()..color = colour.withValues(alpha: 0.75);
    final bodyCentre = feet.translate(0, -scale * 0.75);

    for (final offset in [-0.55, -0.2, 0.2, 0.55]) {
      canvas.drawRect(
        Rect.fromLTWH(
          bodyCentre.dx + offset * scale,
          bodyCentre.dy + scale * 0.25,
          scale * 0.13,
          scale * 0.6,
        ),
        paint,
      );
    }

    for (final bump in [-0.55, -0.2, 0.15, 0.5]) {
      canvas.drawCircle(
        bodyCentre.translate(bump * scale, -scale * 0.1),
        scale * 0.42,
        paint,
      );
    }

    final head = bodyCentre.translate(scale * 0.85, -scale * 0.28);
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: head,
          width: scale * 0.55,
          height: scale * 0.42,
        ),
        paint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: head.translate(-scale * 0.1, -scale * 0.24),
          width: scale * 0.42,
          height: scale * 0.22,
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _DuskDunePainter old) =>
      old.phase != phase || old.colour != colour;
}
