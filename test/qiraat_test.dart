import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:islamic_app/features/quran/data/services/ayah_timing_service.dart';
import 'package:islamic_app/features/quran/data/services/mushaf_reader.dart';
import 'package:islamic_app/features/quran/data/services/mushaf_service.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/data/services/reciter_catalogue.dart';
import 'package:islamic_app/features/quran/data/services/verse_reciters.dart';
import 'package:islamic_app/features/quran/data/services/verse_voices.dart';
import 'package:islamic_app/features/quran/domain/entities/riwaya.dart';

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
    MushafService.parseResponse(jsonDecode(_warshFatiha));

/// The opening of al-Baqarah as Quranpedia returns it for a Madani mushaf.
///
/// Enough of it to test a selection that crosses a surah boundary, which is
/// what a juz, a hizb and a page all do and a single surah never does.
const String _warshBaqaraHead = '''
[
 {"number":1,"page_number":2,"text":"الم","marker":"ﭐ","number_in_hafs":[1]},
 {"number":2,"page_number":2,"text":"ذلك الكتاب لا ريب فيه هدى للمتقين","marker":"ﭑ","number_in_hafs":[2]},
 {"number":3,"page_number":2,"text":"الذين يؤمنون بالغيب","marker":"ﭒ","number_in_hafs":[3]}
]
''';

