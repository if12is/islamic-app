import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/qibla_math.dart';
import '../../../../core/widgets/app_section.dart';

/// A compass that tells you when you are facing the Kaaba without being
/// looked at.
///
/// The dial stays muted until you are close, warms through gold, and turns
/// green when you are on it. Haptics tighten as the angle closes — far away a
/// slow tap, near the qibla a quick pulse, and landing on it a single firm
/// confirmation. That way the phone can be held at chest height, in a dark
/// room, and still guide you. The sentence underneath is the part that makes
/// it usable: a number is not an instruction.
class QiblaCompass extends StatefulWidget {
  const QiblaCompass({
    super.key,
    required this.qiblaBearing,
    required this.alignedText,
    this.size = 280,
  });

  final double qiblaBearing;
  final String alignedText;

  final double size;

  /// Within this many degrees counts as facing the qibla.
  static const double alignedThreshold = QiblaMath.alignedThreshold;

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  StreamSubscription<CompassEvent>? _subscription;
  Timer? _hapticTimer;

  double _heading = 0;
  double? _accuracy;
  bool _hasSensor = true;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _hasSensor = false;
      return;
    }

    final events = FlutterCompass.events;
    if (events == null) {
      _hasSensor = false;
      return;
    }

    _subscription = events.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) {
        return;
      }

      setState(() {
        // Low-pass filter: raw compass data jitters by several degrees and a
        // needle that shivers is unusable.
        _heading = QiblaMath.smooth(_heading, heading);
        _accuracy = event.accuracy;
      });

      _updateHaptics(_difference(_heading));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hapticTimer?.cancel();
    super.dispose();
  }

  double _difference(double heading) =>
      QiblaMath.difference(heading, widget.qiblaBearing);

  /// Which way is shorter, and by how much.
  double get _signedOffset {
    final raw = (widget.qiblaBearing - _heading) % 360;
    return raw > 180 ? raw - 360 : raw;
  }

  /// Pulse faster the closer the phone gets, and confirm once on arrival.
  void _updateHaptics(double difference) {
    if (QiblaMath.isAligned(difference)) {
      _hapticTimer?.cancel();
      _hapticTimer = null;
      if (!_wasAligned) {
        _wasAligned = true;
        HapticFeedback.heavyImpact();
      }
      return;
    }

    _wasAligned = false;
    final interval = QiblaMath.hapticInterval(difference);
    if (interval == null) {
      // Pointing away from the qibla: stay quiet rather than buzz constantly.
      _hapticTimer?.cancel();
      _hapticTimer = null;
      return;
    }

    if (_hapticTimer?.isActive ?? false) {
      return;
    }
    _hapticTimer = Timer(interval, () {
      if (!mounted) {
        return;
      }
      if (difference < 20) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    });
  }

  /// "Turn 135° to the left" — the sentence that makes the dial actionable.
  String _instruction(BuildContext context) {
    if (!_hasSensor) {
      return context.tr('qibla_no_sensor');
    }
    final offset = _signedOffset;
    if (QiblaMath.isAligned(offset.abs())) {
      return widget.alignedText;
    }

    final degrees = offset.abs().round();
    final key = offset > 0 ? 'qibla_turn_right' : 'qibla_turn_left';
    return AppLocalizations.translate(
      Localizations.localeOf(context).languageCode,
      key,
      replacements: {'degrees': '$degrees'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final difference = _difference(_heading);
    final isAligned = QiblaMath.isAligned(difference);

    // Muted when off, warming through gold as it closes, green on target.
    final closeness = (1 - (difference / 90)).clamp(0.0, 1.0);
    final dialColor =
        isAligned
            ? tokens.brand
            : Color.lerp(tokens.inkFaint, tokens.goldBright, closeness)!;

    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The dial turns with the phone, so north stays north.
              AnimatedRotation(
                duration: const Duration(milliseconds: 120),
                turns: -_heading / 360,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _DialPainter(
                    face: tokens.surface,
                    ring: tokens.line,
                    tick: tokens.inkFaint.withValues(alpha: 0.55),
                    label: tokens.inkMuted,
                    marker: dialColor,
                    qiblaBearing: widget.qiblaBearing,
                    isAligned: isAligned,
                    shadow: tokens.ink,
                  ),
                ),
              ),
              // The needle points at the qibla relative to the phone.
              AnimatedRotation(
                duration: const Duration(milliseconds: 120),
                turns: (widget.qiblaBearing - _heading) / 360,
                child: CustomPaint(
                  size: Size.square(widget.size * 0.82),
                  painter: _NeedlePainter(
                    color: dialColor,
                    tail: tokens.inkFaint.withValues(alpha: 0.30),
                    pivotFill: tokens.surface,
                  ),
                ),
              ),
              // A fixed pointer at the top: line the needle up with this.
              PositionedDirectional(
                top: 0,
                child: Icon(Icons.arrow_drop_down, size: 30, color: dialColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedDefaultTextStyle(
          duration: AppMotion.base,
          style: AppTextStyles.display(
            context,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: isAligned ? tokens.brand : tokens.ink,
          ),
          child: Text('${difference.round()}°'),
        ),
        Text(
          context.tr('qibla_angle_caption'),
          style: AppTextStyles.caption(context, color: tokens.inkFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        HintPill(
          text: _instruction(context),
          icon:
              !_hasSensor
                  ? Icons.explore_off_outlined
                  : isAligned
                  ? Icons.check_circle
                  : (_signedOffset > 0
                      ? Icons.rotate_right
                      : Icons.rotate_left),
          tone: isAligned ? HintTone.success : HintTone.neutral,
        ),
        if (_hasSensor && (_accuracy ?? 0) > 15) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('qibla_calibrate'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context, color: tokens.danger),
          ),
        ],
      ],
    );
  }
}

