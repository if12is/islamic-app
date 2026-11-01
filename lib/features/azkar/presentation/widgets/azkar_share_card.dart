import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/fajr_mark.dart';
import '../../../../core/widgets/motif_icon.dart';
import '../../../../core/widgets/seasonal_art.dart';
import '../../domain/azkar_share_copy.dart';

/// One exported picture of the short morning or evening adhkar.
///
/// Four compositions, not one layout recolored. The type is the thin naskh
/// bundled for these cards. The picture is always Arabic and right to left,
/// whatever language the rest of the app is in.
enum AzkarShareDesign { mist, garden, night, parchment }

class AzkarShareCard extends StatelessWidget {
  const AzkarShareCard({super.key, required this.period, required this.design});

  final AzkarSharePeriod period;
  final AzkarShareDesign design;

  /// A phone status is taller than it is wide.
  static const double width = 1080;
  static const double height = 1920;

  @override
  Widget build(BuildContext context) {
    final title = AzkarShareCopy.title(period);
    final lines = AzkarShareCopy.lines(period);
    return switch (design) {
      AzkarShareDesign.mist => _MistCard(title: title, lines: lines),
      AzkarShareDesign.garden => _GardenCard(title: title, lines: lines),
      AzkarShareDesign.night => _NightCard(title: title, lines: lines),
      AzkarShareDesign.parchment => _ParchmentCard(title: title, lines: lines),
    };
  }
}

TextStyle _naskh(Color color, double size, {double height = 1.72}) {
  return TextStyle(
    fontFamily: AppTextStyles.shareFamily,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.w300,
    fontVariations: const [FontVariation('wght', 260)],
    color: color,
  );
}

TextStyle _display(Color color, double size) {
  return TextStyle(
    fontFamily: AppTextStyles.displayFamily,
    fontSize: size,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

/// Shrinks a tall column of adhkar until it sits in the space it was given.
class _FitLines extends StatelessWidget {
  const _FitLines({
    required this.width,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final double width;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.ink, required this.gold});

  final Color ink;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FajrMark(size: 44, book: ink, sun: gold),
        const SizedBox(width: 14),
        Text('الفجر', style: _display(ink, 32)),
      ],
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel(this.count, {required this.color, this.size = 32});

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }
    return Text(
      '×${toArabicDigits('$count')}',
      style: _naskh(color, size, height: 1.2),
    );
  }
}

class _MistCard extends StatelessWidget {
  const _MistCard({required this.title, required this.lines});

  final String title;
  final List<AzkarShareLine> lines;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.mist;
    return _Canvas(
      color: palette.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(84, 100, 84, 72),
        child: Column(
          children: [
            _MistBadge(title: title),
            const SizedBox(height: 56),
            _FitLines(
              width: AzkarShareCard.width - 168,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 48),
                    Text(
                      lines[i].text,
                      textAlign: TextAlign.center,
                      style: _naskh(palette.ink, 40, height: 1.9),
                    ),
                    _CountLabel(
                      lines[i].count,
                      color: palette.accent,
                      size: 30,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            _AppMark(ink: palette.muted, gold: palette.star),
          ],
        ),
      ),
    );
  }
}

class _MistBadge extends StatelessWidget {
  const _MistBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.mist;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      decoration: BoxDecoration(
        color: palette.badge,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Heart(color: palette.heart, size: 34),
          const SizedBox(width: 14),
          Text(title, style: _naskh(palette.ink, 40, height: 1.2)),
          const SizedBox(width: 14),
          _Star(color: palette.star, size: 34),
        ],
      ),
    );
  }
}

class _GardenCard extends StatelessWidget {
  const _GardenCard({required this.title, required this.lines});

