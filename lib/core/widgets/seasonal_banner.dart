import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/seasonal_theme.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'islamic_ornaments.dart';

/// The decorated header that appears in Ramadan and on the two Eids.
///
/// Everything is drawn — lanterns, a crescent, a sheep — so the app carries a
/// festive look without shipping images, and the decoration scales cleanly on
/// any screen.
class SeasonalBanner extends StatelessWidget {
  const SeasonalBanner({super.key, required this.event, this.hijriDay});

  final SeasonalEvent event;

  /// Day of the month, shown when it is Ramadan.
  final int? hijriDay;

  @override
  Widget build(BuildContext context) {
    final palette = SeasonalTheme.paletteFor(event);
    if (palette == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      height: 138,
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
            child: CustomPaint(
              painter: _SeasonalOrnamentPainter(
                event: event,
                color: palette.ornament,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 140, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(SeasonalTheme.greetingKey(event)),
                  style: AppTextStyles.display(
                    context,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.tr(SeasonalTheme.subtitleKey(event)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    context,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (hijriDay != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentBright.withValues(alpha: 0.22),
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      AppLocalizations.translate(
                        Localizations.localeOf(context).languageCode,
                        'ramadan_day',
                        replacements: {'day': hijriDay!.toString()},
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
}

/// Draws the season's decoration on the banner.
class _SeasonalOrnamentPainter extends CustomPainter {
  const _SeasonalOrnamentPainter({required this.event, required this.color});

  final SeasonalEvent event;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    IslamicOrnaments.stars(canvas, size, color);

    switch (event) {
      case SeasonalEvent.ramadan:
      case SeasonalEvent.lastTenNights:
        IslamicOrnaments.crescent(
          canvas,
          Offset(size.width * 0.18, size.height * 0.34),
          26,
          color.withValues(alpha: 0.9),
        );
        IslamicOrnaments.lantern(
          canvas,
          top: Offset(size.width * 0.34, 0),
          width: 46,
          cordLength: size.height * 0.30,
          color: color,
        );
        IslamicOrnaments.lantern(
          canvas,
          top: Offset(size.width * 0.20, 0),
          width: 34,
          cordLength: size.height * 0.16,
          color: color,
        );
        IslamicOrnaments.lantern(
          canvas,
          top: Offset(size.width * 0.08, 0),
          width: 40,
          cordLength: size.height * 0.24,
          color: color,
        );
      case SeasonalEvent.eidFitr:
        IslamicOrnaments.crescent(
          canvas,
          Offset(size.width * 0.16, size.height * 0.32),
          28,
          color.withValues(alpha: 0.9),
        );
        _confetti(canvas, size);
      case SeasonalEvent.eidAdha:
        IslamicOrnaments.crescent(
          canvas,
          Offset(size.width * 0.14, size.height * 0.28),
          24,
          color.withValues(alpha: 0.9),
        );
        _sheep(canvas, Offset(size.width * 0.26, size.height * 0.70), 30);
      case SeasonalEvent.none:
        break;
    }
  }

  /// Falling confetti for Eid al-Fitr.
  void _confetti(Canvas canvas, Size size) {
    final random = math.Random(19);
    for (var i = 0; i < 22; i++) {
      final rect = Rect.fromLTWH(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
        4,
        7,
      );
      canvas
        ..save()
        ..translate(rect.center.dx, rect.center.dy)
        ..rotate(random.nextDouble() * math.pi)
        ..translate(-rect.center.dx, -rect.center.dy)
        ..drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          Paint()..color = color.withValues(alpha: 0.5),
        )
        ..restore();
    }
  }

  /// A sheep silhouette for Eid al-Adha.
  void _sheep(Canvas canvas, Offset center, double size) {
    final wool = Paint()..color = color.withValues(alpha: 0.85);
    final dark = Paint()..color = color.withValues(alpha: 0.45);

    for (final offset in const [
      Offset(-0.34, 0.0),
      Offset(-0.12, -0.16),
      Offset(0.12, -0.10),
      Offset(0.0, 0.10),
      Offset(-0.22, 0.14),
    ]) {
      canvas.drawCircle(
        center.translate(offset.dx * size, offset.dy * size),
        size * 0.30,
        wool,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(size * 0.42, size * 0.02),
        width: size * 0.34,
        height: size * 0.42,
      ),
      dark,
    );
    for (final dx in [-0.28, -0.06, 0.16]) {
      canvas.drawRect(
        Rect.fromLTWH(
          center.dx + dx * size,
          center.dy + size * 0.28,
          size * 0.08,
          size * 0.30,
        ),
        dark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeasonalOrnamentPainter oldDelegate) =>
      oldDelegate.event != event || oldDelegate.color != color;
}
