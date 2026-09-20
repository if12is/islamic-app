import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:islamic_app/features/quran/data/services/mushaf_reader.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/data/services/reciter_catalogue.dart';
import 'package:islamic_app/features/quran/data/services/verse_reciters.dart';
import 'package:islamic_app/features/quran/data/services/warsh_mushaf_service.dart';
import 'package:islamic_app/features/quran/domain/entities/riwaya.dart';
import 'package:islamic_app/features/quran/domain/verse_alignment.dart';

/// Al-Fatiha as Quranpedia returns it for the Warsh mushaf.
///
/// Trimmed to the fields the app keeps, but the numbers are the provider's
/// own. They are worth reading: Warsh's first verse answers to Hafs 1 **and**
/// 2, because the basmalah is not counted apart; and Warsh 6 and 7 both answer
/// to Hafs 7, because the Madani count splits that verse in two. Seven verses
/// in each reading, not one of them in the same place.
const String _warshFatiha = '''
[
 {"number":1,"page_number":1,"text":"الحمد لله رب العالمين","marker":"ﰀ","number_in_hafs":[1,2]},
 {"number":2,"page_number":1,"text":"الرحمن الرحيم","marker":"ﰁ","number_in_hafs":[3]},
 {"number":3,"page_number":1,"text":"مالك يوم الدين","marker":"ﰂ","number_in_hafs":[4]},
 {"number":4,"page_number":1,"text":"إياك نعبد وإياك نستعين","marker":"ﰃ","number_in_hafs":[5]},
 {"number":5,"page_number":1,"text":"اهدنا الصراط المستقيم","marker":"ﰄ","number_in_hafs":[6]},
 {"number":6,"page_number":1,"text":"صراط الذين أنعمت عليهم","marker":"ﰅ","number_in_hafs":[7]},
 {"number":7,"page_number":1,"text":"غير المغضوب عليهم ولا الضالين","marker":"ﰆ","number_in_hafs":[7]}
]
''';

List<MushafVerse> get _fatiha =>
    WarshMushafService.parseResponse(jsonDecode(_warshFatiha));

