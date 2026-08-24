import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/broadcasts/data/broadcast_catalogue.dart';
import 'package:islamic_app/features/broadcasts/domain/broadcast.dart';

Map<String, dynamic> _radios(List<Map<String, dynamic>> entries) => {
  'radios': entries,
};

void main() {
  group('Reading the station list', () {
    test('the host that answers is tried first, the published one second', () {
      // Measured, not assumed: over a sample of ten stations qurango.net
      // answered ten times and backup.qurango.net eight. So the published
      // address becomes the fallback and the primary is tried first.
      final parsed = BroadcastCatalogue.parse(
        _radios([
          {
            'id': 3,
            'name': 'إذاعة أحمد العجمي',
            'url': 'https://backup.qurango.net/radio/ahmad_alajmy',
          },
        ]),
        'radios',
        BroadcastKind.radio,
      );

      final station = parsed.single;
      expect(station.url, 'https://qurango.net/radio/ahmad_alajmy');
      expect(
        station.fallbackUrl,
        'https://backup.qurango.net/radio/ahmad_alajmy',
      );
      expect(station.sources.length, 2);
    });

    test('a station on another host is left exactly as published', () {
      final station =
          BroadcastCatalogue.parse(
            _radios([
              {
                'id': 9,
                'name': 'إذاعة القرآن الكريم - السعودية',
                'url': 'https://stream.radiojar.com/0tpy1h0kxtzuv',
              },
            ]),
            'radios',
            BroadcastKind.radio,
          ).single;

      expect(station.url, 'https://stream.radiojar.com/0tpy1h0kxtzuv');
      expect(station.fallbackUrl, isNull);
      expect(station.sources, hasLength(1));
    });

    test('anything served over plain http is dropped, not listed', () {
      // The app refuses cleartext, so listing one would be offering a station
      // that cannot possibly play.
      final parsed = BroadcastCatalogue.parse(
        _radios([
          {'id': 1, 'name': 'A', 'url': 'http://insecure.example/stream'},
          {'id': 2, 'name': 'B', 'url': 'https://qurango.net/radio/b'},
        ]),
        'radios',
        BroadcastKind.radio,
      );

      expect(parsed.map((s) => s.name), ['B']);
    });

    test('an entry with no name or no id is skipped', () {
      final parsed = BroadcastCatalogue.parse(
        _radios([
          {'id': 1, 'name': '', 'url': 'https://qurango.net/radio/a'},
          {'name': 'no id', 'url': 'https://qurango.net/radio/b'},
          {'id': 3, 'name': 'fine', 'url': 'https://qurango.net/radio/c'},
        ]),
        'radios',
        BroadcastKind.radio,
      );

      expect(parsed.map((s) => s.name), ['fine']);
    });

    test('a repeated id is kept once', () {
      final parsed = BroadcastCatalogue.parse(
        _radios([
          {'id': 7, 'name': 'A', 'url': 'https://qurango.net/radio/a'},
          {'id': 7, 'name': 'A again', 'url': 'https://qurango.net/radio/a'},
        ]),
        'radios',
        BroadcastKind.radio,
      );
      expect(parsed, hasLength(1));
    });

    test('ids carry their kind, so a radio and a channel cannot collide', () {
      final radio =
          BroadcastCatalogue.parse(
            _radios([
              {'id': 3, 'name': 'R', 'url': 'https://qurango.net/radio/a'},
            ]),
            'radios',
            BroadcastKind.radio,
          ).single;
      final tv =
          BroadcastCatalogue.parse(
            {
              'livetv': [
                {
                  'id': 3,
                  'name': 'قناة القرآن الكريم',
                  'url': 'https://win.holol.com/live/quran/playlist.m3u8',
                },
              ],
            },
            'livetv',
            BroadcastKind.tv,
          ).single;

      expect(radio.id, isNot(tv.id));
      expect(tv.kind, BroadcastKind.tv);
    });

    test('a payload that is not what it expects returns nothing', () {
      expect(
        BroadcastCatalogue.parse({}, 'radios', BroadcastKind.radio),
        isEmpty,
      );
      expect(
        BroadcastCatalogue.parse(
          {'radios': 'oops'},
          'radios',
          BroadcastKind.radio,
        ),
        isEmpty,
      );
      expect(
        BroadcastCatalogue.parse(
          {
            'radios': [1, 'two', null],
          },
          'radios',
          BroadcastKind.radio,
        ),
        isEmpty,
      );
    });
  });

  group('Finding a station by name', () {
    final stations = BroadcastCatalogue.parse(
      _radios([
        {
          'id': 1,
          'name': 'إذاعة القرآن الكريم - السعودية',
          'url': 'https://qurango.net/radio/a',
        },
        {
          'id': 2,
          'name': 'إذاعة أحمد العجمي',
          'url': 'https://qurango.net/radio/b',
        },
        {
          'id': 3,
          'name': 'إذاعة سعد الغامدي',
          'url': 'https://qurango.net/radio/c',
        },
      ]),
      'radios',
      BroadcastKind.radio,
    );

    test('typing without the diacritics still finds it', () {
      expect(BroadcastCatalogue.search(stations, 'القران'), hasLength(1));
      expect(BroadcastCatalogue.search(stations, 'اذاعة'), hasLength(3));
    });

    test('a bare alif finds a hamza and vice versa', () {
      expect(BroadcastCatalogue.search(stations, 'احمد'), hasLength(1));
      expect(BroadcastCatalogue.search(stations, 'أحمد'), hasLength(1));
    });

    test('an empty query is not a filter', () {
      expect(BroadcastCatalogue.search(stations, '   '), hasLength(3));
    });

    test('no match says so rather than showing everything', () {
      expect(BroadcastCatalogue.search(stations, 'zzz'), isEmpty);
    });
  });

  group('The station the catalogue leaves out', () {
    test('Cairo is pinned, because mp3quran does not carry it', () {
      // It is what most people in Egypt mean by "إذاعة القرآن الكريم" and it is
      // simply not in the API's 177 entries.
      final cairo = BroadcastCatalogue.pinned.single;
      expect(cairo.name, contains('القاهرة'));
      expect(cairo.kind, BroadcastKind.radio);
      expect(cairo.pinned, isTrue);
      expect(cairo.url, startsWith('https://'));
    });
  });

  group('A station survives being cached and read back', () {
    test('round trip keeps both addresses and the pin', () {
      const station = Broadcast(
        id: 'radio:3',
        name: 'إذاعة',
        url: 'https://qurango.net/radio/a',
        fallbackUrl: 'https://backup.qurango.net/radio/a',
        kind: BroadcastKind.radio,
        pinned: true,
        noteAr: 'ملاحظة',
      );

      final back = Broadcast.fromJson(station.toJson())!;
      expect(back.id, station.id);
      expect(back.url, station.url);
      expect(back.fallbackUrl, station.fallbackUrl);
      expect(back.pinned, isTrue);
      expect(back.noteAr, 'ملاحظة');
      expect(back.kind, BroadcastKind.radio);
    });

    test('a cache entry with no url is dropped rather than crashing', () {
      expect(Broadcast.fromJson({'id': 'x', 'name': 'y'}), isNull);
      expect(Broadcast.fromJson({'url': 'https://a', 'name': 'y'}), isNull);
    });
  });

  group('Splitting the list by kind', () {
    test('radio and television are separated', () {
      const all = [
        Broadcast(
          id: 'a',
          name: 'R',
          url: 'https://a',
          kind: BroadcastKind.radio,
        ),
        Broadcast(id: 'b', name: 'T', url: 'https://b', kind: BroadcastKind.tv),
      ];

      expect(BroadcastCatalogue.of(all, BroadcastKind.radio).single.name, 'R');
      expect(BroadcastCatalogue.of(all, BroadcastKind.tv).single.name, 'T');
    });
  });
}
