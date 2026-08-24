/// What a shared verse video or image should look like, and how long it runs.
///
/// Pure data: no colours, no widgets, no plugins. The frame widget turns a
/// [VideoPalette] into actual paint and the encoder turns a [VideoTimeline]
/// into a file, but the decisions — which verses, how big the type, how long
/// each verse stays on screen — are all made here where they can be tested.
library;

/// The colour world of the exported card.
enum VideoPalette { emerald, night, parchment, mihrab, dawn }

/// The motif drawn faintly behind the text.
enum VideoPattern { none, stars, arabesque, rays }

/// Output shape. The three that social platforms actually accept.
enum VideoAspect {
  /// 1080×1080 — feeds and WhatsApp.
  square(1080, 1080),

  /// 1080×1920 — stories and reels.
  portrait(1080, 1920),

  /// 1920×1080 — YouTube and a television.
  landscape(1920, 1080);

  const VideoAspect(this.width, this.height);

  final int width;
  final int height;

  double get ratio => width / height;
}

/// One verse holding the screen for as long as it is recited.
class VideoSegment {
  const VideoSegment({required this.verseNumber, required this.duration});

  final int verseNumber;
  final Duration duration;
}

/// The running order of a video: which verse is on screen, and until when.
class VideoTimeline {
  const VideoTimeline(this.segments);

  final List<VideoSegment> segments;

  static const VideoTimeline empty = VideoTimeline([]);

  bool get isEmpty => segments.isEmpty;

  Duration get total =>
      segments.fold(Duration.zero, (sum, segment) => sum + segment.duration);

  /// Which verse is showing at [position].
  ///
  /// Past the end it stays on the last verse rather than going blank — a
  /// video whose final frame is empty looks like it failed.
  int? verseAt(Duration position) {
    if (segments.isEmpty) {
      return null;
    }
    var elapsed = Duration.zero;
    for (final segment in segments) {
      elapsed += segment.duration;
      if (position < elapsed) {
        return segment.verseNumber;
      }
    }
    return segments.last.verseNumber;
  }

  /// Where each verse starts, for a progress bar or a seek.
  List<Duration> get starts {
    final starts = <Duration>[];
    var elapsed = Duration.zero;
    for (final segment in segments) {
      starts.add(elapsed);
      elapsed += segment.duration;
    }
    return starts;
  }

  /// Build a timeline from measured audio lengths, in verse order.
  ///
  /// A verse whose audio could not be measured still gets a turn: it is given
  /// [fallback] rather than being dropped, because a video that silently skips
  /// an ayah is worse than one that lingers a moment too long on it.
  static VideoTimeline fromDurations(
    Map<int, Duration?> durations, {
    Duration fallback = const Duration(seconds: 6),
  }) {
    final verses = durations.keys.toList()..sort();
    return VideoTimeline([
      for (final verse in verses)
        VideoSegment(
          verseNumber: verse,
          duration: _sane(durations[verse]) ?? fallback,
        ),
    ]);
  }

  /// A zero or absurd duration is a failed probe, not a real measurement.
  static Duration? _sane(Duration? value) {
    if (value == null || value <= Duration.zero) {
      return null;
    }
    return value > const Duration(minutes: 5) ? null : value;
  }
}

/// Everything the studio needs to render and export one passage.
class AyahVideoSpec {
  const AyahVideoSpec({
    required this.surahNumber,
    required this.fromVerse,
    required this.toVerse,
    required this.reciterCode,
    this.fontFamily = 'AmiriQuran',
    this.fontSize = 56,
    this.palette = VideoPalette.emerald,
    this.pattern = VideoPattern.arabesque,
    this.aspect = VideoAspect.portrait,
    this.showSurahName = true,
    this.showAppMark = true,
  });

  final int surahNumber;
  final int fromVerse;
  final int toVerse;

  /// Which voice recites it. Verse-by-verse audio, so the passage can be cut
  /// at the ayah — a whole-surah recording has no seam to cut on.
  final String reciterCode;

  final String fontFamily;

  /// Point size on the export canvas, whose width is [VideoAspect.width].
  final double fontSize;

  final VideoPalette palette;
  final VideoPattern pattern;
  final VideoAspect aspect;
  final bool showSurahName;
  final bool showAppMark;

  /// A long passage makes a long file and a slow export, and nobody watches a
  /// twelve-minute verse card. The studio refuses past this and says why.
  static const int maxVerses = 20;

  /// Smallest and largest type the studio will set.
  static const double minFontSize = 28;
  static const double maxFontSize = 110;

  int get verseCount => (toVerse - fromVerse + 1).clamp(0, 1 << 20);

  List<int> get verseNumbers => [
    for (var verse = fromVerse; verse <= toVerse; verse++) verse,
  ];

  bool get isTooLong => verseCount > maxVerses;

  /// Type that fits without the studio having to be told.
  ///
  /// Sized off the longest verse in the passage, not the average: the card is
  /// one fixed size, so the verse that overflows is the one that decides.
  static double suggestedFontSize(
    Iterable<String> verses, {
    VideoAspect aspect = VideoAspect.portrait,
  }) {
    if (verses.isEmpty) {
      return 56;
    }
    final longest = verses
        .map((text) => text.length)
        .reduce((a, b) => a > b ? a : b);

    final base = switch (longest) {
      <= 60 => 92.0,
      <= 120 => 76.0,
      <= 200 => 64.0,
      <= 320 => 54.0,
      <= 500 => 44.0,
      <= 800 => 36.0,
      _ => 30.0,
    };

    // A square has far less vertical room than a story for the same width.
    final roomFactor = switch (aspect) {
      VideoAspect.portrait => 1.0,
      VideoAspect.square => 0.82,
      VideoAspect.landscape => 0.7,
    };

    return (base * roomFactor).clamp(minFontSize, maxFontSize).toDouble();
  }

  AyahVideoSpec copyWith({
    int? surahNumber,
    int? fromVerse,
    int? toVerse,
    String? reciterCode,
    String? fontFamily,
    double? fontSize,
    VideoPalette? palette,
    VideoPattern? pattern,
    VideoAspect? aspect,
    bool? showSurahName,
    bool? showAppMark,
  }) {
    final from = fromVerse ?? this.fromVerse;
    final to = toVerse ?? this.toVerse;
    return AyahVideoSpec(
      surahNumber: surahNumber ?? this.surahNumber,
      fromVerse: from,
      // Keep the range the right way round however the sliders were dragged.
      toVerse: to < from ? from : to,
      reciterCode: reciterCode ?? this.reciterCode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize:
          (fontSize ?? this.fontSize)
              .clamp(minFontSize, maxFontSize)
              .toDouble(),
      palette: palette ?? this.palette,
      pattern: pattern ?? this.pattern,
      aspect: aspect ?? this.aspect,
      showSurahName: showSurahName ?? this.showSurahName,
      showAppMark: showAppMark ?? this.showAppMark,
    );
  }

  /// `an-nasr_1-3` — a file name someone can find again in their gallery.
  String fileStem(String surahSlug) =>
      fromVerse == toVerse
          ? '${surahSlug}_$fromVerse'
          : '${surahSlug}_$fromVerse-$toVerse';
}
