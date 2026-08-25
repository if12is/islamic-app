import '../../../core/utils/geo.dart';

/// A mosque as OpenStreetMap knows it, with how far away it is from you.
class NearbyMosque {
  const NearbyMosque({
    required this.osmType,
    required this.osmId,
    required this.latitude,
    required this.longitude,
    required this.distanceMetres,
    required this.bearing,
    this.nameAr = '',
    this.nameEn = '',
    this.nameAny = '',
    this.street = '',
    this.isMusalla = false,
  });

  /// `node`, `way`, or `relation` — half of the OSM identity.
  final String osmType;
  final int osmId;

  final double latitude;
  final double longitude;

  /// Straight-line distance from the searcher. Not walking distance: there is
  /// no routing here, and a river or a motorway can make the nearest mosque on
  /// this list the furthest one to actually reach.
  final double distanceMetres;

  /// Clockwise from north, so the list can point rather than only measure.
  final double bearing;

  final String nameAr;
  final String nameEn;

  /// Whatever `name` held, which is usually Arabic in Arabic-speaking places
  /// but is not promised to be.
  final String nameAny;

  final String street;

  /// A prayer room rather than a mosque — a mall musalla, an airport room.
  /// Worth telling apart: you can pray in one, but Friday prayer is not held.
  final bool isMusalla;

  /// A stable identity for caching and for de-duplicating across queries.
  String get key => '$osmType/$osmId';

  bool get hasName =>
      nameAr.isNotEmpty || nameEn.isNotEmpty || nameAny.isNotEmpty;

  /// The best name for this reader, or an empty string when OSM has none.
  ///
  /// About a quarter of the mosques in a dense city carry no name at all. An
  /// unnamed mosque is still a mosque — often the nearest one — so it is kept
  /// and the screen calls it what it is rather than dropping it.
  String displayName(String languageCode) {
    if (languageCode == 'ar') {
      if (nameAr.isNotEmpty) return nameAr;
      if (nameAny.isNotEmpty) return nameAny;
      return nameEn;
    }
    if (nameEn.isNotEmpty) return nameEn;
    if (nameAny.isNotEmpty) return nameAny;
    return nameAr;
  }

  /// A link every phone understands, whichever maps app is installed.
  ///
  /// `geo:` with a `q` label is the Android intent that opens the chooser.
  Uri get geoUri =>
      Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

  /// The fallback for a device with no app registered for `geo:`.
  Uri get webMapUri => Uri.parse(
    'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=18/$latitude/$longitude',
  );

  /// Directions from where the searcher is standing.
  Uri directionsUri(double fromLatitude, double fromLongitude) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$fromLatitude,$fromLongitude'
    '&destination=$latitude,$longitude'
    '&travelmode=walking',
  );
}

/// Why a search came back with nothing.
///
/// An empty area and an unanswered question look identical to the user unless
/// the difference is carried this far, and telling someone there is no mosque
/// nearby when the request never arrived is worse than saying nothing.
enum MosqueLookupFailure {
  /// The request never reached the server.
  offline,

  /// The server answered, but refused or timed out.
  ///
  /// Overpass allows two queries at a time per address and replies `504` with
  /// an HTML page when that is exceeded — so this covers both "too many at
  /// once" and a genuinely slow query.
  busy,

  /// Something came back that is not an Overpass answer.
  unreadable,
}

class MosqueLookupException implements Exception {
  const MosqueLookupException(this.reason, {this.detail});

  final MosqueLookupFailure reason;
  final String? detail;

  String get messageKey => switch (reason) {
    MosqueLookupFailure.offline => 'mosques_offline',
    MosqueLookupFailure.busy => 'mosques_busy',
    MosqueLookupFailure.unreadable => 'mosques_unreadable',
  };

  @override
  String toString() => 'MosqueLookupException(${reason.name}: $detail)';
}

