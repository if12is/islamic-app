import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';

void main() {
  // The bug: the bundled text glues the basmala onto verse 1 of every surah
  // but al-Fatihah and at-Tawbah, and the reader also draws it as a centred
  // line — so it appeared twice, once in the header and again inside verse 1.
  group('The basmala appears once', () {
    test('is gone from the first verse of a surah that has a header', () {
      final baqarah = QuranLocalService.verse(2, 1);
      expect(baqarah.text.startsWith(QuranLocalService.basmala), isFalse);
      // Al-Baqarah opens on the disconnected letters and nothing else.
      expect(baqarah.text.trim().split(' ').length, 1);

      final ikhlas = QuranLocalService.verse(112, 1);
      expect(ikhlas.text.startsWith(QuranLocalService.basmala), isFalse);
      expect(ikhlas.text, contains('أَحَدٌ'));
    });

    test('across every surah that carries a header', () {
      for (var surah = 2; surah <= QuranLocalService.surahCount; surah++) {
        if (surah == 9) {
          continue;
        }
        expect(
          QuranLocalService.verse(surah, 1).text,
          isNot(startsWith(QuranLocalService.basmala)),
          reason: 'surah $surah verse 1 still carries it',
        );
        expect(QuranLocalService.verse(surah, 1).text.trim(), isNotEmpty);
      }
    });
  });

  group('Where it belongs, it stays', () {
    test('al-Fatihah 1 is the basmala and keeps it', () {
      expect(QuranLocalService.verse(1, 1).text, QuranLocalService.basmala);
    });

    test('at-Tawbah opens as it always did', () {
      expect(QuranLocalService.verse(9, 1).text, startsWith('بَرَاءَةٌ'));
    });

    test('an-Naml 30 quotes it mid-verse and is untouched', () {
      // Stripping anywhere but the front would delete revelation here.
      final verse = QuranLocalService.verse(27, 30);
      expect(verse.text, contains(QuranLocalService.basmala));
      expect(
        verse.text.startsWith(QuranLocalService.basmala),
        isFalse,
        reason: 'it is quoted inside the verse, not at its head',
      );
      expect(verse.text, contains('سُلَيْمَانَ'));
    });

    test('a later verse that happens to open with it is left alone', () {
      expect(
        QuranLocalService.stripLeadingBasmala(
          '${QuranLocalService.basmala} شيء',
          surahNumber: 2,
          verseNumber: 7,
        ),
        '${QuranLocalService.basmala} شيء',
        reason: 'only verse 1 is ever trimmed',
      );
    });
  });

  group('Everything reads the same text', () {
    test('search no longer matches 112 surahs on the basmala alone', () {
      // Before, the basmala sat at the head of 112 first verses, so searching
      // it returned a wall of them. It belongs to two places in the Mushaf.
      final results = QuranLocalService.search('بسم الله الرحمن الرحيم');
      expect(results.length, lessThan(5));
      expect(
        results.any((v) => v.surahNumber == 1 && v.numberInSurah == 1),
        isTrue,
      );
    });

    test('the verse count is unchanged', () {
      expect(QuranLocalService.versesOfSurah(2).length, 286);
      expect(QuranLocalService.versesOfSurah(1).length, 7);
    });
  });
}