/// The dial: a soft face, a thin ring, quarter dots, cardinal letters, and a
/// Kaaba marker sitting on the ring at the qibla bearing.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.face,
    required this.ring,
    required this.tick,
    required this.label,
    required this.marker,
    required this.qiblaBearing,
    required this.isAligned,
    required this.shadow,
  });

  final Color face;
  final Color ring;
  final Color tick;
  final Color label;
  final Color marker;
  final double qiblaBearing;
  final bool isAligned;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 14;

    canvas
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = shadow.withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      )
      ..drawCircle(centre, radius, Paint()..color = face)
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      )
      ..drawCircle(
        centre,
        radius * 0.72,
        Paint()
          ..color = ring.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    // Four dots on the diagonals — enough orientation without a ruler face.
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.72),
        2.5,
        Paint()..color = tick,
      );
    }

    const letters = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < letters.length; i++) {
      final angle = -math.pi / 2 + i * math.pi / 2;
      final painter = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            fontFamily: AppTextStyles.bodyFamily,
            fontSize: 13,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
            color: label,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final position =
          centre +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 0.86) -
          Offset(painter.width / 2, painter.height / 2);
      painter.paint(canvas, position);
    }

    // The Kaaba sits on the ring where the qibla is.
    final qiblaAngle = (qiblaBearing - 90) * math.pi / 180;
    final markerCentre =
        centre + Offset(math.cos(qiblaAngle), math.sin(qiblaAngle)) * radius;

    canvas.drawCircle(markerCentre, 15, Paint()..color = marker);
    if (isAligned) {
      canvas.drawCircle(
        markerCentre,
        22,
        Paint()
          ..color = marker.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    final kaaba = Rect.fromCenter(center: markerCentre, width: 12, height: 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kaaba, const Radius.circular(2)),
      Paint()..color = face,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.qiblaBearing != qiblaBearing ||
      old.marker != marker ||
      old.isAligned != isAligned;
}

/// The needle: a slim blade towards the qibla, a faint tail behind, and a
/// round pivot that hides where the two meet.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({
    required this.color,
    required this.tail,
    required this.pivotFill,
  });

  final Color color;
  final Color tail;
  final Color pivotFill;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final length = size.height / 2;

    final blade =
        Path()
          ..moveTo(centre.dx, centre.dy - length)
          ..lineTo(centre.dx - 7, centre.dy + 6)
          ..lineTo(centre.dx + 7, centre.dy + 6)
          ..close();
    canvas.drawPath(blade, Paint()..color = color);

    final back =
        Path()
          ..moveTo(centre.dx, centre.dy + length * 0.52)
          ..lineTo(centre.dx - 5, centre.dy - 4)
          ..lineTo(centre.dx + 5, centre.dy - 4)
          ..close();
    canvas.drawPath(back, Paint()..color = tail);

    canvas
      ..drawCircle(centre, 11, Paint()..color = color)
      ..drawCircle(centre, 6, Paint()..color = pivotFill);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter old) => old.color != color;
}
