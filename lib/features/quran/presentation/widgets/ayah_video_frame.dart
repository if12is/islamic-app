import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/islamic_ornaments.dart';
import '../../data/services/quran_local_service.dart';
import '../../domain/ayah_video_spec.dart';

/// One frame of a verse video — and, on its own, the shareable still image.
///
/// It is laid out at the export resolution rather than at screen size, so what
/// the studio previews and what lands in the gallery are the same composition
/// scaled, not two designs that drift apart. The preview simply shrinks it.
///
/// The whole passage is on screen at once with the verse being recited lit and
/// the rest dimmed. That is how a page of the Mushaf actually reads: you see
/// where you are inside the passage, not one line floating alone.
class AyahVideoFrame extends StatelessWidget {
  const AyahVideoFrame({
    super.key,
    required this.spec,
    required this.verses,
    this.activeVerse,
  });

  final AyahVideoSpec spec;

  /// The passage, in order.
  final List<QuranVerse> verses;

  /// Which verse is being recited right now. Null lights all of them, which is
  /// what a still image wants.
  final int? activeVerse;

  @override
  Widget build(BuildContext context) {
    final theme = VideoFrameTheme.of(spec.palette);
    final width = spec.aspect.width.toDouble();
    final height = spec.aspect.height.toDouble();

    // Everything scales off the short edge, so a story and a square are the
    // same design rather than the same numbers in a different box.
    final unit = math.min(width, height);
    final margin = unit * 0.062;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(gradient: theme.background),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PatternPainter(
                pattern: spec.pattern,
                color: theme.ornament,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(margin),
              child: CustomPaint(
                painter: _FramePainter(color: theme.hairline, unit: unit),
                child: Padding(
                  padding: EdgeInsets.all(unit * 0.055),
                  child: Column(
                    children: [
                      if (spec.showSurahName) _header(theme, unit),
                      Expanded(child: Center(child: _body(theme, unit))),
                      if (spec.showAppMark) _footer(theme, unit),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(VideoFrameTheme theme, double unit) {
    final surahName =
        verses.isEmpty
            ? ''
            : QuranLocalService.surahInfo(verses.first.surahNumber).nameAr;

    return Padding(
      padding: EdgeInsets.only(bottom: unit * 0.03),
      child: Column(
        children: [
          Text(
            'سورة $surahName',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: unit * 0.045,
              height: 1.4,
              color: theme.accent,
            ),
          ),
          SizedBox(height: unit * 0.012),
          Text(
            _rangeLabel(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: unit * 0.028,
              color: theme.muted,
            ),
          ),
          SizedBox(height: unit * 0.022),
          _rule(theme, unit),
        ],
      ),
    );
  }

  String _rangeLabel() {
    if (verses.isEmpty) {
      return '';
    }
    final first = arabicDigits(verses.first.numberInSurah);
    if (verses.length == 1) {
      return 'الآية $first';
    }
    return 'الآيات $first – ${arabicDigits(verses.last.numberInSurah)}';
  }

  Widget _rule(VideoFrameTheme theme, double unit) {
    final line = Expanded(child: Container(height: 1.5, color: theme.hairline));
    return Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: unit * 0.02),
          child: Icon(
            Icons.brightness_1,
            size: unit * 0.012,
            color: theme.accent,
          ),
        ),
        line,
      ],
    );
  }

  Widget _body(VideoFrameTheme theme, double unit) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: unit * 0.045,
        vertical: unit * 0.05,
      ),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(unit * 0.035),
      ),
      child: Text.rich(
        TextSpan(children: _spans(theme)),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: spec.fontFamily,
          fontSize: spec.fontSize,
          height: 2.05,
          color: theme.text,
        ),
      ),
    );
  }

  List<InlineSpan> _spans(VideoFrameTheme theme) {
    final spans = <InlineSpan>[];

    for (final verse in verses) {
      // Dim the verses that are not being recited so the eye lands on the one
      // that is. With no active verse — a still image — nothing is dimmed.
      final lit = activeVerse == null || verse.numberInSurah == activeVerse;
      final colour = lit ? theme.text : theme.textDim;

      spans.add(
        TextSpan(text: '${verse.text} ', style: TextStyle(color: colour)),
      );
      spans.add(
        TextSpan(
          text: '﴿${arabicDigits(verse.numberInSurah)}﴾ ',
          style: TextStyle(
            color: lit ? theme.accent : theme.accent.withValues(alpha: 0.35),
            fontSize: spec.fontSize * 0.72,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _footer(VideoFrameTheme theme, double unit) {
    return Padding(
      padding: EdgeInsets.only(top: unit * 0.03),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mosque, size: unit * 0.03, color: theme.muted),
          SizedBox(width: unit * 0.014),
          Text(
            'الفجر · تطبيق إسلامي',
            style: TextStyle(
              fontFamily: 'ReemKufi',
              fontSize: unit * 0.026,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// ٢٤ — the numerals the rest of the card is set in.
  static String arabicDigits(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }
}

/// The paint behind a [VideoPalette].
///
/// These are export colours, fixed to the file rather than to the app theme: a
/// card someone shares should look the same whatever theme they had open when
/// they made it, and should not change under them next time the app is styled.
class VideoFrameTheme {
  const VideoFrameTheme({
    required this.background,
    required this.panel,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.muted,
    required this.hairline,
    required this.ornament,
  });

  final Gradient background;

  /// The soft plate the verse sits on. Transparent where the design wants the
  /// text straight on the ground.
  final Color panel;

  final Color text;

  /// The verses that are not being recited.
  final Color textDim;

  final Color accent;
  final Color muted;
  final Color hairline;
  final Color ornament;

  static VideoFrameTheme of(VideoPalette palette) => switch (palette) {
    VideoPalette.emerald => const VideoFrameTheme(
      background: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF04241A), Color(0xFF0A5F46), Color(0xFF04241A)],
      ),
      panel: Color(0x14FFFFFF),
      text: Color(0xFFF6FBF8),
      textDim: Color(0x59F6FBF8),
      accent: Color(0xFFE9C349),
      muted: Color(0xB3F6FBF8),
      hairline: Color(0x59E9C349),
      ornament: Color(0x1FE9C349),
    ),
    VideoPalette.night => const VideoFrameTheme(
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF07090D), Color(0xFF1A2430)],
      ),
      panel: Color(0x12FFFFFF),
      text: Color(0xFFEEF2F6),
      textDim: Color(0x52EEF2F6),
      accent: Color(0xFF7FD8B6),
      muted: Color(0xADEEF2F6),
      hairline: Color(0x4D7FD8B6),
      ornament: Color(0x1A7FD8B6),
    ),
    VideoPalette.parchment => const VideoFrameTheme(
      background: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF9F1DE), Color(0xFFE7D3AE)],
      ),
      panel: Color(0x33FFFFFF),
      text: Color(0xFF3A2C12),
      textDim: Color(0x593A2C12),
      accent: Color(0xFF8A5A17),
      muted: Color(0xB33A2C12),
      hairline: Color(0x668A5A17),
      ornament: Color(0x1F8A5A17),
    ),
    VideoPalette.mihrab => const VideoFrameTheme(
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1D33), Color(0xFF123A52), Color(0xFF07131F)],
      ),
      panel: Color(0x14FFFFFF),
      text: Color(0xFFF4EFE3),
      textDim: Color(0x54F4EFE3),
      accent: Color(0xFFD8A657),
      muted: Color(0xB0F4EFE3),
      hairline: Color(0x54D8A657),
      ornament: Color(0x1CD8A657),
    ),
    VideoPalette.dawn => const VideoFrameTheme(
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF7DFC8), Color(0xFFE8B79B), Color(0xFFB98A85)],
      ),
      panel: Color(0x2EFFFFFF),
      text: Color(0xFF2E1D2B),
      textDim: Color(0x5E2E1D2B),
      accent: Color(0xFF12503C),
      muted: Color(0xB32E1D2B),
      hairline: Color(0x6612503C),
      ornament: Color(0x2312503C),
    ),
  };
}

