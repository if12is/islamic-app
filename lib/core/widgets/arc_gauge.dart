import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// The countdown, drawn as a half-circle from one prayer to the next.
///
/// A line of text saying "2h 14m left" is information; this is a picture of
/// where the day is. The track runs from the prayer just gone to the one
/// coming, the filled part is how much of that window has passed, and both
/// ends are labelled so the arc needs no legend.
///
/// It fills in the reading direction: left-to-right in English, **right-to-left
/// in Arabic**, with the prayer already behind you at the start of that
/// direction. An arc that fills against the language reads as a mistake even
/// when the numbers are right.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.progress,
    required this.headline,
    this.headlineSuffix,
    this.caption,
    this.startLabel,
    this.endLabel,
    this.startTime,
    this.endTime,
    this.startIcon = Icons.wb_twilight,
    this.endIcon = Icons.nights_stay_outlined,
    this.size = 268,
    this.footnote,
    this.remaining,
  });

  /// 0 at the previous prayer, 1 at the next one.
  final double progress;

  /// The big number in the middle — usually the time of the next prayer.
  final String headline;

  /// "ص" / "PM" — set smaller and raised beside the headline.
  final String? headlineSuffix;

  /// What the number is ("Maghrib · 42 min").
  final String? caption;

  /// The prayer just gone, and the one coming.
  final String? startLabel;
  final String? endLabel;
  final String? startTime;
  final String? endTime;
  final IconData startIcon;
  final IconData endIcon;

  /// A small line above the headline — the place the times are for.
  final String? footnote;

  /// "٤٢ د" — how long is left, shown in the gap between the two feet.
  final String? remaining;

  final double size;

  static const double _stroke = 20;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final ratio = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth
                ? math.min(size, constraints.maxWidth)
                : size;
        return SizedBox(
          width: width,
          // Room for the arc plus the two feet under it.
          height: width * 0.5 + _stroke + 74,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                child: SizedBox(
                  width: width,
                  height: width * 0.5 + _stroke,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: AppMotion.slow,
                          curve: AppMotion.enter,
                          builder:
                              (context, animated, _) => CustomPaint(
                                painter: _ArcPainter(
                                  progress: animated,
                                  rightToLeft: isRtl,
                                  track: tokens.groundAlt,
                                  from: tokens.brandDeep,
                                  to: tokens.brand,
                                  head: tokens.goldBright,
                                  glow: tokens.brand.withValues(alpha: 0.20),
                                ),
                              ),
                        ),
                      ),
                      Positioned(
                        top: width * 0.16,
                        left: _stroke * 2,
                        right: _stroke * 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (footnote != null)
                              Text(
                                footnote!,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(
                                  context,
                                  color: tokens.inkFaint,
                                  fontSize: 11.5,
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headline,
                                    style: AppTextStyles.display(
                                      context,
                                      fontSize: 38,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  if (headlineSuffix != null) ...[
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        headlineSuffix!,
                                        style: AppTextStyles.caption(
                                          context,
                                          color: tokens.inkMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (caption != null)
                              Text(
                                caption!,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(
                                  context,
                                  color: tokens.inkMuted,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // The two feet sit under the ends of the arc, in reading order:
              // what has passed first, what is coming last.
              PositionedDirectional(
                start: 0,
                bottom: 0,
                child: _Foot(
                  icon: startIcon,
                  label: startLabel,
                  time: startTime,
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: _Foot(
                  icon: endIcon,
                  label: endLabel,
                  time: endTime,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One end of the arc: an icon, the prayer, and its time.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.icon,
    this.label,
    this.time,
    this.alignEnd = false,
  });

  final IconData icon;
  final String? label;
  final String? time;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (label == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tokens.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: tokens.brand),
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              context,
              color: tokens.inkFaint,
              fontSize: 11.5,
            ),
          ),
          if (time != null)
            Text(
              time!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.display(
                context,
                fontSize: 14,
                color: tokens.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.rightToLeft,
    required this.track,
    required this.from,
    required this.to,
    required this.head,
    required this.glow,
  });

  final double progress;

  /// Fill from the right in Arabic, from the left in English.
  final bool rightToLeft;

  final Color track;
  final Color from;
  final Color to;
  final Color head;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = ArcGauge._stroke;
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 2;
    final centre = Offset(size.width / 2, size.height - stroke / 2 - 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0.001) {
      return;
    }

    // In Arabic the sweep runs backwards from the right-hand foot.
    final sweep = math.pi * progress * (rightToLeft ? -1 : 1);
    final start = rightToLeft ? 2 * math.pi : math.pi;

    canvas
      ..drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = glow
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: math.pi,
            endAngle: 2 * math.pi,
            colors: rightToLeft ? [to, from] : [from, to],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );

    // The knob marks where the day has got to.
    final angle = start + sweep;
    final knob = Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );
    canvas
      ..drawCircle(knob, stroke * 0.48, Paint()..color = head)
      ..drawCircle(
        knob,
        stroke * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress ||
      old.rightToLeft != rightToLeft ||
      old.from != from ||
      old.track != track;
}
