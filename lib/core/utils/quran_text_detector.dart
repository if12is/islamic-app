import '../../features/quran/data/services/quran_local_service.dart';

/// A run of text that is either revelation or ordinary words.
class ArabicSegment {
  const ArabicSegment({required this.text, required this.isQuran});

  final String text;
  final bool isQuran;
}

/// Tells Quranic text apart from du'a and dhikr prose.
///
/// Azkar collections mix the two freely — a chapter may open with Ayat
/// al-Kursi and continue with a supplication — and the app renders each in its
/// own face. Detection is exact, not fuzzy: a line counts as revelation only
/// when it actually appears in the bundled Mushaf.
class QuranTextDetector {
  QuranTextDetector._();

  /// Explicit verse markers used by most datasets.
  static final RegExp _bracketed = RegExp(r'[﴿\{]([^﴾\}]+)[﴾\}]');

  /// Short lines match too easily ("الحمد لله"), so require some length.
  static const int _minNormalizedLength = 14;

  /// Share of a passage's four-word windows that must exist in the Mushaf.
  ///
  /// Quoted verses score 0.8-1.0 even across spelling differences; du'a that
  /// borrows a Quranic phrase or two lands at 0.5 or below.
  static const double _quranicThreshold = 0.6;

  static final Map<String, List<ArabicSegment>> _cache = {};
  static const int _cacheLimit = 400;

  /// Split [text] into runs, marking the Quranic ones.
  ///
  /// Consecutive runs of the same kind are merged, so the caller renders one
  /// span per block rather than one per line.
  static List<ArabicSegment> segment(String text) {
    final cached = _cache[text];
    if (cached != null) {
      return cached;
    }

    final segments = <ArabicSegment>[];
    for (final line in _split(text)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final isQuran = isQuranic(trimmed);
      if (segments.isNotEmpty && segments.last.isQuran == isQuran) {
        final merged = '${segments.last.text}\n$trimmed';
        segments[segments.length - 1] = ArabicSegment(
          text: merged,
          isQuran: isQuran,
        );
      } else {
        segments.add(ArabicSegment(text: trimmed, isQuran: isQuran));
      }
    }

    if (segments.isEmpty) {
      segments.add(ArabicSegment(text: text.trim(), isQuran: false));
    }

    if (_cache.length >= _cacheLimit) {
      _cache.clear();
    }
    _cache[text] = segments;
    return segments;
  }

  /// True when [line] is a verse, or a run of verses, from the Mushaf.
  static bool isQuranic(String line) => quranicScore(line) >= _quranicThreshold;

  /// How much of [line] is Quran: 0 for none of it, 1 for all of it.
  ///
  /// Short fragments cannot be scored by windows, so they fall back to an
  /// exact lookup — and anything shorter than a few words is never treated as
  /// revelation, because phrases like "الحمد لله" appear in both.
  static double quranicScore(String line) {
    final cleaned = line.replaceAll(RegExp(r'[﴿﴾\{\}\[\]]'), '');
    final normalized = QuranLocalService.normalizeArabic(cleaned);
    if (normalized.length < _minNormalizedLength) {
      return 0;
    }

    final words =
        QuranLocalService.skeleton(
          cleaned,
        ).split(' ').where((word) => word.isNotEmpty).toList();

    if (words.length < QuranLocalService.ngramSize) {
      return QuranLocalService.normalizedCorpus().contains(normalized) ? 1 : 0;
    }

    final ngrams = QuranLocalService.quranNgrams();
    var hits = 0;
    var windows = 0;

    for (var i = 0; i + QuranLocalService.ngramSize <= words.length; i++) {
      windows++;
      final hash = QuranLocalService.windowHash(words, i);
      if (hash != null && ngrams.contains(hash)) {
        hits++;
      }
    }

    return windows == 0 ? 0 : hits / windows;
  }

  /// Break text where a dataset would break it: newlines, then verse markers.
  static Iterable<String> _split(String text) sync* {
    for (final line in text.split(RegExp(r'[\n\r]+'))) {
      if (line.trim().isEmpty) {
        continue;
      }

      // A bracketed verse inside a longer line becomes its own segment.
      final matches = _bracketed.allMatches(line).toList();
      if (matches.isEmpty) {
        yield line;
        continue;
      }

      var cursor = 0;
      for (final match in matches) {
        if (match.start > cursor) {
          yield line.substring(cursor, match.start);
        }
        yield match.group(1)!;
        cursor = match.end;
      }
      if (cursor < line.length) {
        yield line.substring(cursor);
      }
    }
  }

  /// Drops memoized segmentation; used by tests.
  static void resetCache() => _cache.clear();
}
