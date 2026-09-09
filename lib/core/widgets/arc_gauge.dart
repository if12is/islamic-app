import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import '../utils/duration_words.dart';

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
///
/// The big number in the middle is **how long is left**, not what time the
/// prayer is. Four time-shaped numbers used to share this widget — the next
/// prayer's clock time set large, both feet, and the countdown in a small gold
/// pill at the bottom — and the one people open the app to read was the
/// smallest of them. The clock time has not gone anywhere: it is on the foot it
/// belongs to, and named again under the countdown.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.progress,
    required this.headline,
    this.headlineParts = const [],
    this.caption,
    this.startLabel,
    this.endLabel,
    this.startTime,
    this.endTime,
    this.startIcon = Icons.wb_twilight_rounded,
    this.endIcon = Icons.bedtime_rounded,
    this.size = 268,
    this.footnote,
  });

  /// 0 at the previous prayer, 1 at the next one.
  final double progress;

  /// The countdown as one line — read aloud, and drawn when there are no
  /// [headlineParts] to set instead ("—", "حان الآن").
  final String headline;

  /// The countdown split into counted parts, so the digits can be set large
  /// and the words that name them small.
  ///
  /// Set as one string at 38px, "ساعتان و٥٩ دقيقة" has to shrink to about a
  /// third of that to fit between the arms of the arc — ending up smaller than
  /// the caption beneath it, which is the opposite of the point. Splitting it
  /// keeps the numbers at full size and spends the saved width on the words.
  final List<DurationPart> headlineParts;

  /// What the countdown runs to ("حتى العصر · ٤:٢٧ م").
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
        return Semantics(
          // Read as one sentence. Left to itself a screen reader announces the
          // pieces in painting order — a stray "4:27", a place name, two
          // prayer names — and the listener has to assemble the countdown
          // from fragments.
          container: true,
          label: [
            headline,
            if (caption != null) caption,
            if (footnote != null) footnote,
          ].join('، '),
          child: ExcludeSemantics(
            child: SizedBox(
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
                                      glow: tokens.brand.withValues(
                                        alpha: 0.20,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          Positioned(
                            // The countdown is words, not four digits, so it needs
                            // the width the clock time did not.
                            top: width * 0.15,
                            left: _stroke * 1.1,
                            right: _stroke * 1.1,
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
                                  child:
                                      headlineParts.isEmpty
                                          ? Text(
                                            headline,
                                            maxLines: 1,
                                            style: AppTextStyles.display(
                                              context,
                                              fontSize: 38,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700,
                                              color: tokens.ink,
                                            ),
                                          )
                                          : _Countdown(parts: headlineParts),
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
                                      fontSize: 13.5,
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
            ),
          ),
        );
      },
    );
  }
}

/// "٢ ساعة ٥٩ دقيقة" — digits at full size, the words that name them small.
///
/// The words sit on the digits' baseline rather than being centred against
/// them, which is how a clock face sets a unit beside a number and what keeps
/// the line from looking like two sizes of the same sentence.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.parts});

  final List<DurationPart> parts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Arabic joins "and" to the word after it with no space, so it is a
    // prefix on the next part rather than a separator between two. English
    // has no word here at all and the gap does the joining.
    final conjunction = context.tr('and_prefix');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          if (parts[i].value != null) ...[
            Text(
              '${i > 0 ? conjunction : ''}${parts[i].value}',
              maxLines: 1,
              style: AppTextStyles.display(
                context,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            parts[i].value == null && i > 0
                ? '$conjunction${parts[i].unit}'
                : parts[i].unit,
            maxLines: 1,
            style: AppTextStyles.body(
              context,
              // A dual like "ساعتان" is the number as well as the word, so it
              // is set at the size a number gets.
              fontSize: parts[i].value == null ? 24 : 15,
              fontWeight:
                  parts[i].value == null ? FontWeight.w700 : FontWeight.w600,
              color: parts[i].value == null ? tokens.ink : tokens.inkMuted,
            ),
          ),
        ],
      ],
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

    // A soft foot where the fill begins, so it grows out of the track rather
    // than appearing as a cut half-circle.
    canvas.drawCircle(
      Offset(centre.dx + radius * (rightToLeft ? 1 : -1), centre.dy),
      stroke / 2,
      Paint()..color = Color.lerp(track, from, 0.55)!,
    );

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
          // Linear across the arc's box, not swept: a sweep gradient measured
          // in absolute angles leaves the right-to-left arc outside its range,
          // so it clamps to one colour and shows a hard seam at the start.
          ..shader = LinearGradient(
            begin: rightToLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: rightToLeft ? Alignment.centerLeft : Alignment.centerRight,
            colors: [from, to, head],
            stops: const [0.0, 0.62, 1.0],
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
