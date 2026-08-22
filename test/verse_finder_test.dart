import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/domain/entities/verse_match.dart';

/// "Which verse was that?" has to be right, or silent.
///
/// A confident wrong answer about the Qur'an is worse than no answer, so the
/// finder is tested both ways: it must locate a verse from a rough transcript,
/// and it must decline when what it heard was not Qur'an at all.
void main() {
  group('Finding a verse from what was heard', () {
    test('locates a famous verse from its own words', () {
      final matches = VerseFinder.search(
        'الله لا اله الا هو الحي القيوم لا تأخذه سنة ولا نوم',
      );

      expect(matches, isNotEmpty);
      expect(matches.first.surahNumber, 2);
      expect(matches.first.verseNumber, 255);
      expect(matches.first.isConfident, isTrue);
    });

    test('works from modern spelling, not just the Uthmani text', () {
      // What a recognizer actually returns: no diacritics, alef written out.
      final matches = VerseFinder.search('قل هو الله احد الله الصمد');

      expect(matches.first.surahNumber, 112);
      expect(matches.first.verseNumber, anyOf(1, 2));
    });

    test('finds a verse from the middle of a long surah', () {
      final matches = VerseFinder.search(
        'وجعلنا من الماء كل شيء حي أفلا يؤمنون',
      );

      expect(matches.first.surahNumber, 21);
      expect(matches.first.verseNumber, 30);
    });

    test('says nothing when it heard nothing', () {
      expect(VerseFinder.search(''), isEmpty);
      expect(VerseFinder.search('الله'), isEmpty);
    });

    test('does not invent a verse for ordinary speech', () {
      final matches = VerseFinder.search(
        'صباح الخير كيف حالك اليوم الطقس جميل جدا',
      );

      // It may return something, but never confidently.
      for (final match in matches) {
        expect(match.isConfident, isFalse, reason: match.text);
      }
    });

    test('ranks the best answer first', () {
      // A phrase that lives inside one verse. The search is per verse, so a
      // recitation spanning several of them has no single best home — and
      // now that the basmala is no longer glued onto every first verse, the
      // words of one surah's opening no longer bleed across the whole Mushaf.
      final matches = VerseFinder.search('اهدنا الصراط المستقيم');

      expect(matches, isNotEmpty);
      for (var i = 1; i < matches.length; i++) {
        expect(matches[i - 1].score, greaterThanOrEqualTo(matches[i].score));
      }
      expect(matches.first.surahNumber, 1);
      expect(matches.first.verseNumber, 6);
    });
  });
}
