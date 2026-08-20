import '../../data/services/quran_local_service.dart';

/// One candidate answer to "which verse was that?".
class VerseMatch {
  const VerseMatch({
    required this.surahNumber,
    required this.verseNumber,
    required this.score,
    required this.text,
  });

  final int surahNumber;
  final int verseNumber;

  /// Share of the heard words that landed in this verse, 0 to 1.
  final double score;

  final String text;

  /// Confident enough to state rather than suggest.
  bool get isConfident => score >= 0.6;
}

/// Finds where in the Mushaf a recitation came from.
///
/// The idea is borrowed from the "Quranic verse recognition" projects doing
/// the rounds: recite anything and be told the surah and ayah. Those run a
/// model in the cloud; this runs on a word index built from the bundled text,
/// so it costs nothing, works in airplane mode, and answers instantly.
///
/// It searches on the alef-stripped skeleton, because whatever recogniser
/// produced the transcript writes modern orthography while the Mushaf uses the
/// Uthmani one — matching those letter for letter fails on almost every verse.
class VerseFinder {
  VerseFinder._();

  /// Words that carry no identifying weight: they appear in hundreds of verses
  /// and would make every search return al-Baqarah.
  static const Set<String> _stopWords = {
    'من',
    'ما',
    'لا',
    'ان',
    'في',
    'علي',
    'الي',
    'عن',
    'هو',
    'هي',
    'ثم',
    'قد',
    'كل',
    'بل',
    'او',
    'يا',
    'به',
    'لم',
    'لن',
    'اذ',
    'اذا',
  };

  /// verse key ("2:255") for every word, built once and kept.
  static Map<String, List<String>>? _index;

  /// Build the word index: each distinctive word to the verses it appears in.
  static Map<String, List<String>> index() {
    if (_index != null) {
      return _index!;
    }

    final index = <String, List<String>>{};
    for (var surah = 1; surah <= QuranLocalService.surahCount; surah++) {
      final count = QuranLocalService.surahInfo(surah).versesCount;
      for (var ayah = 1; ayah <= count; ayah++) {
        final key = '$surah:$ayah';
        final words = QuranLocalService.skeleton(
          QuranLocalService.verse(surah, ayah).text,
        ).split(' ');

        for (final word in words.toSet()) {
          if (word.length < 3 || _stopWords.contains(word)) {
            continue;
          }
          index.putIfAbsent(word, () => <String>[]).add(key);
        }
      }
    }
    return _index = index;
  }

  /// The verses that best match [heard], best first.
  ///
  /// Returns an empty list when nothing was said, or when what was said has
  /// nothing to do with the Quran — a wrong answer stated confidently would be
  /// worse than no answer at all.
  static List<VerseMatch> search(String heard, {int limit = 5}) {
    final words =
        QuranLocalService.skeleton(heard)
            .split(' ')
            .where((word) => word.length >= 3 && !_stopWords.contains(word))
            .toList();

    if (words.length < 2) {
      return const [];
    }

    final table = index();
    final hits = <String, int>{};

    for (final word in words.toSet()) {
      final verses = table[word];
      if (verses == null) {
        continue;
      }
      // A word found in half the Mushaf tells us nothing; skip it rather than
      // let it drown the verses that actually match.
      if (verses.length > 400) {
        continue;
      }
      for (final key in verses) {
        hits[key] = (hits[key] ?? 0) + 1;
      }
    }

    if (hits.isEmpty) {
      return const [];
    }

    final ranked =
        hits.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final distinct = words.toSet().length;
    final results = <VerseMatch>[];

    for (final entry in ranked.take(limit)) {
      final parts = entry.key.split(':');
      final surah = int.parse(parts[0]);
      final ayah = int.parse(parts[1]);

      results.add(
        VerseMatch(
          surahNumber: surah,
          verseNumber: ayah,
          score: (entry.value / distinct).clamp(0.0, 1.0),
          text: QuranLocalService.verse(surah, ayah).text,
        ),
      );
    }

    return results;
  }
}
