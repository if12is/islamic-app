import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';

void main() {
  group('Where a juz begins', () {
    test('the first is al-Fatiha', () {
      final start = QuranLocalService.juzStart(1);
      expect(start.surahNumber, 1);
      expect(start.numberInSurah, 1);
    });

    test('juz 30 is an-Naba, which everyone knows', () {
      // The one anybody can check without a Mushaf in front of them: juz Amma
      // opens at 78:1.
      final start = QuranLocalService.juzStart(30);
      expect(start.surahNumber, 78);
      expect(start.numberInSurah, 1);
    });

    test('juz 2 is al-Baqara 142, the change of qibla', () {
      final start = QuranLocalService.juzStart(2);
      expect(start.surahNumber, 2);
      expect(start.numberInSurah, 142);
    });

    test('a juz is two ahzab, so it starts where its first hizb does', () {
      for (var juz = 1; juz <= QuranLocalService.juzCount; juz++) {
        final byJuz = QuranLocalService.juzStart(juz);
        final byHizb = QuranLocalService.hizbStart((juz - 1) * 2 + 1);
        expect(byJuz.surahNumber, byHizb.surahNumber, reason: 'juz $juz');
        expect(byJuz.numberInSurah, byHizb.numberInSurah, reason: 'juz $juz');
      }
    });

    test('every juz starts after the one before it', () {
      var previous = -1;
      for (var juz = 1; juz <= QuranLocalService.juzCount; juz++) {
        final start = QuranLocalService.juzStart(juz);
        final absolute = start.surahNumber * 1000 + start.numberInSurah;
        expect(absolute, greaterThan(previous), reason: 'juz $juz');
        previous = absolute;
      }
    });

    test('a number outside 1..30 is brought back into range', () {
      expect(QuranLocalService.juzStart(0).surahNumber, 1);
      expect(QuranLocalService.juzStart(99).surahNumber, 78);
    });
  });
}
