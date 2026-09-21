import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:islamic_app/features/broadcasts/data/recordings_catalogue.dart';
import 'package:islamic_app/features/broadcasts/domain/recording.dart';
import 'package:islamic_app/features/broadcasts/presentation/providers/recordings_provider.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';

/// Every fixture below is an excerpt of a real `archive.org/metadata` payload,
/// copied rather than written: the irregular names, the two ways of writing a
/// length, the derived copies — each is here because the real item has it.
Map<String, dynamic> _payload(List<Map<String, dynamic>> files) => {
  'files': files,
};

RecordingCollection _collection(String id) => RecordingsCatalogue.byId(id)!;

/// `ramadan1445makkahtaraweeh`, nights 1, 4 and 29, with the derived images
/// the archive generates beside every file.
final _makkah1445 = _payload([
  {
    'name': '01ramadan1445first4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '1485.19',
  },
  {
    'name': '01ramadan1445first4rakahmakkahtaraweeh.png',
    'source': 'derivative',
  },
  {
    'name': '01ramadan1445first4rakahmakkahtaraweeh_notakbeer.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '1040.3',
  },
  {
    'name': '01ramadan1445last2rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '525.77',
  },
  {
    'name': '01ramadan1445last2rakahmakkahtaraweeh_notakbeer.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '390.62',
  },
  {
    'name': '01ramadan1445second4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '1183.37',
  },
  {
    'name': '01ramadan1445second4rakahmakkahtaraweeh_notakbeer.mp3',
    'source': 'original',
    'title': 'Ramadan 01, 1445',
    'length': '733.37',
  },
  {
    'name': '04ramadan1445first4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 04, 1445',
    'length': '1632.1',
  },
  {
    'name': '04ramadan1445last2rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 04, 1445',
    'length': '663.96',
  },
  {
    'name': '04ramadan1445next4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 04, 1445',
    'length': '1300.63',
  },
  {
    'name': '04ramadan1445next4rakahmakkahtaraweeh_notakbeer.mp3',
    'source': 'original',
    'title': 'Ramadan 04, 1445',
    'length': '824.69',
  },
  {
    'name': '29ramadan1445first4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 29, 1445',
    'length': '1695.22',
  },
  {
    'name': '29ramadan1445last2rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 29, 1445',
    'length': '419.28',
  },
  {
    'name': '29ramadan1445makkahkhatamalquraanduaa.mp3',
    'source': 'original',
    'title': 'Ramadan 29, 1445',
    'length': '1634.71',
  },
  {
    'name': '29ramadan1445second4rakahmakkahtaraweeh.mp3',
    'source': 'original',
    'title': 'Ramadan 29, 1445',
    'length': '1373.4',
  },
]);