/// The thin frame with corner marks that says "this is a card, not a crop".
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color, required this.unit});

  final Color color;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.0035;

    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, stroke);

    // Corner brackets, drawn inside the frame line.
    final inset = unit * 0.022;
    final arm = unit * 0.05;
    final inner = bounds.deflate(inset);

    for (final (corner, dx, dy) in [
      (inner.topLeft, 1.0, 1.0),
      (inner.topRight, -1.0, 1.0),
      (inner.bottomLeft, 1.0, -1.0),
      (inner.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * arm, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy * arm),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.color != color || old.unit != unit;
}

/// The motif behind the text. Deterministic — a random scatter that changed
/// between frames would strobe in the finished video.
class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.pattern, required this.color});

  final VideoPattern pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case VideoPattern.none:
        return;
      case VideoPattern.stars:
        IslamicOrnaments.stars(canvas, size, color, count: 120, seed: 11);
      case VideoPattern.arabesque:
        _eightPointTiles(canvas, size);
      case VideoPattern.rays:
        _rays(canvas, size);
    }
  }

  /// A grid of eight-pointed stars — the khatim, the most common tile in
  /// Islamic ornament and the one that reads at any size.
  void _eightPointTiles(Canvas canvas, Size size) {
    final cell = size.shortestSide * 0.19;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.0022;

    for (var y = -cell; y < size.height + cell; y += cell) {
      for (var x = -cell; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x + cell / 2, y + cell / 2), cell * 0.42, paint);
      }
    }
  }

  void _star(Canvas canvas, Offset centre, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.42;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  /// Light falling from the top corner, the way it does through a lattice.
  void _rays(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.5, -size.height * 0.15);
    final paint = Paint()..color = color;
    final reach = size.height * 1.7;

    for (var i = 0; i < 22; i++) {
      final angle = math.pi / 2 + (i - 11) * 0.075;
      final spread = 0.022;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(
            origin.dx + math.cos(angle - spread) * reach,
            origin.dy + math.sin(angle - spread) * reach,
          )
          ..lineTo(
            origin.dx + math.cos(angle + spread) * reach,
            origin.dy + math.sin(angle + spread) * reach,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern || old.color != color;
}
