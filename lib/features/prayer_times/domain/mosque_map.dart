/// The embedded Google map that shows what OpenStreetMap has not been given.
///
/// OpenStreetMap is drawn by volunteers, and ten kilometres around the centre
/// of Damanhour — a city of a quarter of a million — holds exactly one mapped
/// mosque, while a phone's own maps app lists eight within five. No amount of
/// tuning an Overpass query fixes an absence in the data, so the map beside
/// the list comes from Google instead.
///
/// The Maps Embed API is the one piece of Google Maps Platform that is free
/// with no request cap at all — and that is the whole reason it is the piece
/// used here. Everything else is billed: Nearby Search is $32 per thousand
/// calls after five thousand a month, which for an app anyone can install is a
/// bill with no ceiling on it.
///
/// It also settles the key problem. A key inside a published APK can be pulled
/// out of it, and a Places key cannot be restricted to one Android app — the
/// web services accept only IP restrictions, which a phone cannot satisfy. A
/// key restricted to the Embed API alone is different: extracting it buys the
/// finder nothing, because what it unlocks is free and uncapped. The
/// restriction is what makes that true, so the app says out loud that it must
/// be set.
class MosqueMap {
  MosqueMap._();

  /// Supplied at build time, never committed.
  ///
  /// `--dart-define=MAPS_EMBED_KEY=…`, from a repository secret in CI. Absent
  /// by default, and everything below degrades to the list and the handoff
  /// rather than showing a broken frame.
  static const String key = String.fromEnvironment('MAPS_EMBED_KEY');

  static bool get isConfigured => key.isNotEmpty;

  /// The one Google Cloud setting that has to be right.
  static const String restrictionNote = 'Maps Embed API';

  /// A map centred on the user, searching for mosques around them.
  ///
  /// `search` mode rather than `place` or `view`: it is the only one that
  /// drops a pin on every match, which is the entire point.
  static Uri searchUri({
    required double latitude,
    required double longitude,
    String term = 'مسجد',
    int zoom = 14,
    String language = 'ar',
  }) {
    return Uri.https('www.google.com', '/maps/embed/v1/search', {
      'key': key,
      'q': term,
      'center': '$latitude,$longitude',
      'zoom': '$zoom',
      'language': language,
      // Place names and addresses come back in the conventions of this region
      // rather than the caller's, which is what someone reading them locally
      // expects to see.
      'region': 'EG',
    });
  }

  /// Zoom that roughly matches a search radius, so the map opens showing the
  /// same ground the list was gathered from.
  ///
  /// Each zoom level halves the ground covered, so this steps by one for each
  /// doubling of the radius rather than interpolating something smoother that
  /// would only ever land between two levels.
  static int zoomForRadius(int metres) {
    if (metres <= 1000) return 15;
    if (metres <= 3000) return 14;
    if (metres <= 5000) return 13;
    if (metres <= 10000) return 12;
    return 11;
  }

  /// The frame the WebView loads.
  ///
  /// An iframe rather than the URL directly: loading the embed as the page
  /// itself leaves it sized to whatever the WebView guesses, and Google's
  /// frame wants a parent that has told it how big it is.
  static String html({
    required double latitude,
    required double longitude,
    required int radiusMetres,
    String term = 'مسجد',
    String language = 'ar',
  }) {
    final src =
        searchUri(
          latitude: latitude,
          longitude: longitude,
          term: term,
          zoom: zoomForRadius(radiusMetres),
          language: language,
        ).toString();

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; background: transparent; }
  iframe { border: 0; width: 100%; height: 100%; display: block; }
</style>
</head>
<body>
<iframe src="$src" allowfullscreen loading="eager" referrerpolicy="no-referrer-when-downgrade"></iframe>
</body>
</html>
''';
  }
}
