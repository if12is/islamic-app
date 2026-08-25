import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/prayer_times/domain/mosque_map.dart';

/// Damanhour — the city that showed the gap this map exists to cover.
const double _lat = 31.034573;
const double _lon = 30.467686;

void main() {
  group('Nothing is built without a key', () {
    test('the key is absent unless it was supplied at build time', () {
      // No --dart-define in a plain `flutter test` run, which is exactly the
      // state a fork with no Google account builds in.
      expect(MosqueMap.key, isEmpty);
      expect(MosqueMap.isConfigured, isFalse);
    });
  });

  group('The address the frame loads', () {
    Uri uri({String term = 'مسجد', int zoom = 14, String language = 'ar'}) =>
        MosqueMap.searchUri(
          latitude: _lat,
          longitude: _lon,
          term: term,
          zoom: zoom,
          language: language,
        );

    test('it is the Embed API, which is the free one', () {
      // The whole reason this is Embed and not Places: Nearby Search bills
      // $32 per thousand calls past five thousand a month, and an app anyone
      // can install has no ceiling on how many that is.
      expect(uri().host, 'www.google.com');
      expect(uri().path, '/maps/embed/v1/search');
    });

    test('search mode, because it is the only one that pins every match', () {
      expect(uri().path, endsWith('/search'));
    });

    test('the point, the term and the zoom all travel', () {
      final query = uri(zoom: 13).queryParameters;
      expect(query['center'], '$_lat,$_lon');
      expect(query['q'], 'مسجد');
      expect(query['zoom'], '13');
    });

    test('the term and the labels follow the reader', () {
      final english = uri(term: 'mosque', language: 'en').queryParameters;
      expect(english['q'], 'mosque');
      expect(english['language'], 'en');
    });

    test('Arabic in the query is encoded, not dropped', () {
      expect(uri().toString(), contains('q=%D9%85%D8%B3%D8%AC%D8%AF'));
    });
  });

  group('Opening on the ground the list covers', () {
    test('a wider search opens zoomed further out', () {
      var previous = 99;
      for (final metres in [1000, 3000, 5000, 10000, 20000]) {
        final zoom = MosqueMap.zoomForRadius(metres);
        expect(
          zoom,
          lessThan(previous),
          reason: '$metres should be no closer in than the radius below it',
        );
        previous = zoom;
      }
    });

    test('every zoom stays inside what the embed accepts', () {
      for (final metres in [500, 1000, 3000, 5000, 10000, 20000, 100000]) {
        final zoom = MosqueMap.zoomForRadius(metres);
        expect(zoom, inInclusiveRange(0, 21), reason: '$metres');
      }
    });
  });

  group('The frame itself', () {
    String page() =>
        MosqueMap.html(latitude: _lat, longitude: _lon, radiusMetres: 5000);

    test('it is an iframe with a parent that has given it a size', () {
      // Loading the embed as the page itself leaves it sized to whatever the
      // WebView guesses, and Google's frame wants to be told.
      expect(page(), contains('<iframe'));
      expect(page(), contains('height: 100%'));
    });

    test('it carries the search address', () {
      expect(page(), contains('/maps/embed/v1/search'));
      expect(page(), contains('center=$_lat%2C$_lon'));
    });

    test('it does not scroll inside its own box', () {
      // The page is the map; a scrollbar in it would fight the list outside.
      expect(page(), contains('overflow: hidden'));
    });
  });
}