void main() {
  group('Which reading a recording is of', () {
    test('the provider says so, and it is no longer thrown away', () {
      // mp3quran has always sent rewaya_id on every moshaf. The parser dropped
      // it, which is why nothing downstream could separate Warsh from Hafs.
      final voices = ReciterCatalogue.parse({
        'reciters': [
          {
            'id': 118,
            'name': 'محمود خليل الحصري',
            'moshaf': [
              {
                'id': 120,
                'name': 'ورش عن نافع - مرتل',
                'rewaya_id': 2,
                'server': 'https://server13.mp3quran.net/husr/Warsh/',
                'surah_list': '1,2,3',
              },
              {
                'id': 121,
                'name': 'حفص عن عاصم - مرتل',
                'rewaya_id': 1,
                'server': 'https://server13.mp3quran.net/husr/',
                'surah_list': '1,2,3',
              },
            ],
          },
        ],
      });

      expect(voices, hasLength(2));
      final warsh = voices.firstWhere((voice) => voice.isWarsh);
      expect(warsh.riwayaId, Riwaya.warshId);
      expect(voices.any((voice) => voice.riwayaId == Riwaya.hafsId), isTrue);
    });

    test('a recording with no reading stated is read as Hafs', () {
      final voices = ReciterCatalogue.parse({
        'reciters': [
          {
            'id': 1,
            'name': 'قارئ',
            'moshaf': [
              {
                'id': 1,
                'name': 'مرتل',
                'server': 'https://example.com/a/',
                'surah_list': '1',
              },
            ],
          },
        ],
      });

      expect(voices.single.riwayaId, Riwaya.hafsId);
    });

    test('the riwayat list is read from the provider', () {
      final riwayat = ReciterCatalogue.parseRiwayat({
        'riwayat': [
          {'id': 1, 'name': 'حفص عن عاصم'},
          {'id': 2, 'name': 'ورش عن نافع'},
          {'id': 5, 'name': 'قالون عن نافع'},
        ],
      });

      expect(riwayat, hasLength(3));
      expect(Riwaya.nameFor(2, riwayat), 'ورش عن نافع');
    });

    test('both routes of Warsh count as Warsh', () {
      // Asbahani is a different tariq of the same reading. Someone reading
      // Warsh is not being handed the wrong text by either.
      expect(Riwaya.isWarsh(Riwaya.warshId), isTrue);
      expect(Riwaya.isWarsh(Riwaya.warshAsbahaniId), isTrue);
      expect(Riwaya.isWarsh(Riwaya.hafsId), isFalse);
      expect(MushafEdition.warsh.accepts(Riwaya.warshAsbahaniId), isTrue);
      expect(MushafEdition.warsh.accepts(Riwaya.hafsId), isFalse);
      expect(MushafEdition.hafs.accepts(Riwaya.warshId), isFalse);
    });
  });

  group('How a recording numbers its files', () {
    test('the Warsh voices do not agree with each other', () {
      // Measured against the host, one file at a time: al-Baqarah ends at 286
      // under Hafs and 285 under Warsh, al-Tawbah at 129 and 130. Two of these
      // three answer to the Hafs numbers. Nothing in a folder name says so,
      // and a URL built from the wrong scheme returns the neighbouring ayah
      // rather than an error.
      final dosary = VerseReciters.find('warsh-dosary')!;
      final jazaery = VerseReciters.find('warsh-jazaery')!;
      final abdulbasit = VerseReciters.find('warsh-abdulbasit')!;

      expect(dosary.counting, VerseCounting.hafs);
      expect(jazaery.counting, VerseCounting.hafs);
      expect(abdulbasit.counting, VerseCounting.warsh);

      for (final voice in [dosary, jazaery, abdulbasit]) {
        expect(voice.isWarsh, isTrue, reason: voice.id);
      }
    });

    test('everything else is Hafs, and says so', () {
      final alafasy = VerseReciters.find('alafasy')!;
      expect(alafasy.riwayaId, Riwaya.hafsId);
      expect(alafasy.counting, VerseCounting.hafs);
    });
  });

  group('Offering only what can play', () {
    test(
      'an id with no per-ayah audio is answered with null, not a stand-in',
      () {
        // The bug this replaces: the picker resolved a whole-surah catalogue id
        // to al-Afasy and played him. The reader chose one voice and heard
        // another, with nothing on screen admitting the swap.
        expect(VerseReciters.find('mp3quran:92:92'), isNull);
        expect(VerseReciters.find('nonsense'), isNull);
        expect(VerseReciters.find('alafasy'), isNotNull);
      },
    );

    test('a legacy id still resolves to the voice it named', () {
      expect(VerseReciters.find('ar.husary')?.id, 'husary');
    });

    test('a Warsh reader is offered Warsh and nothing else', () {
      final warsh = VerseReciters.forEdition(MushafEdition.warsh);

      expect(warsh, isNotEmpty);
      for (final voice in warsh) {
        expect(voice.isWarsh, isTrue, reason: voice.id);
      }
      expect(warsh.any((voice) => voice.id == 'alafasy'), isFalse);
    });

    test('the default voice follows the reading', () {
      expect(
        VerseReciters.find(
          VerseReciters.defaultFor(MushafEdition.warsh),
        )!.isWarsh,
        isTrue,
      );
      expect(VerseReciters.defaultFor(MushafEdition.hafs), 'alafasy');
    });
  });

  group('Reading the Warsh mushaf', () {
    test('the provider payload is kept down to what makes a page', () {
      final verses = _fatiha;

      expect(verses, hasLength(7));
      expect(verses.first.number, 1);
      expect(verses.first.page, 1);
      expect(verses.first.marker, isNotEmpty);
      expect(verses.first.text, contains('الحمد'));
    });

    test('a payload that is not a list is empty, not a crash', () {
      expect(WarshMushafService.parseResponse({'error': 'nope'}), isEmpty);
      expect(WarshMushafService.parseResponse(null), isEmpty);
    });

    test('a verse with no text is dropped rather than shown blank', () {
      final verses = WarshMushafService.parseResponse([
        {
          'number': 1,
          'text': '',
          'number_in_hafs': [1],
        },
        {
          'number': 2,
          'text': 'كلام',
          'number_in_hafs': [2],
        },
      ]);

      expect(verses, hasLength(1));
      expect(verses.single.number, 2);
    });

    test('what is cached reads back as what was fetched', () {
      final original = _fatiha;
      final restored = WarshMushafService.parseCache(
        jsonEncode([for (final verse in original) verse.toJson()]),
      );

      expect(restored, hasLength(original.length));
      expect(restored.first.hafsNumbers, original.first.hafsNumbers);
      expect(restored.last.text, original.last.text);
    });
  });

  group('Lining the two readings up', () {
    test('Warsh opens al-Fatiha on two Hafs verses at once', () {
      final verses = _fatiha;
      expect(verses.first.hafsNumbers, [1, 2]);
      expect(verses.first.primaryHafsNumber, 1);
    });

    test('two Warsh verses share the last Hafs one', () {
      final verses = _fatiha;
      expect(verses[5].hafsNumbers, [7]);
      expect(verses[6].hafsNumbers, [7]);
    });

    test('a Warsh page asking a Hafs-numbered recording is translated', () {
      // The whole point. Reading Warsh 2, a recording filed under Hafs numbers
      // must be asked for Hafs 3 — not for 2, which is a different ayah.
      final verses = _fatiha;

      expect(
        VerseAlignment.audioVerseNumber(
          edition: MushafEdition.warsh,
          recordingCounting: VerseCounting.hafs,
          verseNumber: 2,
          surahVerses: verses,
        ),
        3,
      );
    });

    test('a recording that already counts in Warsh is left alone', () {
      final verses = _fatiha;

      expect(
        VerseAlignment.audioVerseNumber(
          edition: MushafEdition.warsh,
          recordingCounting: VerseCounting.warsh,
          verseNumber: 2,
          surahVerses: verses,
        ),
        2,
      );
    });

    test('a Hafs reader never goes through the mapping', () {
      expect(
        VerseAlignment.audioVerseNumber(
          edition: MushafEdition.hafs,
          recordingCounting: VerseCounting.hafs,
          verseNumber: 5,
          surahVerses: const [],
        ),
        5,
      );
    });

    test('a saved place crosses between the readings', () {
      final verses = _fatiha;

      // Warsh 1 is stored as Hafs 1, and Hafs 3 comes back as Warsh 2.
      expect(VerseAlignment.toHafs(1, verses), 1);
      expect(VerseAlignment.toHafs(2, verses), 3);
      expect(VerseAlignment.fromHafs(3, verses), 2);
      // Hafs 7 is covered by two Warsh verses; the first is where it starts.
      expect(VerseAlignment.fromHafs(7, verses), 6);
    });

    test('a number past the end of the mapping lands on the last verse', () {
      // Hafs numbers al-Baqarah to 286 and Warsh stops at 285. That last verse
      // is still inside the surah, not outside the book.
      final verses = _fatiha;
      expect(VerseAlignment.fromHafs(99, verses), 7);
    });

    test('an empty mapping passes the number through rather than guessing', () {
      expect(
        VerseAlignment.audioVerseNumber(
          edition: MushafEdition.warsh,
          recordingCounting: VerseCounting.hafs,
          verseNumber: 4,
          surahVerses: const [],
        ),
        4,
      );
    });
  });

  group('Handing the Warsh mushaf to the rest of the app', () {
    test('it arrives in the shape every other screen already reads', () {
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);

      expect(verses, hasLength(7));
      expect(verses.first.surahNumber, 1);
      expect(verses.first.numberInSurah, 1);
      expect(verses.first.text, contains('الحمد'));
      expect(verses.first.surahNameAr, isNotEmpty);
    });

    test('the divisions come from the Hafs verse it stands on', () {
      // So a reader who switches reading stays on the same juz and the same
      // hizb instead of drifting by a verse for the length of the surah.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);

      for (final verse in verses) {
        expect(verse.juz, 1);
        expect(verse.hizbQuarter, greaterThan(0));
      }
    });

    test('the page is the Warsh leaf, not the Hafs one', () {
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);

      expect(verses.first.page, 1);
    });

    test('a mapping that points past the Hafs surah is still placed', () {
      // Warsh numbers al-Tawbah to 130 where Hafs stops at 129, and the
      // provider maps that last verse back to 129 — so this case is the belt,
      // not the live path. It is kept because the Hafs index throws on a verse
      // out of range, and a mushaf that ever disagreed with the provider by
      // one would take the reader's page down rather than being off by a line.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 9, [
        const MushafVerse(
          number: 130,
          page: 208,
          text: 'آية',
          marker: 'ﰀ',
          hafsNumbers: [130],
        ),
      ]);

      expect(verses, hasLength(1));
      expect(verses.single.numberInSurah, 130);
      expect(verses.single.juz, greaterThan(0));
    });
  });

  group('Asking a recording for the right file', () {
    test('a Warsh page gives a Hafs-numbered recording the Hafs number', () {
      // The bug this prevents, stated plainly: al-Dosary's Warsh recording is
      // filed under Hafs numbers. Reading Warsh 2:2 and asking him for file
      // 002002 plays the ayah before the one on the page, and every ayah after
      // it is wrong too. Nothing 404s. Nothing is logged.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final dosary = VerseReciters.find('warsh-dosary')!;

      final second = verses[1];
      expect(second.numberInSurah, 2);
      expect(second.hafsVerseNumber, 3);

      final file =
          dosary.counting == VerseCounting.hafs
              ? second.hafsVerseNumber
              : second.numberInSurah;
      expect(file, 3);
      expect(dosary.urlFor(1, file), endsWith('001003.mp3'));
    });

    test('a Warsh-numbered recording is asked for the Warsh number', () {
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final abdulbasit = VerseReciters.find('warsh-abdulbasit')!;

      final second = verses[1];
      final file =
          abdulbasit.counting == VerseCounting.hafs
              ? second.hafsVerseNumber
              : second.numberInSurah;
      expect(file, 2);
      expect(abdulbasit.urlFor(1, file), endsWith('001002.mp3'));
    });

    test('a Hafs page is unchanged, because there is nothing to convert', () {
      final verses = QuranLocalService.versesOfSurah(1);
      expect(verses[1].hafsNumberInSurah, isNull);
      expect(verses[1].hafsVerseNumber, verses[1].numberInSurah);
    });
  });

  group('Standing in for a download that is not there', () {
    bool acceptsFor(MushafEdition edition, int riwayaId) =>
        edition.accepts(riwayaId);

    test('a Warsh reader is not handed a downloaded Hafs recitation', () {
      // Substituting a downloaded voice for a missing one is a kindness when
      // both recite the same text. Across readings it recites words that are
      // not on the page, and says nothing about having done so.
      expect(acceptsFor(MushafEdition.warsh, Riwaya.hafsId), isFalse);
      expect(acceptsFor(MushafEdition.warsh, Riwaya.warshId), isTrue);
    });

    test('and a Hafs reader is not handed a Warsh one either', () {
      expect(acceptsFor(MushafEdition.hafs, Riwaya.warshId), isFalse);
      expect(acceptsFor(MushafEdition.hafs, Riwaya.hafsId), isTrue);
    });
  });

  group('Reaching the mushaf at all', () {
    test('the host the Warsh text comes from is trusted', () {
      // The client rejects any host not on this list, and does it by throwing
      // inside an interceptor — so dropping the entry would not look like a
      // networking change. It would look like Warsh quietly never loading.
      expect(SecureHttpClient.allowedHosts, contains('api.quranpedia.net'));
    });

    test('and so is the host the per-ayah recitations come from', () {
      expect(SecureHttpClient.allowedHosts, contains('everyayah.com'));
    });
  });

  group('Which readings can actually be shown', () {
    test('only the ones with a text behind them', () {
      // Audio exists for a dozen riwayat. A text the reader can follow exists
      // for two, and offering a third would repeat the failure this change is
      // about: a choice that looks live and quietly does something else.
      expect(MushafEdition.values, hasLength(2));
      expect(WarshMushafService.supports(MushafEdition.warsh), isTrue);
      expect(WarshMushafService.supports(MushafEdition.hafs), isFalse);
    });

    test('the stored id survives a reordering of the enum', () {
      expect(MushafEdition.fromId('warsh'), MushafEdition.warsh);
      expect(MushafEdition.fromId('hafs'), MushafEdition.hafs);
      expect(MushafEdition.fromId(null), MushafEdition.hafs);
      expect(MushafEdition.fromId('qalun'), MushafEdition.hafs);
    });

    test('each reading knows how it counts', () {
      expect(MushafEdition.hafs.counting, VerseCounting.hafs);
      expect(MushafEdition.warsh.counting, VerseCounting.warsh);
    });
  });
}
