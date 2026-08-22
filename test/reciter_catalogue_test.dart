import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/data/services/reciter_catalogue.dart';

/// A slice of the real mp3quran payload, copied from the live response.
final _payload = <String, dynamic>{
  'reciters': [
    {
      'id': 1,
      'name': 'إبراهيم الأخضر',
      'moshaf': [
        {
          'id': 1,
          'name': 'حفص عن عاصم - مرتل',
          'server': 'https://server6.mp3quran.net/akdr/',
          'surah_total': 114,
          'surah_list': [for (var i = 1; i <= 114; i++) i].join(','),
        },
      ],
    },
    {
      'id': 30,
      'name': 'محمود خليل الحصري',
      'moshaf': [
        {
          'id': 40,
          'name': 'حفص عن عاصم - مرتل',
          'server': 'https://server13.mp3quran.net/husr/',
          'surah_list': '1,2,3',
        },
        {
          'id': 41,
          'name': 'حفص عن عاصم - مجود',
          'server': 'https://server11.mp3quran.net/hsr/',
          'surah_list': '1,2',
        },
      ],
    },
    {
      'id': 99,
      'name': 'قارئ بلا تشفير',
      'moshaf': [
        {
          'id': 1,
          'name': 'مرتل',
          // Plain http is blocked by the network security config, so listing
          // it would offer a voice that cannot play.
          'server': 'http://insecure.example.com/x/',
          'surah_list': '1',
        },
      ],
    },
  ],
};

void main() {
  group('Reading the catalogue', () {
    test('one entry per recording, not per reciter', () {
      final voices = ReciterCatalogue.parse(_payload);

      // Al-Husary has murattal and mujawwad; they are different recordings.
      final husary = voices.where((v) => v.nameAr.contains('الحصري')).toList();
      expect(husary.length, 2);
      expect(husary.map((v) => v.styleAr).toSet().length, 2);
    });

    test('drops anything served over plain http', () {
      final voices = ReciterCatalogue.parse(_payload);
      expect(voices.any((v) => v.server.startsWith('http://')), isFalse);
      expect(voices.any((v) => v.nameAr.contains('بلا تشفير')), isFalse);
    });

    test('ids survive the list being re-ordered', () {
      final voices = ReciterCatalogue.parse(_payload);
      expect(voices.map((v) => v.id).toSet().length, voices.length);
      expect(voices.any((v) => v.id == 'mp3quran:30:41'), isTrue);
    });

    test('a partial recording only offers the surahs it has', () {
      final voices = ReciterCatalogue.parse(_payload);
      final mujawwad = voices.firstWhere((v) => v.id == 'mp3quran:30:41');

      expect(mujawwad.has(1), isTrue);
      expect(mujawwad.has(2), isTrue);
      expect(mujawwad.has(3), isFalse);
      expect(mujawwad.urlFor(3), isNull, reason: 'better than a 404');
      expect(mujawwad.urlFor(1), endsWith('/001.mp3'));
    });

    test('a missing trailing slash on the server is handled', () {
      final voices = ReciterCatalogue.parse({
        'reciters': [
          {
            'id': 5,
            'name': 'قارئ',
            'moshaf': [
              {
                'id': 1,
                'name': 'مرتل',
                'server': 'https://example.mp3quran.net/abc',
                'surah_list': '7',
              },
            ],
          },
        ],
      });
      expect(
        voices.single.urlFor(7),
        'https://example.mp3quran.net/abc/007.mp3',
      );
    });

    test('survives a payload that is not what it expects', () {
      expect(ReciterCatalogue.parse({}), isEmpty);
      expect(ReciterCatalogue.parse({'reciters': 'nope'}), isEmpty);
      expect(
        ReciterCatalogue.parse({
          'reciters': [
            {'name': '', 'moshaf': []},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('Round-tripping through the cache', () {
    test('a voice survives being written and read back', () {
      final original = ReciterCatalogue.parse(_payload).first;
      final restored = ReciterVoice.fromJson(original.toJson())!;

      expect(restored.id, original.id);
      expect(restored.nameAr, original.nameAr);
      expect(restored.server, original.server);
      expect(restored.surahs, original.surahs);
    });
  });

  group('Resolving a catalogue voice to a URL', () {
    test('a registered host builds the same shape as a bundled one', () {
      QuranLocalService.registerSurahHost(
        'mp3quran:30:41',
        'https://server11.mp3quran.net/hsr/',
      );

      expect(QuranLocalService.hasSurahAudio('mp3quran:30:41'), isTrue);
      expect(
        QuranLocalService.audioUrlForSurah(2, reciterCode: 'mp3quran:30:41'),
        'https://server11.mp3quran.net/hsr/002.mp3',
      );
    });

    test('plain http is refused even here', () {
      QuranLocalService.registerSurahHost('bad', 'http://example.com/');
      expect(QuranLocalService.hasSurahAudio('bad'), isFalse);
    });
  });

  test('duplicate moshaf ids are kept once', () {
    final voices = ReciterCatalogue.parse({
      'reciters': [
        {
          'id': 92,
          'name': 'Test',
          'moshaf': [
            {
              'id': 92,
              'name': 'A',
              'server': 'https://server1.mp3quran.net/a/',
              'surah_list': '1',
            },
            {
              'id': 92,
              'name': 'B',
              'server': 'https://server1.mp3quran.net/b/',
              'surah_list': '1',
            },
          ],
        },
      ],
    });
    expect(voices.where((voice) => voice.id == 'mp3quran:92:92').length, 1);
  });
}
