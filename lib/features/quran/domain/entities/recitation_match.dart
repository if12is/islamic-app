import 'dart:math' as math;

import '../../data/services/quran_local_service.dart';

/// How a single expected word came out.
enum RecitationWordStatus {
  /// Not reached yet.
  pending,

  /// Said as written.
  correct,

  /// Close, but not exact — usually the recognizer's spelling, sometimes a
  /// genuine slip. Worth a second look rather than a verdict.
  near,

  /// Skipped, or something else was said in its place.
  wrong,
}

/// One expected word and its verdict.
class RecitationWord {
  const RecitationWord({required this.text, required this.status, this.heard});

  final String text;
  final RecitationWordStatus status;

  /// What the recognizer produced for this word, when anything did.
  final String? heard;

  RecitationWord copyWith({RecitationWordStatus? status, String? heard}) =>
      RecitationWord(
        text: text,
        status: status ?? this.status,
        heard: heard ?? this.heard,
      );
}

/// The result of comparing a recitation against the text.
class RecitationResult {
  const RecitationResult({required this.words, required this.reached});

  final List<RecitationWord> words;

  /// How far into the passage the reciter has got.
  final int reached;

  int get correct =>
      words.where((w) => w.status == RecitationWordStatus.correct).length;

  int get near =>
      words.where((w) => w.status == RecitationWordStatus.near).length;

  int get wrong =>
      words.where((w) => w.status == RecitationWordStatus.wrong).length;

  int get graded => correct + near + wrong;

  /// Share of what has been attempted that came out right, counting a near
  /// match as half.
  double get accuracy {
    if (graded == 0) {
      return 0;
    }
    return ((correct + near * 0.5) / graded).clamp(0.0, 1.0).toDouble();
  }

  bool get isComplete => reached >= words.length;

  static const RecitationResult empty = RecitationResult(words: [], reached: 0);
}

/// Compares what was recited against what is written.
///
/// Speech recognition of Quranic recitation is never word-perfect: engines
/// return modern spelling, drop elongations, and merge words. So the check is
/// an alignment, not an equality test — each expected word is matched to the
/// nearest heard word, and anything close is flagged rather than failed. What
/// the app shows is a reading aid, not a ruling.
class RecitationMatcher {
  RecitationMatcher._();

  /// Similarity above which two words count as the same.
  static const double exactThreshold = 0.92;

  /// Similarity above which a word is "close" instead of wrong.
  static const double nearThreshold = 0.68;

  /// Compare [heard] against the [expected] passage.
  ///
  /// Words after the last recognized one stay [RecitationWordStatus.pending],
  /// so a passage in progress is never marked wrong for what has not been
  /// said yet.
  static RecitationResult compare({
    required String expected,
    required String heard,
  }) {
    final expectedWords = _words(expected);
    final heardWords = _words(heard);

    if (expectedWords.isEmpty) {
      return RecitationResult.empty;
    }

    final statuses = List<RecitationWordStatus>.filled(
      expectedWords.length,
      RecitationWordStatus.pending,
    );
    final matches = List<String?>.filled(expectedWords.length, null);

    if (heardWords.isEmpty) {
      return RecitationResult(
        words: [
          for (var i = 0; i < expectedWords.length; i++)
            RecitationWord(
              text: expectedWords[i].original,
              status: statuses[i],
            ),
        ],
        reached: 0,
      );
    }

    // Walk both sequences, allowing a small lookahead on each side so a
    // dropped or inserted word does not knock the rest out of step.
    var expectedIndex = 0;
    var heardIndex = 0;
    var reached = 0;

    while (expectedIndex < expectedWords.length &&
        heardIndex < heardWords.length) {
      final expectedWord = expectedWords[expectedIndex];
      final heardWord = heardWords[heardIndex];
      final score = similarity(expectedWord.normalized, heardWord.normalized);

      if (score >= nearThreshold) {
        statuses[expectedIndex] =
            score >= exactThreshold
                ? RecitationWordStatus.correct
                : RecitationWordStatus.near;
        matches[expectedIndex] = heardWord.original;
        expectedIndex++;
        heardIndex++;
        reached = expectedIndex;
        continue;
      }

      // Did the reciter skip a word? Look a little ahead in the text.
      final skipAhead = _lookahead(
        expectedWords,
        expectedIndex + 1,
        heardWord.normalized,
      );

      // Or did the recognizer insert one? Look ahead in what it heard.
      final insertAhead = _lookahead(
        heardWords,
        heardIndex + 1,
        expectedWord.normalized,
      );

      if (skipAhead != null &&
          (insertAhead == null || skipAhead <= insertAhead)) {
        for (var i = expectedIndex; i < skipAhead; i++) {
          statuses[i] = RecitationWordStatus.wrong;
        }
        expectedIndex = skipAhead;
        continue;
      }

      if (insertAhead != null) {
        heardIndex = insertAhead;
        continue;
      }

      statuses[expectedIndex] = RecitationWordStatus.wrong;
      matches[expectedIndex] = heardWord.original;
      expectedIndex++;
      heardIndex++;
      reached = expectedIndex;
    }

    return RecitationResult(
      words: [
        for (var i = 0; i < expectedWords.length; i++)
          RecitationWord(
            text: expectedWords[i].original,
            status: statuses[i],
            heard: matches[i],
          ),
      ],
      reached: reached,
    );
  }

  /// Index of the first word within reach that matches [target], or null.
  static int? _lookahead(
    List<_Word> words,
    int from,
    String target, {
    int window = 2,
  }) {
    final end = math.min(from + window, words.length);
    for (var i = from; i < end; i++) {
      if (similarity(words[i].normalized, target) >= nearThreshold) {
        return i;
      }
    }
    return null;
  }

  /// 1 for identical words, 0 for nothing in common.
  ///
  /// Compares on the alef-insensitive skeleton, because recognizers write
  /// modern orthography while the Mushaf uses the Uthmani one.
  static double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    if (a == b) {
      return 1;
    }

    final distance = _levenshtein(a, b);
    final longest = math.max(a.length, b.length);
    return (1 - distance / longest).clamp(0.0, 1.0).toDouble();
  }

  static int _levenshtein(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[b.length];
  }

  static List<_Word> _words(String text) {
    final originals =
        text
            .split(RegExp(r'\s+'))
            .where((word) => word.trim().isNotEmpty)
            .toList();

    return [
      for (final original in originals)
        _Word(
          original: original,
          normalized: QuranLocalService.skeleton(original),
        ),
    ]..removeWhere((word) => word.normalized.isEmpty);
  }
}

class _Word {
  const _Word({required this.original, required this.normalized});

  final String original;
  final String normalized;
}