  final String title;
  final List<AzkarShareLine> lines;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.garden;
    return _Canvas(
      color: palette.background,
      child: Stack(
        children: [
          PositionedDirectional(
            top: -120,
            end: -160,
            child: IgnorePointer(
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.accent, width: 3),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(72, 88, 72, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      FajrMark(
                        size: 72,
                        book: palette.star,
                        sun: palette.accent,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(title, style: _display(palette.accent, 64)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 180,
                      height: 4,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _FitLines(
                    width: AzkarShareCard.width - 144,
                    alignment: AlignmentDirectional.topStart,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < lines.length; i++) ...[
                          if (i > 0) const SizedBox(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Medallion(count: lines[i].count),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Text(
                                  lines[i].text,
                                  textAlign: TextAlign.start,
                                  style: _naskh(palette.ink, 36, height: 1.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'الفجر',
                    textAlign: TextAlign.center,
                    style: _display(palette.muted, 30),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.garden;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
      child: Text(
        toArabicDigits('$count'),
        style: _display(palette.onAccent, 32),
      ),
    );
  }
}

class _NightCard extends StatelessWidget {
  const _NightCard({required this.title, required this.lines});

  final String title;
  final List<AzkarShareLine> lines;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.night;
    return _Canvas(
      color: palette.background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.backgroundAlt, palette.background],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(80, 72, 80, 64),
          child: Column(
            children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StarFieldPainter(palette.star),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CustomPaint(
                              painter: MotifPainter(
                                motif: Motif.crescentStar,
                                color: palette.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Text(title, style: _display(palette.accent, 48)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _FitLines(
                width: AzkarShareCard.width - 160,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(height: 22),
                        _Star(color: palette.accent, size: 18),
                        const SizedBox(height: 22),
                      ],
                      Text(
                        lines[i].text,
                        textAlign: TextAlign.center,
                        style: _naskh(palette.ink, 36, height: 1.75),
                      ),
                      _CountLabel(lines[i].count, color: palette.accent),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _AppMark(ink: palette.muted, gold: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParchmentCard extends StatelessWidget {
  const _ParchmentCard({required this.title, required this.lines});

  final String title;
  final List<AzkarShareLine> lines;

  @override
  Widget build(BuildContext context) {
    const palette = AzkarSharePalette.parchment;
    return _Canvas(
      color: palette.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: CardCorners(color: palette.accent, size: 72, inset: 28),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: palette.accent, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Star(color: palette.accent, size: 22),
                              const SizedBox(width: 16),
                              Text(title, style: _display(palette.accent, 52)),
                              const SizedBox(width: 16),
                              _Star(color: palette.accent, size: 22),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(height: 1, color: palette.accent),
                          const SizedBox(height: 24),
                          _FitLines(
                            width: AzkarShareCard.width - 224,
                            alignment: AlignmentDirectional.topStart,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < lines.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 26),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: Column(
                                          children: [
                                            Text(
                                              toArabicDigits('${i + 1}'),
                                              style: _display(
                                                palette.accent,
                                                32,
                                              ),
                                            ),
                                            _CountLabel(
                                              lines[i].count,
                                              color: palette.muted,
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          lines[i].text,
                                          textAlign: TextAlign.justify,
                                          style: _naskh(
                                            palette.ink,
                                            34,
                                            height: 1.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('الفجر', style: _display(palette.muted, 28)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A shared picture has a fixed composition. The phone's text size
    // would otherwise blow the lines out of the frame.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: AzkarShareCard.width,
          height: AzkarShareCard.height,
          child: ColoredBox(color: color, child: child),
        ),
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _HeartPainter(color));
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(size.width * 0.5, size.height * 0.86)
          ..cubicTo(
            size.width * 0.5,
            size.height * 0.86,
            size.width * 0.08,
            size.height * 0.58,
            size.width * 0.08,
            size.height * 0.36,
          )
          ..cubicTo(
            size.width * 0.08,
            size.height * 0.18,
            size.width * 0.22,
            size.height * 0.1,
            size.width * 0.36,
            size.height * 0.1,
          )
          ..cubicTo(
            size.width * 0.44,
            size.height * 0.1,
            size.width * 0.5,
            size.height * 0.18,
            size.width * 0.5,
            size.height * 0.26,
          )
          ..cubicTo(
            size.width * 0.5,
            size.height * 0.18,
            size.width * 0.56,
            size.height * 0.1,
            size.width * 0.64,
            size.height * 0.1,
          )
          ..cubicTo(
            size.width * 0.78,
            size.height * 0.1,
            size.width * 0.92,
            size.height * 0.18,
            size.width * 0.92,
            size.height * 0.36,
          )
          ..cubicTo(
            size.width * 0.92,
            size.height * 0.58,
            size.width * 0.5,
            size.height * 0.86,
            size.width * 0.5,
            size.height * 0.86,
          )
          ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Star extends StatelessWidget {
  const _Star({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _StarPainter(color));
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.42;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter(this.color);

  final Color color;

  static const List<Offset> _points = [
    Offset(0.08, 0.18),
    Offset(0.18, 0.42),
    Offset(0.3, 0.12),
    Offset(0.42, 0.55),
    Offset(0.58, 0.2),
    Offset(0.7, 0.48),
    Offset(0.82, 0.16),
    Offset(0.92, 0.4),
    Offset(0.14, 0.78),
    Offset(0.88, 0.72),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.85);
    for (var i = 0; i < _points.length; i++) {
      final point = _points[i];
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        i.isEven ? 4 : 2.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
