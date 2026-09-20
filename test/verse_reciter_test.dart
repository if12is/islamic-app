import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/data/services/verse_reciters.dart';

void main() {
  group('Telling the two catalogues apart', () {
    test('a whole-surah id has no per-ayah files, and says so', () {
      // A whole-surah recording is one file with no seam at the ayah. It can
      // still be played a verse at a time, but only through the provider's
      // marks — never by asking this host for a file that does not exist.
      expect(VerseReciters.has('mp3quran:92:92'), isFalse);
      expect(VerseReciters.find('mp3quran:92:92'), isNull);
    });

    test('a voice that is recorded per ayah is accepted', () {
      expect(VerseReciters.has('alafasy'), isTrue);
      expect(VerseReciters.has('sudais'), isTrue);
      expect(VerseReciters.find('husary')?.id, 'husary');
    });

    test('something that is neither is refused rather than substituted', () {
      // There used to be a `resolve` here that answered an unknown id with
      // al-Afasy. That is how a reader came to pick one sheikh and hear
      // another, and on a Warsh page it meant hearing a different reading.
      expect(VerseReciters.has('nonsense'), isFalse);
      expect(VerseReciters.find('nonsense'), isNull);
    });
  });

  group('A choice saved by an older build still works', () {
    test('the seven old ids each land on the same voice', () {
      // These were saved in preferences and in people's backups, so they have
      // to keep resolving after the source moved.
      expect(VerseReciters.find('ar.alafasy')?.id, 'alafasy');
      expect(VerseReciters.find('ar.husary')?.id, 'husary');
      expect(VerseReciters.find('ar.minshawi')?.id, 'minshawi');
      expect(VerseReciters.find('ar.mahermuaiqly')?.id, 'maher');
      expect(VerseReciters.find('ar.shaatree')?.id, 'shaatree');
      expect(VerseReciters.find('ar.ahmedajamy')?.id, 'ajamy');
      expect(VerseReciters.find('ar.abdurrahmaansudais')?.id, 'sudais');
    });

    test('every legacy id points at a voice that exists', () {
      for (final id in VerseReciters.legacyIds.keys) {
        expect(VerseReciters.has(id), isTrue, reason: id);
      }
    });

    test('Sudais now has verse audio, which he did not before', () {
      // The reason the source moved: the old CDN answered 403 for him, so the
      // verse player and the memorisation loop were silently broken on a voice
      // the app was offering.
      expect(VerseReciters.has('ar.abdurrahmaansudais'), isTrue);
      expect(
        QuranLocalService.audioUrlForVerse(
          1,
          1,
          reciterCode: 'ar.abdurrahmaansudais',
          small: false,
        ),
        'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/001001.mp3',
      );
    });
  });

  group('The address of one ayah', () {
    test('is the surah and the ayah, each padded to three digits', () {
      expect(
        QuranLocalService.audioUrlForVerse(1, 1, small: false),
        'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
      );
      expect(
        QuranLocalService.audioUrlForVerse(2, 255, small: false),
        'https://everyayah.com/data/Alafasy_128kbps/002255.mp3',
      );
      expect(
        QuranLocalService.audioUrlForVerse(114, 6, small: false),
        'https://everyayah.com/data/Alafasy_128kbps/114006.mp3',
      );
    });

    test('a surah outside the Mushaf is refused, not requested', () {
      expect(
        () => QuranLocalService.audioUrlForVerse(0, 1),
        throwsArgumentError,
      );
      expect(
        () => QuranLocalService.audioUrlForVerse(115, 1),
        throwsArgumentError,
      );
    });
  });

  group('The catalogue itself', () {
    test('every id is unique', () {
      final ids = VerseReciters.all.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test(
      'every folder is unique, so no two entries are the same recording',
      () {
        final folders = VerseReciters.all.map((r) => r.folder).toList();
        expect(folders.toSet().length, folders.length);
      },
    );

    test('every entry has an Arabic name and a folder', () {
      for (final reciter in VerseReciters.all) {
        expect(reciter.nameAr.trim(), isNotEmpty, reason: reciter.id);
        expect(reciter.folder.trim(), isNotEmpty, reason: reciter.id);
        expect(reciter.urlFor(1, 1), startsWith('https://'));
      }
    });

    test('a small recording is only offered where one exists', () {
      for (final reciter in VerseReciters.all) {
        final small = reciter.urlFor(1, 1, small: true);
        if (!reciter.hasLowQuality) {
          expect(small, reciter.urlFor(1, 1), reason: reciter.id);
        } else {
          expect(small, isNot(reciter.urlFor(1, 1)), reason: reciter.id);
        }
      }
    });

    test('a different reading is labelled as one', () {
      // Someone who wants Hafs must not land on Warsh by accident.
      final warsh = VerseReciters.all.where(
        (r) => r.folder.startsWith('warsh/'),
      );
      expect(warsh, isNotEmpty);
      for (final reciter in warsh) {
        expect(reciter.styleAr, contains('ورش'), reason: reciter.id);
      }
    });

    test('the list is far longer than the seven it replaced', () {
      expect(VerseReciters.all.length, greaterThan(30));
    });
  });

  group('Searching the voices', () {
    test('typing without diacritics or hamza still finds the name', () {
      expect(VerseReciters.search('العفاسي'), isNotEmpty);
      expect(VerseReciters.search('احمد'), isNotEmpty);
      expect(VerseReciters.search('الحصري'), isNotEmpty);
    });

    test('a style can be searched as well as a name', () {
      expect(VerseReciters.search('مجود'), isNotEmpty);
      expect(VerseReciters.search('ورش'), isNotEmpty);
    });

    test('an empty query is not a filter', () {
      expect(VerseReciters.search('  ').length, VerseReciters.all.length);
    });

    test('no match returns nothing rather than everything', () {
      expect(VerseReciters.search('zzzz'), isEmpty);
    });
  });
}