/// Builds the Overpass query and reads its answer.
///
/// Kept free of any network code so the query text and the parsing can both be
/// tested without asking a public server for anything.
class MosqueSearch {
  MosqueSearch._();

  /// Hand the search itself to whichever maps app is installed.
  ///
  /// OpenStreetMap is drawn by volunteers, and outside the big cities it can
  /// be nearly empty: ten kilometres around the centre of Damanhour — a city
  /// of a quarter of a million people — holds exactly one mapped mosque, while
  /// a phone's own maps app lists eight within five. No amount of tuning the
  /// query fixes an absence in the data.
  ///
  /// So rather than pretend, this offers one tap to the place where the answer
  /// actually lives. `geo:` is the intent every maps app registers for, and a
  /// `q` alongside a point is a search near that point.
  static Uri mapsSearchUri(
    double latitude,
    double longitude, {
    String term = 'مسجد',
  }) => Uri.parse('geo:$latitude,$longitude?q=${Uri.encodeComponent(term)}');

  /// For a device with nothing registered for `geo:`.
  static Uri webSearchUri(
    double latitude,
    double longitude, {
    String term = 'مسجد',
  }) => Uri.parse(
    'https://www.google.com/maps/search/${Uri.encodeComponent(term)}/'
    '@$latitude,$longitude,15z',
  );

  /// Radii offered on screen, in metres.
  ///
  /// One query per search, not a loop that widens until it finds something:
  /// Overpass gives an address two slots and answers `504` past them, so a
  /// widening loop would rate-limit itself on the first empty result.
  static const List<int> radiusChoices = [1000, 3000, 5000, 10000, 20000];

  /// Five kilometres, not three.
  ///
  /// Three is plenty in a mapped city and finds nothing at all in an unmapped
  /// one, and the first thing someone does when a screen says "nothing here"
  /// is widen it — so it starts one step further out.
  static const int defaultRadius = 5000;

  /// A ceiling on what is drawn, not on what is asked for.
  ///
  /// The query is deliberately uncapped: an `out … 200` limit is applied by
  /// Overpass in element-id order, not by distance, so it can drop the very
  /// mosque you are standing next to. Ten kilometres around central Cairo —
  /// about the densest case there is — returns 378 mosques in 124 KB, which is
  /// cheap enough to sort here and show the nearest of.
  static const int maxShown = 60;

  /// Overpass QL for every mosque within [radiusMetres] of a point.
  ///
  /// Two branches because the tagging is not consistent: most mosques are
  /// `amenity=place_of_worship` + `religion=muslim`, but a good number carry
  /// only `building=mosque`. Overpass merges the union by element id, so a
  /// mosque matching both is returned once.
  ///
  /// `out tags center` rather than `out center`: it drops the member-node list
  /// from every way, which is a quarter of the payload and of no use here.
  static String query({
    required double latitude,
    required double longitude,
    int radiusMetres = defaultRadius,
  }) {
    final lat = _coordinate(latitude);
    final lon = _coordinate(longitude);
    final radius = radiusMetres.clamp(200, 20000);
    const around = 'around';

    return '[out:json][timeout:30];'
        '('
        'nwr["amenity"="place_of_worship"]["religion"="muslim"]($around:$radius,$lat,$lon);'
        'nwr["building"="mosque"]($around:$radius,$lat,$lon);'
        ');'
        'out tags center;';
  }