void main() {
  group('The catalogue', () {
    test('every collection is findable and none shares an id', () {
      final ids = RecordingsCatalogue.collections.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final collection in RecordingsCatalogue.collections) {
        expect(RecordingsCatalogue.byId(collection.id), same(collection));
        expect(collection.titleAr, isNotEmpty, reason: collection.id);
        expect(collection.reciterAr, isNotEmpty, reason: collection.id);
      }
    });

    test('both shelves have something on them', () {
      expect(RecordingsCatalogue.of(RecordingCategory.rare), isNotEmpty);
      expect(RecordingsCatalogue.of(RecordingCategory.taraweeh), isNotEmpty);
    });

    test('an archive collection is keyed by the item it reads', () {
      // The id is what positions and cached lists are stored under, so it
      // has to follow the item rather than a label that might be reworded.
      for (final collection in RecordingsCatalogue.collections) {
        if (collection.source == RecordingSource.archive) {
          expect(collection.id, 'archive:${collection.identifier}');
        } else {
          expect(collection.id, collection.identifier);
        }
      }
    });

    test('the Haramain uploads keep the prayer and drop the bare copy', () {
      for (final collection in RecordingsCatalogue.of(
        RecordingCategory.taraweeh,
      )) {
        if (collection.layout == TrackLayout.night) {
          expect(collection.exclude, contains('notakbeer'));
          expect(collection.exclude, contains('withouttakbeer'));
        }
      }
    });

    test('the live stations are addressed the way the radio list is', () {
      for (final id in RecordingsCatalogue.liveRadioIds) {
        expect(id, startsWith('radio:'));
      }
    });

    test('the metadata host is one the guarded client will reach', () {
      // The client throws inside an interceptor on any other host, so this
      // failing would not look like a networking change. It would look like
      // every collection being empty.
      expect(SecureHttpClient.allowedHosts, contains('archive.org'));
      expect(
        Uri.parse(RecordingsCatalogue.metadataEndpoint).host,
        'archive.org',
      );
    });
  });

  group('The two ways the archive writes a length', () {
    test('seconds as a decimal', () {
      expect(
        RecordingsCatalogue.parseLength('1485.19'),
        const Duration(milliseconds: 1485190),
      );
    });

    test('a clock, with or without hours', () {
      // `101:38` is how the archive writes the derived copies of an item
      // whose originals it writes as seconds. Both appear in one payload.
      expect(
        RecordingsCatalogue.parseLength('28:02'),
        const Duration(minutes: 28, seconds: 2),
      );
      expect(
        RecordingsCatalogue.parseLength('101:38'),
        const Duration(minutes: 101, seconds: 38),
      );
      expect(
        RecordingsCatalogue.parseLength('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('anything else is unknown rather than zero', () {
      expect(RecordingsCatalogue.parseLength(null), isNull);
      expect(RecordingsCatalogue.parseLength(''), isNull);
      expect(RecordingsCatalogue.parseLength('soon'), isNull);
      expect(RecordingsCatalogue.parseLength('0'), isNull);
      expect(RecordingsCatalogue.parseLength('1:xx'), isNull);
      expect(RecordingsCatalogue.parseLength(90), const Duration(seconds: 90));
    });
  });

  group('A night of Taraweeh', () {
    final collection = _collection('archive:ramadan1445makkahtaraweeh');
    final tracks = RecordingsCatalogue.parseArchive(collection, _makkah1445);

    test('the copies without takbirat and the derived images are gone', () {
      for (final track in tracks) {
        expect(track.url, isNot(contains('notakbeer')));
        expect(track.url, endsWith('.mp3'));
      }
      expect(tracks, hasLength(10));
    });

    test('the rak`ahs are counted from the parts, not assumed', () {
      final first = [
        for (final track in tracks)
          if (track.group == 'الليلة 1') track.titleAr,
      ];
      expect(first, ['الركعات 1–4', 'الركعات 5–8', 'الركعات 9–10']);
    });

    test('a part named `next4` is the second set, in its place', () {
      // Night 4 of 1445 says `next4` where every other night says `second4`.
      // Sorted by name it would land last; read as a rank, it is second.
      final fourth = [
        for (final track in tracks)
          if (track.group == 'الليلة 4') track.titleAr,
      ];
      expect(fourth, ['الركعات 1–4', 'الركعات 5–8', 'الركعات 9–10']);
    });

    test('the du`a of completing the Qur’an is kept, and named', () {
      final last = [
        for (final track in tracks)
          if (track.group == 'الليلة 29') track.titleAr,
      ];
      expect(last, [
        'الركعات 1–4',
        'الركعات 5–8',
        'الركعات 9–10',
        'دعاء ختم القرآن',
      ]);
    });

    test('nights come in order, and so do the tracks within them', () {
      final groups = <String>[];
      for (final track in tracks) {
        if (groups.isEmpty || groups.last != track.group) {
          groups.add(track.group!);
        }
      }
      expect(groups, ['الليلة 1', 'الليلة 4', 'الليلة 29']);
      expect(
        tracks.map((track) => track.order),
        List<int>.generate(tracks.length, (index) => index),
      );
    });

    test('each part carries its length and a playable address', () {
      final opening = tracks.first;
      expect(opening.duration, const Duration(milliseconds: 1485190));
      expect(
        opening.url,
        'https://archive.org/download/ramadan1445makkahtaraweeh/'
        '01ramadan1445first4rakahmakkahtaraweeh.mp3',
      );
      expect(opening.id, startsWith('${collection.id}/'));
    });

    test('a file that fits no pattern is kept rather than dropped', () {
      final odd = RecordingsCatalogue.parseArchive(
        collection,
        _payload([
          {
            'name': '07ramadan1445makkahwitr.mp3',
            'source': 'original',
            'length': '300',
          },
          {'name': 'readme-notes.mp3', 'source': 'original', 'length': '60'},
        ]),
      );

      expect(odd, hasLength(2));
      expect(odd.first.group, 'الليلة 7');
      expect(odd.last.group, isNull);
    });
  });

  group('One file per surah', () {
    final collection = _collection('archive:MakkahTaraweeh1429');

    test('the derived copies are not listed beside the original', () {
      // 1429 carries a 64 kb/s copy, a VBR copy and an ogg of every surah,
      // each marked derivative. Listed, al-Baqarah would appear three times.
      final tracks = RecordingsCatalogue.parseArchive(
        collection,
        _payload([
          {
            'name': '002-Surah-Al-Baqarah.mp3',
            'source': 'original',
            'title': '002 - Surah Al Baqarah - 1429',
            'length': '6098.66',
          },
          {
            'name': '002-Surah-Al-Baqarah.ogg',
            'source': 'derivative',
            'length': '6098.6',
          },
          {
            'name': '002-Surah-Al-Baqarah_64kb.mp3',
            'source': 'derivative',
            'length': '101:38',
          },
          {
            'name': '002-Surah-Al-Baqarah_vbr.mp3',
            'source': 'derivative',
            'length': '101:38',
          },
        ]),
      );

      expect(tracks, hasLength(1));
      expect(
        tracks.single.titleAr,
        'سورة ${QuranLocalService.surahInfo(2).nameAr}',
      );
    });

    test('a number past 114 is not taken for a surah', () {
      final tracks = RecordingsCatalogue.parseArchive(
        collection,
        _payload([
          {
            'name': '115-closing-dua.mp3',
            'source': 'original',
            'title': '115 - Closing Dua',
          },
        ]),
      );
      expect(tracks.single.titleAr, isNot(startsWith('سورة')));
    });
  });

  group('A file with its own Arabic title', () {
    test('the venue and year are the title, in natural order', () {
      // Named 1, 10, 100, 2 on the server. Sorted as text that is the order
      // they would be shown in, for all 245 of them.
      final tracks = RecordingsCatalogue.parseArchive(
        _collection('archive:way2sona_20160404'),
        _payload([
          {
            'name': '1.mp3',
            'source': 'original',
            'title': 'ارمنت - 1981',
            'length': '3226.57',
          },
          {
            'name': '10.mp3',
            'source': 'original',
            'title': 'مسجد الحسين - 1971',
            'length': '1424.23',
          },
          {
            'name': '100.mp3',
            'source': 'original',
            'title': 'الاسكندرية - 1952',
            'length': '1755.25',
          },
          {
            'name': '2.mp3',
            'source': 'original',
            'title': 'الحرم المكى - 1969',
            'length': '1719.44',
          },
        ]),
      );

      expect(tracks.map((track) => track.titleAr), [
        'ارمنت - 1981',
        'الحرم المكى - 1969',
        'مسجد الحسين - 1971',
        'الاسكندرية - 1952',
      ]);
    });

    test('the uploader’s signature and running number come off', () {
      final tracks = RecordingsCatalogue.parseArchive(
        _collection('archive:Mohammed_Refat_uP_bY_mUSLEm'),
        _payload([
          {
            'name': '001-_up_by_muslem.mp3',
            'source': 'original',
            'title': '001-آذان الشيخ محمد رفعت_uP_bY_mUSLEm',
            'length': '242.08',
          },
          {
            'name': '002-33-51_up_by_muslem.mp3',
            'source': 'original',
            'title': '002-آل عمران 33-51_uP_bY_mUSLEm',
            'length': '2761.03',
          },
          {
            'name': '003-39-49_up_by_muslem.mp3',
            'source': 'original',
            'title': '003-آل عمران 39-49 بصيغة أخرى_uP_bY_mUSLEm',
            'length': '1738.53',
          },
        ]),
      );

      expect(tracks.map((track) => track.titleAr), [
        'آذان الشيخ محمد رفعت',
        'آل عمران 33-51',
        'آل عمران 39-49 بصيغة أخرى',
      ]);
    });

    test('files that would read the same are numbered beneath', () {
      // Islamic_Tape-623: al-Baqarah is three files, each titled «البقرة».
      final tracks = RecordingsCatalogue.parseArchive(
        _collection('archive:Islamic_Tape-623_uP_bY_mUSLEm'),
        _payload([
          {
            'name': '001.mp3',
            'source': 'original',
            'title': 'الفاتحة - البقرة',
          },
          {'name': '002.mp3', 'source': 'original', 'title': 'البقرة'},
          {'name': '003.mp3', 'source': 'original', 'title': 'البقرة'},
          {'name': '004.mp3', 'source': 'original', 'title': 'البقرة'},
          {'name': '005.mp3', 'source': 'original', 'title': 'آل عمران'},
        ]),
      );

      expect(tracks.map((track) => track.subtitleAr), [
        '',
        'المقطع 1',
        'المقطع 2',
        'المقطع 3',
        '',
      ]);
      // The title itself is untouched, so a search or a heading still reads
      // as the surah.
      expect(tracks[2].titleAr, 'البقرة');
    });

    test('the same part name on different nights is not a repeat', () {
      final tracks = RecordingsCatalogue.parseArchive(
        _collection('archive:ramadan1445makkahtaraweeh'),
        _makkah1445,
      );
      for (final track in tracks) {
        expect(track.subtitleAr, isNot(contains('المقطع')));
      }
    });

    test('a file with no title and a bare number is still named', () {
      final tracks = RecordingsCatalogue.parseArchive(
        _collection('archive:way2sona_20160404'),
        _payload([
          {'name': '17.mp3', 'source': 'original'},
        ]),
      );
      expect(tracks.single.titleAr, 'تلاوة 17');
    });
  });

  group('A file named for a video site', () {
    final collection = _collection('archive:20230814_20230814_1538');
    final tracks = RecordingsCatalogue.parseArchive(
      collection,
      _payload([
        {
          'name':
              '020 s 49  50  هل هذا يعقل ! هذا الصوت كأنه قادم من الجنة ! '
              'قارئ القلوب ❤️   الحجرات و ق.mp3',
          'source': 'original',
          'length': '2831.57',
        },
        {
          'name':
              '021 s 50  55  اجمل تلاوة نادرة للشيخ المنشاوي سورة ق والرحمن '
              'عام 1966 م.mp3',
          'source': 'original',
          'length': '1890.12',
        },
        {
          'name':
              '022 s 52    إبداع لا متناهي في تلاوة رائعة !! أرح بها بالك '
              'ومسمعك ♡   جودة عالية.mp3',
          'source': 'original',
          'length': '2100.04',
        },
      ]),
    );

    String nameOf(int surah) => QuranLocalService.surahInfo(surah).nameAr;

    test('is titled by the surahs it holds, not by what it shouted', () {
      expect(tracks.map((track) => track.titleAr), [
        'من سورتي ${nameOf(49)} و${nameOf(50)}',
        'من سورتي ${nameOf(50)} و${nameOf(55)}',
        'من سورة ${nameOf(52)}',
      ]);
    });

    test('none of the video site’s words reach the screen', () {
      for (final track in tracks) {
        for (final word in ['!', '❤', '♡', 'يعقل', 'إبداع', 'جودة']) {
          expect(track.titleAr, isNot(contains(word)));
          expect(track.subtitleAr, isNot(contains(word)));
        }
      }
    });

    test('a year in the name is kept, beneath', () {
      expect(tracks[1].subtitleAr, '1966م');
      expect(tracks[0].subtitleAr, isEmpty);
    });

    test('the file address still carries the whole name, escaped', () {
      expect(tracks.first.url, contains('%D9%87%D9%84'));
      expect(tracks.first.url, isNot(contains(' ')));
      expect(tracks.first.url, isNot(contains('❤')));
      expect(Uri.tryParse(tracks.first.url), isNotNull);
    });
  });

  group('Picking up where a recording was left', () {
    const length = Duration(minutes: 90);

    test('a place well inside the file is resumed', () {
      expect(
        RecordingsController.resumeFrom(const Duration(minutes: 41), length),
        const Duration(minutes: 41),
      );
    });

    test('the first seconds start again from the top', () {
      // A mis-tap, or a file stopped almost as soon as it began: resuming
      // eight seconds in only clips the opening of the recitation.
      expect(
        RecordingsController.resumeFrom(const Duration(seconds: 8), length),
        isNull,
      );
    });

    test('the last half-minute counts as finished', () {
      // Resuming there plays silence and then stops, which reads as broken.
      expect(
        RecordingsController.resumeFrom(
          length - const Duration(seconds: 12),
          length,
        ),
        isNull,
      );
    });

    test('an unknown length does not stop a resume', () {
      expect(
        RecordingsController.resumeFrom(const Duration(minutes: 5), null),
        const Duration(minutes: 5),
      );
      expect(RecordingsController.resumeFrom(null, length), isNull);
    });

    test(
      'a part of a night is named with its night where there is no page',
      () {
        // On the lock screen the heading «الليلة 4» is not there to read, so
        // «الركعات 5–8» alone would not say which night.
        const part = RecordingTrack(
          id: 'a/1',
          titleAr: 'الركعات 5–8',
          url: 'https://archive.org/download/a/1.mp3',
          group: 'الليلة 4',
        );
        const single = RecordingTrack(
          id: 'a/2',
          titleAr: 'سورة البقرة',
          url: 'https://archive.org/download/a/2.mp3',
        );
        expect(
          RecordingsController.displayTitle(part),
          'الليلة 4 · الركعات 5–8',
        );
        expect(RecordingsController.displayTitle(single), 'سورة البقرة');
      },
    );

    test('a failure is named for the reader, not the stack trace', () {
      expect(
        RecordingsController.describe(Exception('SocketException: failed')),
        'audio_no_network',
      );
      expect(
        RecordingsController.describe(Exception('Source error 404')),
        'recording_failed',
      );
    });
  });

  group('The small pieces', () {
    test('surah tags are real surahs, once each, in order', () {
      expect(RecordingsCatalogue.surahsTagged('012 s 26  89 نص'), [26, 89]);
      expect(RecordingsCatalogue.surahsTagged('017 s 48  48  50 نص'), [48, 50]);
      expect(RecordingsCatalogue.surahsTagged('099 s 0 115 3 نص'), [3]);
      expect(RecordingsCatalogue.surahsTagged('no tag here'), isEmpty);
    });

    test('a list of surahs reads as Arabic', () {
      String nameOf(int surah) => QuranLocalService.surahInfo(surah).nameAr;
      expect(RecordingsCatalogue.surahPhrase([50]), 'من سورة ${nameOf(50)}');
      expect(
        RecordingsCatalogue.surahPhrase([61, 62, 63]),
        'من سور ${nameOf(61)} و${nameOf(62)} و${nameOf(63)}',
      );
    });

    test('a folder inside an item keeps its slash', () {
      expect(
        RecordingsCatalogue.archiveUrl('item', 'CD 1/سورة.mp3'),
        'https://archive.org/download/item/CD%201/'
        '%D8%B3%D9%88%D8%B1%D8%A9.mp3',
      );
    });

    test('natural order reads the leading number', () {
      expect(RecordingsCatalogue.leadingNumber('100.mp3'), 100);
      expect(RecordingsCatalogue.leadingNumber(' 007 s 16'), 7);
      expect(RecordingsCatalogue.leadingNumber('Al-Aaraf1.mp3'), isNull);
    });

    test('a cleaned title loses only what is not the title', () {
      expect(
        RecordingsCatalogue.cleanTitle('005-سورة الشمس 1'),
        'سورة الشمس 1',
      );
      expect(RecordingsCatalogue.cleanTitle('سورة البروج'), 'سورة البروج');
      expect(RecordingsCatalogue.cleanTitle('001.mp3'), '001');
      expect(RecordingsCatalogue.cleanTitle('_uP_bY_mUSLEm'), isEmpty);
    });

    test('a track survives being cached and read back', () {
      const track = RecordingTrack(
        id: 'archive:x/1.mp3',
        titleAr: 'الركعات 1–4',
        subtitleAr: '1966م',
        url: 'https://archive.org/download/x/1.mp3',
        duration: Duration(seconds: 90),
        group: 'الليلة 1',
        order: 3,
      );
      final back = RecordingTrack.fromJson(track.toJson())!;

      expect(back.id, track.id);
      expect(back.titleAr, track.titleAr);
      expect(back.subtitleAr, track.subtitleAr);
      expect(back.url, track.url);
      expect(back.duration, track.duration);
      expect(back.group, track.group);
      expect(back.order, 3);
      expect(RecordingTrack.fromJson({'id': 'x'}), isNull);
    });

    test('a payload that is not what was asked for is empty, not a crash', () {
      final collection = _collection('archive:MakkahTaraweeh1429');
      expect(RecordingsCatalogue.parseArchive(collection, null), isEmpty);
      expect(RecordingsCatalogue.parseArchive(collection, 'x'), isEmpty);
      expect(
        RecordingsCatalogue.parseArchive(collection, {'files': 3}),
        isEmpty,
      );
      expect(
        RecordingsCatalogue.parseArchive(collection, {
          'files': [
            {'name': 42},
            'junk',
          ],
        }),
        isEmpty,
      );
    });
  });
}
