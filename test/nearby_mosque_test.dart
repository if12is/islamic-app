import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/utils/geo.dart';
import 'package:islamic_app/features/prayer_times/domain/nearby_mosque.dart';

/// Tahrir Square, Cairo — the point every distance below is measured from.
const double _lat = 30.0444;
const double _lon = 31.2357;

void main() {
  group('The query sent to Overpass', () {
    test('asks both ways a mosque is tagged', () {
      final query = MosqueSearch.query(latitude: _lat, longitude: _lon);

      // Most mosques carry the amenity pair; a good number carry only the
      // building tag. Asking for one of them alone loses the other.
      expect(query, contains('"amenity"="place_of_worship"'));
      expect(query, contains('"religion"="muslim"'));
      expect(query, contains('"building"="mosque"'));
    });

    test('asks for tags and centres, not member nodes', () {
      // `out center` also returns the node list of every way, which is a
      // quarter of the payload and of no use to a list of distances.
      final query = MosqueSearch.query(latitude: _lat, longitude: _lon);
      expect(query, contains('out tags center;'));
    });

    test('carries no result cap', () {
      // Overpass applies `out … 200` in element-id order, not by distance, so
      // a cap can drop the mosque you are standing next to.
      final query = MosqueSearch.query(
        latitude: _lat,
        longitude: _lon,
        radiusMetres: 10000,
      );
      expect(RegExp(r'out tags center \d+;').hasMatch(query), isFalse);
    });

    test('a wild radius is brought back into range', () {
      expect(
        MosqueSearch.query(latitude: _lat, longitude: _lon, radiusMetres: 5),
        contains('around:200,'),
      );
      expect(
        MosqueSearch.query(
          latitude: _lat,
          longitude: _lon,
          radiusMetres: 9999999,
        ),
        contains('around:20000,'),
      );
    });

    test('coordinates are trimmed to what a phone actually knows', () {
      final query = MosqueSearch.query(
        latitude: 30.044412345678,
        longitude: 31.235700000001,
      );
      expect(query, contains('30.044412,31.235700'));
    });
  });

  group('Reading a real Overpass answer', () {
    // Taken verbatim from what overpass-api.de returned for the query above,
    // so a change in its shape fails here rather than on someone's phone.
    final answer = <String, dynamic>{
      'version': 0.6,
      'elements': [
        {
          'type': 'node',
          'id': 329979223,
          'lat': 30.0391655,
          'lon': 31.2608856,
          'tags': {
            'amenity': 'place_of_worship',
            'name': 'مسجد السيدة فاطمة النبوية',
            'name:ar': 'مسجد السيدة فاطمة النبوية',
            'name:en': 'Al-Sayyeda Fatema Al-Nabaweya Mosque',
            'religion': 'muslim',
          },
        },
        {
          'type': 'way',
          'id': 24748791,
          'center': {'lat': 30.0478438, 'lon': 31.2632106},
          'tags': {
            'amenity': 'place_of_worship',
            'building': 'yes',
            'name': 'مسجد الحسين',
            'name:ar': 'مسجد الحسين',
            'name:en': 'Hussein Mosque',
            'religion': 'muslim',
          },
        },
        {
          'type': 'node',
          'id': 1152871135,
          'lat': 30.0244724,
          'lon': 31.2393512,
          'tags': {'amenity': 'place_of_worship', 'religion': 'muslim'},
        },
      ],
    };

    test('a way is placed at the centre Overpass computed for it', () {
      final mosques = MosqueSearch.parse(
        answer,
        latitude: _lat,
        longitude: _lon,
      );

      final hussein = mosques.firstWhere((m) => m.osmId == 24748791);
      expect(hussein.osmType, 'way');
      expect(hussein.latitude, closeTo(30.0478438, 0.000001));
      expect(hussein.longitude, closeTo(31.2632106, 0.000001));
    });

    test('the list comes back nearest first', () {
      final mosques = MosqueSearch.parse(
        answer,
        latitude: _lat,
        longitude: _lon,
      );

      for (var i = 1; i < mosques.length; i++) {
        expect(
          mosques[i].distanceMetres,
          greaterThanOrEqualTo(mosques[i - 1].distanceMetres),
        );
      }
    });

    test('an unnamed mosque is kept, not dropped', () {
      // About a quarter of the mosques in a dense city have no name, and one
      // of them is regularly the nearest. Dropping it to keep the list tidy
      // would be hiding the answer to the question being asked.
      final mosques = MosqueSearch.parse(
        answer,
        latitude: _lat,
        longitude: _lon,
      );

      final unnamed = mosques.firstWhere((m) => m.osmId == 1152871135);
      expect(unnamed.hasName, isFalse);
      expect(unnamed.displayName('ar'), isEmpty);
      expect(mosques.length, 3);
    });

    test('Arabic and English readers get the name each can read', () {
      final mosques = MosqueSearch.parse(
        answer,
        latitude: _lat,
        longitude: _lon,
      );
      final hussein = mosques.firstWhere((m) => m.osmId == 24748791);

      expect(hussein.displayName('ar'), 'مسجد الحسين');
      expect(hussein.displayName('en'), 'Hussein Mosque');
    });

    test('distances match the real ones to within a few metres', () {
      final mosques = MosqueSearch.parse(
        answer,
        latitude: _lat,
        longitude: _lon,
      );
      final hussein = mosques.firstWhere((m) => m.osmId == 24748791);

      // Al-Hussein Mosque is a little over 2.7 km from Tahrir Square.
      expect(hussein.distanceMetres, closeTo(2700, 150));
    });
  });

  group('What is not a mosque any more', () {
    List<NearbyMosque> parseOne(Map<String, String> tags) => MosqueSearch.parse(
      {
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': _lat + 0.001,
            'lon': _lon,
            'tags': tags,
          },
        ],
      },
      latitude: _lat,
      longitude: _lon,
    );

    test('a disused building is left out', () {
      expect(
        parseOne({'building': 'mosque', 'disused:amenity': 'place_of_worship'}),
        isEmpty,
      );
    });

    test('an abandoned or former one is left out', () {
      expect(
        parseOne({'building': 'mosque', 'abandoned:amenity': 'x'}),
        isEmpty,
      );
      expect(parseOne({'building': 'mosque', 'was:amenity': 'x'}), isEmpty);
    });

    test('a mosque turned museum is left out', () {
      // Nobody hurrying to pray wants to be sent to a ticket desk.
      expect(parseOne({'building': 'mosque', 'tourism': 'museum'}), isEmpty);
    });

    test('a place of worship of another religion is left out', () {
      expect(
        parseOne({'amenity': 'place_of_worship', 'religion': 'christian'}),
        isEmpty,
      );
    });

    test('a mosque with no religion tag is kept', () {
      // The second branch of the query exists precisely for these.
      expect(parseOne({'building': 'mosque'}), hasLength(1));
    });

    test('a prayer room is kept, and marked as one', () {
      final found = parseOne({
        'amenity': 'place_of_worship',
        'religion': 'muslim',
        'place_of_worship': 'musalla',
      });
      expect(found.single.isMusalla, isTrue);
    });
  });

  group('Answers that cannot be read', () {
    test('an element with no coordinates is skipped, not guessed at', () {
      final mosques = MosqueSearch.parse(
        {
          'elements': [
            {
              'type': 'relation',
              'id': 7,
              'tags': {'building': 'mosque'},
            },
          ],
        },
        latitude: _lat,
        longitude: _lon,
      );
      expect(mosques, isEmpty);
    });

    test('a payload with no element list is refused', () {
      expect(
        () => MosqueSearch.parse(
          {'remark': 'runtime error'},
          latitude: _lat,
          longitude: _lon,
        ),
        throwsA(
          isA<MosqueLookupException>().having(
            (e) => e.reason,
            'reason',
            MosqueLookupFailure.unreadable,
          ),
        ),
      );
    });

    test('the same element twice is one mosque', () {
      final mosques = MosqueSearch.parse(
        {
          'elements': [
            for (var i = 0; i < 2; i++)
              {
                'type': 'node',
                'id': 42,
                'lat': _lat,
                'lon': _lon,
                'tags': {'building': 'mosque'},
              },
          ],
        },
        latitude: _lat,
        longitude: _lon,
      );
      expect(mosques, hasLength(1));
    });

    test('every reason has something to say', () {
      for (final reason in MosqueLookupFailure.values) {
        expect(
          MosqueLookupException(reason).messageKey,
          startsWith('mosques_'),
        );
      }
    });
  });

  group('Pointing the way', () {
    test('due north is north, and due east is east', () {
      expect(Geo.compassOctant(0), 0);
      expect(Geo.compassOctant(90), 2);
      expect(Geo.compassOctant(180), 4);
      expect(Geo.compassOctant(270), 6);
    });

    test('the boundaries land where a reader would expect', () {
      // 22.4 degrees is still north; 22.6 has tipped into north-east.
      expect(Geo.compassOctant(22.4), 0);
      expect(Geo.compassOctant(22.6), 1);
      expect(Geo.compassOctant(359), 0);
    });

    test('a bearing that wrapped past a full turn still reads', () {
      expect(Geo.compassOctant(365), 0);
      expect(Geo.compassOctant(-90), 6);
    });

    test('bearing from Cairo to Mecca is roughly south-east', () {
      // A known direction, so a sign error in the formula cannot pass.
      final bearing = Geo.bearingDegrees(30.0444, 31.2357, 21.4225, 39.8262);
      expect(bearing, closeTo(136, 3));
    });
  });

  group('Links out to a maps app', () {
    const mosque = NearbyMosque(
      osmType: 'node',
      osmId: 1,
      latitude: 30.05,
      longitude: 31.24,
      distanceMetres: 700,
      bearing: 45,
    );

    test('the geo link carries the point twice, so it is labelled', () {
      expect(mosque.geoUri.toString(), 'geo:30.05,31.24?q=30.05,31.24');
    });

    test('the fallback is a real page, not a dead end', () {
      expect(mosque.webMapUri.host, 'www.openstreetmap.org');
      expect(mosque.webMapUri.queryParameters['mlat'], '30.05');
    });

    test('directions start from where the user is standing', () {
      final uri = mosque.directionsUri(30.0444, 31.2357);
      expect(uri.queryParameters['origin'], '30.0444,31.2357');
      expect(uri.queryParameters['destination'], '30.05,31.24');
    });
  });

  group('A query that failed while answering 200', () {
    // Overpass reports a failed query as HTTP 200, an empty element list, and
    // a `remark`. Reading only the list turns "the query timed out" into
    // "there is no mosque near you" — the wrong answer wearing the clothes of
    // a right one. This is exactly what came back from a slow query around
    // Damanhour while this was being built.
    test('a timed-out query is busy, not an empty neighbourhood', () {
      expect(
        () => MosqueSearch.parse(
          {
            'version': 0.6,
            'elements': <dynamic>[],
            'remark':
                'runtime error: Query timed out in "query" at line 1 after '
                '56 seconds.',
          },
          latitude: _lat,
          longitude: _lon,
        ),
        throwsA(
          isA<MosqueLookupException>().having(
            (e) => e.reason,
            'reason',
            MosqueLookupFailure.busy,
          ),
        ),
      );
    });

    test('any other remark is refused rather than read as empty', () {
      expect(
        () => MosqueSearch.parse(
          {'elements': <dynamic>[], 'remark': 'runtime error: out of memory'},
          latitude: _lat,
          longitude: _lon,
        ),
        throwsA(isA<MosqueLookupException>()),
      );
    });

    test('a genuinely empty area is still allowed to be empty', () {
      // The distinction has to cut both ways: 25 km into the Western Desert
      // really does hold no mosque, and that answer must survive.
      expect(
        MosqueSearch.parse(
          {'version': 0.6, 'elements': <dynamic>[]},
          latitude: _lat,
          longitude: _lon,
        ),
        isEmpty,
      );
    });
  });

  group('Handing the search to a maps app', () {
    test('the point and the term both travel', () {
      final uri = MosqueSearch.mapsSearchUri(31.0345, 30.4676);
      expect(uri.scheme, 'geo');
      expect(uri.path, '31.0345,30.4676');
      expect(uri.queryParameters['q'], 'مسجد');
    });

    test('the term can follow the reader\'s language', () {
      final uri = MosqueSearch.mapsSearchUri(31.0, 30.0, term: 'mosque');
      expect(uri.queryParameters['q'], 'mosque');
    });

    test('the web fallback centres on the same point', () {
      final uri = MosqueSearch.webSearchUri(31.0345, 30.4676);
      expect(uri.host, 'www.google.com');
      expect(uri.toString(), contains('@31.0345,30.4676,15z'));
    });
  });

  group('How far the search reaches', () {
    test('it starts wide enough to find something in a thin city', () {
      // Three kilometres finds one mosque around Damanhour and none around
      // most of it; the first thing anyone does with an empty screen is widen
      // it, so it starts a step out.
      expect(MosqueSearch.defaultRadius, greaterThanOrEqualTo(5000));
      expect(MosqueSearch.radiusChoices, contains(MosqueSearch.defaultRadius));
    });

    test('the choices climb, and the widest is a real journey', () {
      for (var i = 1; i < MosqueSearch.radiusChoices.length; i++) {
        expect(
          MosqueSearch.radiusChoices[i],
          greaterThan(MosqueSearch.radiusChoices[i - 1]),
        );
      }
      expect(MosqueSearch.radiusChoices.last, greaterThanOrEqualTo(20000));
    });
  });
}