  /// Read an Overpass answer into mosques sorted by distance.
  ///
  /// Anything that cannot be placed on the map is dropped rather than guessed
  /// at: a mosque with no coordinates cannot be shown a distance to, and an
  /// entry saying "somewhere near you" is worse than one fewer entry.
  static List<NearbyMosque> parse(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
    int limit = maxShown,
  }) {
    // Overpass reports a failed query as HTTP 200, an empty element list, and
    // a `remark` explaining itself. Reading only the list turns "the query
    // timed out" into "there is no mosque near you" — a wrong answer wearing
    // the clothes of a right one, which is the exact failure this whole file
    // is written to avoid. Measured, not assumed: a slow query around
    // Damanhour came back this way, 200 and empty, with the reason in `remark`.
    final remark = json['remark'];
    if (remark is String && remark.isNotEmpty) {
      throw MosqueLookupException(
        remark.toLowerCase().contains('timed out')
            ? MosqueLookupFailure.busy
            : MosqueLookupFailure.unreadable,
        detail: remark,
      );
    }

    final elements = json['elements'];
    if (elements is! List) {
      throw const MosqueLookupException(MosqueLookupFailure.unreadable);
    }

    final found = <String, NearbyMosque>{};

    for (final raw in elements) {
      if (raw is! Map) {
        continue;
      }
      final element = Map<String, dynamic>.from(raw);
      final mosque = _read(element, latitude, longitude);
      if (mosque != null) {
        found[mosque.key] = mosque;
      }
    }

    final list =
        found.values.toList()
          ..sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));

    return list.length <= limit ? list : list.sublist(0, limit);
  }

  static NearbyMosque? _read(
    Map<String, dynamic> element,
    double latitude,
    double longitude,
  ) {
    final type = element['type'] as String? ?? '';
    final id = (element['id'] as num?)?.toInt();
    if (type.isEmpty || id == null) {
      return null;
    }

    // A node carries its own point; a way or relation carries the centre that
    // `out center` computed for it.
    double? lat = (element['lat'] as num?)?.toDouble();
    double? lon = (element['lon'] as num?)?.toDouble();
    final center = element['center'];
    if (center is Map) {
      lat ??= (center['lat'] as num?)?.toDouble();
      lon ??= (center['lon'] as num?)?.toDouble();
    }
    if (lat == null || lon == null) {
      return null;
    }

    final tags = <String, String>{};
    final rawTags = element['tags'];
    if (rawTags is Map) {
      for (final entry in rawTags.entries) {
        tags[entry.key.toString()] = entry.value.toString();
      }
    }

    if (!_isStillAMosque(tags)) {
      return null;
    }

    return NearbyMosque(
      osmType: type,
      osmId: id,
      latitude: lat,
      longitude: lon,
      distanceMetres: Geo.distanceMetres(latitude, longitude, lat, lon),
      bearing: Geo.bearingDegrees(latitude, longitude, lat, lon),
      nameAr: tags['name:ar'] ?? '',
      nameEn: tags['name:en'] ?? '',
      nameAny: tags['name'] ?? '',
      street: tags['addr:street'] ?? '',
      isMusalla:
          (tags['place_of_worship'] ?? '') == 'musalla' ||
          (tags['room'] ?? '') == 'prayer',
    );
  }

  /// Reject buildings that were mosques and are not any more.
  ///
  /// `disused:`, `abandoned:` and `was:` prefixes are how OSM records a place
  /// that has stopped being what it was. The server-side filter already misses
  /// most of these — a `disused:amenity` is not an `amenity` — but a building
  /// still tagged `building=mosque` slips through the second branch, and a
  /// mosque turned museum should not be sent someone hurrying to pray.
  static bool _isStillAMosque(Map<String, String> tags) {
    for (final key in tags.keys) {
      if (key.startsWith('disused:') ||
          key.startsWith('abandoned:') ||
          key.startsWith('was:')) {
        return false;
      }
    }
    if (tags['tourism'] == 'museum' || tags['amenity'] == 'museum') {
      return false;
    }
    // A place of worship that says which religion, and it is not this one.
    final religion = tags['religion'];
    if (religion != null && religion.isNotEmpty && religion != 'muslim') {
      return false;
    }
    return true;
  }

  /// Six decimal places is about a tenth of a metre — past the point where a
  /// phone's fix means anything, and it keeps the query text short.
  static String _coordinate(double value) => value.toStringAsFixed(6);
}
