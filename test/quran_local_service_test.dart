import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';

void main() {
  group('QuranLocalService index', () {
    test('lists all 114 surahs with names and counts', () {
      final surahs = QuranLocalService.surahs();

      expect(surahs, hasLength(114));
      expect(surahs.first.nameAr, 'الفاتحة');
      expect(surahs.first.versesCount, 7);
      expect(surahs.first.isMeccan, isTrue);
      expect(surahs.last.id, 114);
      expect(surahs[1].versesCount, 286);
    });

    test('reads a verse with its juz, page, and surah name', () {
      final ayatAlKursi = QuranLocalService.verse(2, 255);

      expect(ayatAlKursi.key, '2:255');
      // Compare on the normalized form: the Mushaf text carries diacritics
      // that are invisible in a source literal but not identical to it.
      expect(
        QuranLocalService.normalizeArabic(ayatAlKursi.text),
        startsWith('الله لا اله الا هو الحي القيوم'),
      );
      expect(ayatAlKursi.juz, 3);
      expect(ayatAlKursi.page, 42);
      expect(ayatAlKursi.surahNameAr, 'البقرة');
    });

    test('rejects out-of-range references', () {
      expect(() => QuranLocalService.verse(2, 300), throwsArgumentError);
      expect(() => QuranLocalService.verse(115, 1), throwsArgumentError);
      expect(() => QuranLocalService.versesOfJuz(31), throwsArgumentError);
    });

    test('returns a full surah in order', () {
      final fatiha = QuranLocalService.versesOfSurah(1);

      expect(fatiha, hasLength(7));
      expect(fatiha.first.numberInSurah, 1);
      expect(fatiha.last.numberInSurah, 7);
      expect(
        QuranLocalService.normalizeArabic(fatiha.first.text),
        contains('بسم الله'),
      );
    });

    test('returns a juz across surah boundaries', () {
      final juz30 = QuranLocalService.versesOfJuz(30);

      expect(juz30.first.surahNumber, 78);
      expect(juz30.first.numberInSurah, 1);
      expect(juz30.last.surahNumber, 114);
      expect(juz30.last.numberInSurah, 6);
      expect(juz30.map((verse) => verse.surahNumber).toSet(), hasLength(37));
    });

    test('returns the verses printed on a Mushaf page', () {
      final page = QuranLocalService.versesOfPage(604);

      expect(page.map((verse) => verse.surahNumber).toSet(), {112, 113, 114});
      expect(page, hasLength(15)); // 4 + 5 + 6 verses
    });

    test('maps between surah:verse and the running verse number', () {
      expect(QuranLocalService.globalVerseNumber(1, 1), 1);
      expect(QuranLocalService.globalVerseNumber(2, 1), 8);
      expect(QuranLocalService.globalVerseNumber(114, 6), 6236);

      final last = QuranLocalService.verseByGlobalNumber(6236);
      expect(last.surahNumber, 114);
      expect(last.numberInSurah, 6);
    });

    test('marks every sajdah verse, including both in Al-Hajj', () {
      expect(QuranLocalService.verse(32, 15).isSajdah, isTrue);
      expect(QuranLocalService.verse(32, 14).isSajdah, isFalse);
      expect(QuranLocalService.verse(22, 18).isSajdah, isTrue);
      expect(QuranLocalService.verse(22, 77).isSajdah, isTrue);

      final sajdahs = QuranLocalService.sajdahList();
      expect(sajdahs, hasLength(15));
      expect(sajdahs.first.key, '7:206');
      expect(sajdahs.last.key, '96:19');
    });

    test('resolves hizb quarters across the Mushaf', () {
      expect(QuranLocalService.hizbQuarterOf(1, 1), 1);
      expect(QuranLocalService.hizbQuarterOf(2, 25), 1);
      expect(QuranLocalService.hizbQuarterOf(2, 26), 2);
      expect(QuranLocalService.hizbQuarterOf(114, 6), 240);

      final ayatAlKursi = QuranLocalService.verse(2, 255);
      expect(ayatAlKursi.hizb, inInclusiveRange(1, 60));
      expect(ayatAlKursi.quarterInHizb, inInclusiveRange(0, 3));
    });

    test('quarter and hizb starts line up with their verses', () {
      for (var quarter = 1; quarter <= 240; quarter++) {
        final start = QuranLocalService.hizbQuarterStart(quarter);
        expect(start.hizbQuarter, quarter);
        expect(start.startsHizbQuarter, isTrue);
      }

      expect(QuranLocalService.hizbStart(1).key, '1:1');
      expect(QuranLocalService.hizbStart(2).hizbQuarter, 5);
    });

    test('reads a whole hizb and a whole quarter', () {
      final quarter = QuranLocalService.versesOfHizbQuarter(2);
      expect(quarter.first.key, '2:26');
      expect(quarter.every((verse) => verse.hizbQuarter == 2), isTrue);

      final hizb = QuranLocalService.versesOfHizb(1);
      expect(hizb.first.key, '1:1');
      expect(hizb.map((verse) => verse.hizbQuarter).toSet(), {1, 2, 3, 4});
    });

    test('page starts and their surah names', () {
      expect(QuranLocalService.pageStart(1).key, '1:1');
      expect(QuranLocalService.pageStart(604).surahNumber, 112);
      expect(QuranLocalService.surahNamesOnPage(604), hasLength(3));
    });
  });

  group('QuranLocalService search', () {
    test('normalizes diacritics, hamza forms, and taa marbuta', () {
      expect(
        QuranLocalService.normalizeArabic('الرَّحْمَٰنِ'),
        QuranLocalService.normalizeArabic('الرحمن'),
      );
      expect(QuranLocalService.normalizeArabic('إِسْحَاقَ'), 'اسحاق');
      expect(QuranLocalService.normalizeArabic('رَحْمَةً'), 'رحمه');
    });

    test('finds verses typed without diacritics', () {
      final results = QuranLocalService.search('الحمد لله رب العالمين');

      expect(results, isNotEmpty);
      expect(results.first.surahNumber, 1);
      expect(results.first.numberInSurah, 2);
    });

    test('honours the result limit and ignores very short queries', () {
      expect(QuranLocalService.search('الله', limit: 5), hasLength(5));
      expect(QuranLocalService.search('ا'), isEmpty);
    });

    test(
      'searches the surah index by Arabic name, English name, or number',
      () {
        expect(QuranLocalService.searchSurahs('كهف').single.id, 18);
        expect(QuranLocalService.searchSurahs('Kahf').single.id, 18);
        expect(QuranLocalService.searchSurahs('36').single.id, 36);
        expect(QuranLocalService.searchSurahs(''), hasLength(114));
      },
    );
  });

  group('QuranLocalService daily verse and audio', () {
    test('gives the same verse for the whole day and moves on the next', () {
      final morning = QuranLocalService.verseOfTheDay(DateTime(2026, 8, 19, 6));
      final evening = QuranLocalService.verseOfTheDay(
        DateTime(2026, 8, 19, 23),
      );
      final tomorrow = QuranLocalService.verseOfTheDay(DateTime(2026, 8, 20));

      expect(morning.key, evening.key);
      expect(morning.key, isNot(tomorrow.key));
    });

    test('addresses one ayah by its surah and its number in it', () {
      // The per-ayah host names files by surah and ayah, each padded to three
      // digits, rather than by the running 1–6236 number the old CDN used.
      expect(
        QuranLocalService.audioUrlForVerse(1, 1, small: false),
        'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
      );
      expect(
        QuranLocalService.audioUrlForVerse(
          2,
          255,
          reciterCode: 'ar.husary',
          small: false,
        ),
        'https://everyayah.com/data/Husary_128kbps/002255.mp3',
      );
      // Whole surahs come from mp3quran, not the CDN: the CDN serves them for
      // ar.alafasy alone and returns 403 for every other reciter.
      expect(QuranLocalService.audioUrlForSurah(18), endsWith('/018.mp3'));
      expect(QuranLocalService.audioUrlForSurah(18), contains('mp3quran.net'));
    });
  });
}