List<MushafVerse> get _baqaraHead =>
    MushafService.parseResponse(jsonDecode(_warshBaqaraHead));

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
      expect(abdulbasit.counting, VerseCounting.madaniAkhir);

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

    test('the first voice offered for a reading is of that reading', () {
      expect(VerseReciters.forEdition(MushafEdition.warsh).first.isWarsh, true);
      expect(
        VerseReciters.forEdition(MushafEdition.hafs).first.riwayaId,
        Riwaya.hafsId,
      );
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
      expect(MushafService.parseResponse({'error': 'nope'}), isEmpty);
      expect(MushafService.parseResponse(null), isEmpty);
    });

    test('a verse with no text is dropped rather than shown blank', () {
      final verses = MushafService.parseResponse([
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
      final restored = MushafService.parseCache(
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
      // must be asked for Hafs 3 — not for 2, which is a different ayah. The
      // conversion now travels on the verse itself, which is what the audio
      // layer reads when it builds the URL.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final second = verses[1];

      expect(second.numberInSurah, 2);
      expect(second.hafsVerseNumber, 3);
    });

    test('a recording that already counts in Warsh is left alone', () {
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      expect(verses[1].numberInSurah, 2);
    });

    test('a Hafs page has nothing to convert', () {
      final verses = QuranLocalService.versesOfSurah(1);
      expect(verses[4].hafsVerseNumber, verses[4].numberInSurah);
      expect(verses[4].hafsNumbersInSurah, isNull);
    });

    test('a verse can be found by either Hafs number it carries', () {
      // The merge direction. Warsh 1 is Hafs 1 and 2, and a bookmark, a
      // notification or a resume can point at either — so searching by the
      // first alone would lose every reference to the second.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);

      expect(verses.first.coversHafs(1), isTrue);
      expect(verses.first.coversHafs(2), isTrue);
      expect(verses.first.coversHafs(3), isFalse);
      expect(verses.first.hafsVerseNumber, 1);
      expect(verses.where((verse) => verse.coversHafs(7)), hasLength(2));
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

    test('the page is the Hafs leaf, because that is what the app counts', () {
      // The page number is not only a label: it indexes the page-turning
      // view, the reading log behind the streak, and the khatmah plan, all of
      // which are defined over the 604 Hafs leaves. A field that meant the
      // Warsh leaf here and the Hafs one there had each of them counting a
      // different book.
      final verses = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final hafs = QuranLocalService.versesOfSurah(1);

      for (var i = 0; i < verses.length; i++) {
        expect(
          verses[i].page,
          QuranLocalService.verse(1, verses[i].hafsVerseNumber).page,
        );
      }
      expect(verses.first.page, hafs.first.page);
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
      // for three, and offering a fourth would repeat the failure this change
      // is about: a choice that looks live and quietly does something else.
      expect(MushafEdition.values, hasLength(3));
      expect(MushafService.supports(MushafEdition.warsh), isTrue);
      expect(MushafService.supports(MushafEdition.qaloon), isTrue);
      expect(MushafService.supports(MushafEdition.hafs), isFalse);
      expect(MushafService.fetchable, isNot(contains(MushafEdition.hafs)));
    });

    test('the stored id survives a reordering of the enum', () {
      expect(MushafEdition.fromId('warsh'), MushafEdition.warsh);
      expect(MushafEdition.fromId('hafs'), MushafEdition.hafs);
      expect(MushafEdition.fromId('qaloon'), MushafEdition.qaloon);
      expect(MushafEdition.fromId(null), MushafEdition.hafs);
      expect(MushafEdition.fromId('qalun'), MushafEdition.hafs);
    });

    test('each reading knows how it counts', () {
      // Warsh and Qalun both come through Nafi` of Madina, and the provider
      // labels both mushafs `المدني الأخير`: al-Baqarah 285, al-Tawbah 130. One
      // scheme covers the pair, so a recording of either answers to the number
      // printed on either page.
      expect(MushafEdition.hafs.counting, VerseCounting.hafs);
      expect(MushafEdition.warsh.counting, VerseCounting.madaniAkhir);
      expect(MushafEdition.qaloon.counting, VerseCounting.madaniAkhir);
    });

    test('every reading has a short name for a chip', () {
      for (final edition in MushafEdition.values) {
        expect(edition.shortAr, isNotEmpty, reason: edition.id);
        expect(edition.nameAr, contains(edition.shortAr), reason: edition.id);
      }
    });
  });

  group('Qalun', () {
    test('every route of it counts as Qalun, and nothing else does', () {
      expect(Riwaya.isQaloon(Riwaya.qaloonId), isTrue);
      expect(Riwaya.isQaloon(Riwaya.qaloonAbiNashitId), isTrue);
      expect(Riwaya.isQaloon(Riwaya.warshId), isFalse);
      expect(Riwaya.isQaloon(Riwaya.hafsId), isFalse);
    });

    test('a Qalun reader is offered Qalun and nothing else', () {
      // Both come through Nafi`, which makes them neighbours and not the same
      // thing. Handing a Qalun page a Warsh recitation is the same failure as
      // handing it a Hafs one, and harder to notice.
      expect(MushafEdition.qaloon.accepts(Riwaya.qaloonId), isTrue);
      expect(MushafEdition.qaloon.accepts(Riwaya.qaloonAbiNashitId), isTrue);
      expect(MushafEdition.qaloon.accepts(Riwaya.warshId), isFalse);
      expect(MushafEdition.qaloon.accepts(Riwaya.hafsId), isFalse);
      expect(MushafEdition.warsh.accepts(Riwaya.qaloonId), isFalse);
      expect(MushafEdition.hafs.accepts(Riwaya.qaloonId), isFalse);
    });

    test('the per-ayah host carries nothing for it, and does not pretend', () {
      // everyayah has a Hafs corpus and three Warsh folders. No Qalun. The
      // honest answer is an empty list, which is what sends playback to the
      // clipped whole-surah recordings instead of to a Hafs voice.
      expect(VerseReciters.forEdition(MushafEdition.qaloon), isEmpty);
      expect(VerseVoices.files(MushafEdition.qaloon), isEmpty);
    });

    test('al-Azraq is Warsh, which two complete recitations depend on', () {
      expect(Riwaya.isWarsh(Riwaya.warshAzraqId), isTrue);
      expect(MushafEdition.warsh.accepts(Riwaya.warshAzraqId), isTrue);
    });

    test('the bundled riwayat carry the ids the provider actually uses', () {
      final ids = {for (final riwaya in Riwaya.bundled) riwaya.id};
      for (final id in [
        Riwaya.hafsId,
        Riwaya.warshId,
        Riwaya.warshAzraqId,
        Riwaya.warshAsbahaniId,
        Riwaya.qaloonId,
        Riwaya.qaloonAbiNashitId,
      ]) {
        expect(ids, contains(id));
      }
      expect(ids.length, Riwaya.bundled.length, reason: 'no duplicate ids');
    });
  });

  group('A juz, a hizb and a page follow the reading too', () {
    test('a selection inside one surah comes back in the chosen reading', () {
      final hafs = QuranLocalService.versesOfSurah(1);
      final warsh = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);

      expect(hafs.first.text, isNot(warsh.first.text));
      expect(warsh.first.text, contains('الحمد'));
    });

    test('a verse is kept when it carries any part of what was asked for', () {
      // The boundary case a naive `number ==` filter gets wrong. Warsh's
      // al-Fatiha 1 is Hafs 1 and 2 together: a page that asks for Hafs 2 must
      // get that whole verse, not nothing.
      final verses = _fatiha;
      expect(verses.first.coversHafs(1), isTrue);
      expect(verses.first.coversHafs(2), isTrue);
      expect(verses.first.coversHafs(3), isFalse);
      // And a merged verse is offered once, not once per Hafs verse it covers.
      final asked = {1, 2};
      final slice = [
        for (final verse in verses)
          if (asked.any(verse.coversHafs)) verse,
      ];
      expect(slice, hasLength(1));
    });

    test('a verse with no mapping falls back to its own number', () {
      const orphan = MushafVerse(
        number: 4,
        page: 1,
        text: 'آية',
        marker: '',
        hafsNumbers: [],
      );
      expect(orphan.coversHafs(4), isTrue);
      expect(orphan.coversHafs(5), isFalse);
      expect(orphan.primaryHafsNumber, 4);
    });

    test('a selection spanning two surahs keeps them in order', () {
      final verses = [
        ...MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha),
        ...MushafReader.buildVerses(MushafEdition.warsh, 2, _baqaraHead),
      ];

      expect(verses.map((verse) => verse.surahNumber).toSet(), {1, 2});
      expect(verses.first.surahNumber, 1);
      expect(verses.last.surahNumber, 2);
      // Each side keeps its own surah's name rather than the first one's.
      expect(verses.last.surahNameAr, isNot(verses.first.surahNameAr));
    });
  });

  group('One ayah outside the reader', () {
    tearDown(() {
      MushafReader.current = MushafEdition.hafs;
      MushafService.resetForTest();
    });

    test('answers in Hafs while the other mushaf is not loaded', () {
      // A fallback with a remedy, not a substitution: the reader's own page
      // never takes this path, and `warm` closes it for everywhere else.
      MushafService.resetForTest();
      MushafReader.current = MushafEdition.warsh;
      expect(MushafReader.textOf(1, 1), QuranLocalService.verseText(1, 1));
      expect(MushafReader.numberLabelOf(1, 1), '1');
    });

    test('a Hafs reader never looks for another text at all', () {
      MushafReader.current = MushafEdition.hafs;
      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);
      expect(MushafReader.textOf(2, 255), QuranLocalService.verseText(2, 255));
      expect(MushafReader.verseOf(2, 255).numberInSurah, 255);
    });

    test('once the mushaf is in memory the ayah is the chosen reading', () {
      MushafReader.current = MushafEdition.warsh;
      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);

      expect(MushafReader.textOf(1, 3), contains('الرحمن'));
      // Hafs 3 is Warsh 2, so the number shown moves with the text.
      expect(MushafReader.numberLabelOf(1, 3), '2');
      expect(MushafReader.verseOf(1, 3).numberInSurah, 2);
      expect(MushafReader.verseOf(1, 3).hafsVerseNumber, 3);
    });

    test('a Hafs address inside a merged verse finds that whole verse', () {
      MushafReader.current = MushafEdition.warsh;
      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);

      // Warsh 1 covers Hafs 1 and 2. Either address lands on it.
      expect(MushafReader.numberLabelOf(1, 1), '1');
      expect(MushafReader.numberLabelOf(1, 2), '1');
      expect(MushafReader.textOf(1, 2), MushafReader.textOf(1, 1));
    });

    test('a Hafs verse this reading splits in two gives back both', () {
      // Measured against the provider: Warsh and Qalun divide al-Tawbah 70
      // into two verses, which is why at-Tawbah has 130 of them and Hafs has
      // 129. Answering with the first half alone would drop revelation — and
      // do it silently, since a half-verse still reads as a verse.
      MushafReader.current = MushafEdition.warsh;
      MushafService.seedForTest(MushafEdition.warsh, 9, const [
        MushafVerse(
          number: 70,
          page: 1,
          text: 'الشطر الأول',
          marker: '',
          hafsNumbers: [70],
        ),
        MushafVerse(
          number: 71,
          page: 1,
          text: 'الشطر الثاني',
          marker: '',
          hafsNumbers: [70],
        ),
      ]);

      expect(MushafReader.textOf(9, 70), 'الشطر الأول الشطر الثاني');
      expect(MushafReader.numberLabelOf(9, 70), '70-71');
      expect(MushafReader.rangeOf(9, 70, 70), hasLength(2));
      expect(
        MushafReader.rangeOf(9, 70, 70).map((verse) => verse.numberInSurah),
        [70, 71],
      );
    });

    test('a merged verse is not repeated across a stored range', () {
      // A memorisation passage or a video walks a saved Hafs range. Asking for
      // Hafs 1 and Hafs 2 in Warsh returns the same verse twice, and the
      // passage would show the same line back to back.
      MushafReader.current = MushafEdition.warsh;
      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);

      final range = MushafReader.rangeOf(1, 1, 3);
      expect(range.map((verse) => verse.numberInSurah), [1, 2]);
    });

    test('a range in Hafs is untouched', () {
      MushafReader.current = MushafEdition.hafs;
      final range = MushafReader.rangeOf(1, 1, 3);
      expect(range.map((verse) => verse.numberInSurah), [1, 2, 3]);
    });

    test('the sync reader says "not yet" rather than showing a mixture', () {
      MushafService.resetForTest();
      final hafs = QuranLocalService.versesOfSurah(1);

      expect(MushafReader.versesLikeSync(MushafEdition.warsh, hafs), isNull);
      expect(MushafReader.versesLikeSync(MushafEdition.hafs, hafs), same(hafs));

      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);
      final ready = MushafReader.versesLikeSync(MushafEdition.warsh, hafs);
      expect(ready, isNotNull);
      expect(ready!.map((verse) => verse.numberInSurah), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('a selection is dropped whole when one of its surahs is missing', () {
      // Half Warsh and half Hafs on one leaf is worse than a leaf that says
      // it could not fetch the reading.
      MushafService.resetForTest();
      MushafService.seedForTest(MushafEdition.warsh, 1, _fatiha);
      final across = [
        ...QuranLocalService.versesOfSurah(1),
        ...QuranLocalService.versesOfSurah(114),
      ];

      expect(MushafReader.versesLikeSync(MushafEdition.warsh, across), isNull);
    });
  });

  group('Where a saved place is stored', () {
    test('a verse knows both its own number and its Hafs one', () {
      final warsh = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final second = warsh[1];

      expect(second.key, '1:2');
      expect(second.hafsKey, '1:3');
    });

    test('in Hafs the two are the same, so nothing migrates', () {
      final verse = QuranLocalService.verse(2, 255);
      expect(verse.key, verse.hafsKey);
      expect(verse.hafsKey, '2:255');
    });

    test('nothing hands another screen the on-screen number', () {
      // The readers were moved to Hafs addresses before the writers were,
      // which is worse than either end being wrong on its own: a Warsh reader
      // adding al-Baqarah 285 to memorisation got 284 back in review, and a
      // video of the wrong ayah. These three call sites are the writers.
      final source =
          File(
            'lib/features/quran/presentation/widgets/ayah_actions_sheet.dart',
          ).readAsStringSync();

      for (final field in ['fromAyah:', 'toAyah:', 'fromVerse:']) {
        final lines = source
            .split('\n')
            .where((line) => line.trimLeft().startsWith(field));
        expect(lines, isNotEmpty, reason: 'no $field passed anywhere');
        for (final line in lines) {
          expect(line, contains('hafsVerseNumber'), reason: line.trim());
        }
      }
    });

    test('nothing writes the on-screen number into storage', () {
      // A guard rather than a unit test, because the failure is invisible in
      // Hafs — where the two numbers are equal — and only appears for someone
      // who reads Warsh or Qalun, on their own saved verses, later. Each line
      // below stores a place; each must store the Hafs address.
      const mustUseHafs = {
        'lib/features/quran/presentation/providers/bookmarks_provider.dart':
            'verseNumber: verse.',
        'lib/features/quran/presentation/pages/surah_reader_page.dart':
            'verseNumber: verse.',
      };

      for (final entry in mustUseHafs.entries) {
        final source = File(entry.key).readAsStringSync();
        final lines = source
            .split('\n')
            .where((line) => line.trimLeft().startsWith(entry.value));
        expect(lines, isNotEmpty, reason: '${entry.key}: nothing matched');
        for (final line in lines) {
          expect(
            line,
            contains('hafsVerseNumber'),
            reason: '${entry.key}: ${line.trim()}',
          );
        }
      }
    });

    test('the same words keep one key across all three readings', () {
      // The whole reason storage is keyed this way: a bookmark on these words
      // is one bookmark, whichever reading it was made in.
      final warsh = MushafReader.buildVerses(MushafEdition.warsh, 1, _fatiha);
      final hafs = QuranLocalService.versesOfSurah(1);

      expect(warsh[1].hafsKey, hafs[2].hafsKey);
      expect(warsh[1].key, isNot(hafs[2].key));
    });
  });

  group('Cutting a whole-surah recording at the ayah', () {
    test('the provider marks are read into start and end', () {
      final marks = AyahTimingService.parse([
        {'ayah': 1, 'start_time': 5565, 'end_time': 8589},
        {'ayah': 2, 'start_time': 8589, 'end_time': 12000},
      ]);

      expect(marks, hasLength(2));
      expect(marks.first.start, const Duration(milliseconds: 5565));
      expect(marks.first.end, const Duration(milliseconds: 8589));
    });

    test('the opening entry is not an ayah and is dropped', () {
      // Entry zero is the basmalah and the isti`adha before the surah starts.
      // Kept, it would make "play ayah 1" recite the introduction.
      final marks = AyahTimingService.parse([
        {'ayah': 0, 'start_time': 0, 'end_time': 7928},
        {'ayah': 1, 'start_time': 7928, 'end_time': 13700},
      ]);

      expect(marks, hasLength(1));
      expect(marks.single.ayah, 1);
    });

    test(
      'an end that is not after the start means "to the end of the file"',
      () {
        final marks = AyahTimingService.parse([
          {'ayah': 6, 'start_time': 30000, 'end_time': 0},
        ]);

        // Passed on as a clip, a backwards end plays nothing at all.
        expect(marks.single.end, isNull);
      },
    );

    test(
      'a recording with no marks answers empty, which is how it is hidden',
      () {
        expect(AyahTimingService.parse([]), isEmpty);
        expect(AyahTimingService.parse({'error': 'nope'}), isEmpty);
        expect(AyahTimingService.parse(null), isEmpty);
      },
    );

    test('marks come back in verse order whatever order they arrive in', () {
      final marks = AyahTimingService.parse([
        {'ayah': 3, 'start_time': 300},
        {'ayah': 1, 'start_time': 100},
        {'ayah': 2, 'start_time': 200},
      ]);

      expect(marks.map((mark) => mark.ayah), [1, 2, 3]);
      expect(AyahTimingService.find(marks, 2)?.start.inMilliseconds, 200);
      expect(AyahTimingService.find(marks, 9), isNull);
    });

    test('what is cached reads back as what was fetched', () {
      final original = AyahTimingService.parse([
        {'ayah': 1, 'start_time': 100, 'end_time': 200},
        {'ayah': 2, 'start_time': 200},
      ]);
      final restored = AyahTimingService.parseCache(
        jsonEncode([for (final mark in original) mark.toJson()]),
      );

      expect(restored, hasLength(2));
      expect(restored.first.end, const Duration(milliseconds: 200));
      expect(restored.last.end, isNull);
    });
  });

  group('One list of voices that can play one ayah', () {
    ReciterVoice voice({
      required String id,
      required int riwayaId,
      int surahs = 114,
    }) => ReciterVoice(
      id: id,
      nameAr: 'قارئ',
      styleAr: '',
      server: 'https://example.com/x/',
      riwayaId: riwayaId,
      surahs: {for (var i = 1; i <= surahs; i++) i},
    );

    test('the provider id is recovered from the stored key', () {
      expect(voice(id: 'mp3quran:118:270', riwayaId: 5).moshafId, 270);
      expect(voice(id: 'ar.alafasy', riwayaId: 1).moshafId, isNull);
      expect(voice(id: 'mp3quran:118', riwayaId: 1).moshafId, isNull);
    });

    test('candidates are the reading, with this surah, and a provider id', () {
      final candidates = VerseVoices.clipCandidates(
        voices: [
          voice(id: 'mp3quran:1:270', riwayaId: Riwaya.qaloonId),
          voice(id: 'mp3quran:2:271', riwayaId: Riwaya.warshId),
          voice(id: 'ar.alafasy', riwayaId: Riwaya.qaloonId),
          voice(id: 'mp3quran:3:272', riwayaId: Riwaya.qaloonId, surahs: 3),
        ],
        edition: MushafEdition.qaloon,
        surahNumber: 50,
      );

      // The Warsh one is the wrong reading, the bundled one has no provider
      // id to ask about marks with, and the partial one stops at surah 3.
      expect(candidates.map((voice) => voice.id), ['mp3quran:1:270']);
    });

    test('complete recordings are offered before partial ones', () {
      final candidates = VerseVoices.clipCandidates(
        voices: [
          voice(id: 'mp3quran:1:1', riwayaId: Riwaya.qaloonId, surahs: 7),
          voice(id: 'mp3quran:2:2', riwayaId: Riwaya.qaloonId),
        ],
        edition: MushafEdition.qaloon,
        surahNumber: 1,
      );

      expect(candidates.first.id, 'mp3quran:2:2');
    });

    test('a candidate is not shown until its marks are known to exist', () {
      // The rule the whole feature turns on. An unprobed recording is not
      // "probably fine": it is the row that used to be listed and then play
      // somebody else.
      AyahTimingService.resetForTest();
      final clips = VerseVoices.clips(
        voices: [voice(id: 'mp3quran:1:270', riwayaId: Riwaya.qaloonId)],
        edition: MushafEdition.qaloon,
        surahNumber: 1,
      );

      expect(clips, isEmpty);
      expect(AyahTimingService.knownSupport(270), isNull);
    });

    test('a clipped voice carries the numbering it was measured to use', () {
      final clipped = PlayableVerseVoice.fromClip(
        voice(id: 'mp3quran:1:270', riwayaId: Riwaya.qaloonId),
        VerseCounting.madaniAkhir,
      );

      expect(clipped.counting, VerseCounting.madaniAkhir);
      expect(clipped.isClipped, isTrue);
      expect(clipped.clip?.moshafId, 270);
    });

    test('a recording of a reading can still be marked in Hafs numbers', () {
      // Muhammad Sayed's Warsh recording, measured against the provider: 286
      // marks for al-Baqarah and 129 for al-Tawbah, which is the Kufan count,
      // while the other four Warsh recordings with marks use the Madani one.
      // Taking the numbering from the riwayah would have played him an ayah
      // out for the length of al-Baqarah, silently.
      final sayed = PlayableVerseVoice.fromClip(
        voice(id: 'mp3quran:134:134', riwayaId: Riwaya.warshId),
        VerseCounting.hafs,
      );

      expect(sayed.riwayaId, Riwaya.warshId);
      expect(sayed.counting, VerseCounting.hafs);
      expect(
        sayed.counting,
        isNot(MushafEdition.warsh.counting),
        reason: 'the recording and its reading disagree, which is the point',
      );
    });

    test('the probe surah is one where the two counts differ', () {
      // Al-Ikhlas has four verses in every reading and would let a recording
      // through with its numbering unknown. At-Tawbah has 129 or 130, which
      // is the whole answer in one number.
      expect(AyahTimingService.probeSurah, 9);
      expect(QuranLocalService.surahInfo(9).versesCount, 129);
    });

    test('the last mark says which scheme a recording was marked in', () {
      AyahTiming mark(int ayah) =>
          AyahTiming(ayah: ayah, start: Duration(seconds: ayah));

      expect(
        AyahTimingService.countingFrom([mark(1), mark(129)]),
        VerseCounting.hafs,
      );
      expect(
        AyahTimingService.countingFrom([mark(1), mark(130)]),
        VerseCounting.madaniAkhir,
      );
      // Neither count. Refused rather than filed under a guess, because a
      // wrong verdict plays the wrong ayah without failing.
      expect(AyahTimingService.countingFrom([mark(1), mark(64)]), isNull);
      expect(AyahTimingService.countingFrom(const []), isNull);
    });

    test('a verdict survives being written down and read back', () {
      final stored = AyahTimingService.writeVerdicts({
        134: VerseCounting.hafs,
        120: VerseCounting.madaniAkhir,
        178: null,
      });
      final restored = AyahTimingService.readVerdicts(stored);

      expect(restored[134], VerseCounting.hafs);
      expect(restored[120], VerseCounting.madaniAkhir);
      expect(restored.containsKey(178), isTrue);
      expect(restored[178], isNull);
      // Stored by name, so adding a scheme later cannot re-read an old
      // verdict as a different one.
      expect(stored, contains('madaniAkhir'));
      expect(AyahTimingService.readVerdicts(null), isEmpty);
      expect(AyahTimingService.readVerdicts('not json'), isEmpty);
    });

    test('an unmeasured recording is not shown, a measured one is', () {
      AyahTimingService.resetForTest();
      final candidate = voice(id: 'mp3quran:1:270', riwayaId: Riwaya.qaloonId);

      expect(
        VerseVoices.clips(
          voices: [candidate],
          edition: MushafEdition.qaloon,
          surahNumber: 1,
        ),
        isEmpty,
      );

      AyahTimingService.seedVerdictForTest(270, VerseCounting.madaniAkhir);
      final shown = VerseVoices.clips(
        voices: [candidate],
        edition: MushafEdition.qaloon,
        surahNumber: 1,
      );
      expect(shown, hasLength(1));
      expect(shown.single.counting, VerseCounting.madaniAkhir);

      // A recording measured as having no marks stays hidden for good.
      AyahTimingService.seedVerdictForTest(270, null);
      expect(
        VerseVoices.clips(
          voices: [candidate],
          edition: MushafEdition.qaloon,
          surahNumber: 1,
        ),
        isEmpty,
      );
      expect(AyahTimingService.knownSupport(270), isFalse);
      AyahTimingService.resetForTest();
    });

    test('a per-ayah voice keeps its own measured numbering', () {
      final file = PlayableVerseVoice.fromFile(
        VerseReciters.find('warsh-dosary')!,
      );

      expect(file.isClipped, isFalse);
      expect(file.counting, VerseCounting.hafs);
    });

    test('Hafs is not probed, because it already has the longest list', () {
      expect(VerseVoices.files(MushafEdition.hafs), isNotEmpty);
      expect(VerseVoices.files(MushafEdition.warsh), isNotEmpty);
    });
  });

  group('Reaching the provider at all', () {
    test('the catalogue asks a host the client is allowed to answer', () {
      // The bare domain answers 301 and the client follows no redirects, so a
      // catalogue pointed at it is rejected before it leaves the device — and
      // the picker silently falls back to the seven bundled voices, which is
      // the complaint the whole unified list was built to answer.
      expect(SecureHttpClient.allowedHosts, contains('www.mp3quran.net'));
      expect(SecureHttpClient.allowedHosts, isNot(contains('mp3quran.net')));
      expect(ReciterCatalogue.endpoint, startsWith('https://www.mp3quran.net'));
      expect(
        ReciterCatalogue.riwayatEndpoint,
        startsWith('https://www.mp3quran.net'),
      );
      expect(
        AyahTimingService.endpoint,
        startsWith('https://www.mp3quran.net'),
      );
    });
  });
}
