import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/geo.dart';
import '../../domain/nearby_mosque.dart';

/// One search, and what it was a search for.
class MosqueSearchResult {
  const MosqueSearchResult({
    required this.mosques,
    required this.latitude,
    required this.longitude,
    required this.radiusMetres,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final List<NearbyMosque> mosques;
  final double latitude;
  final double longitude;
  final int radiusMetres;
  final DateTime fetchedAt;

  /// Whether this came off the disk rather than the network, so the screen can
  /// say when the answer was gathered instead of implying it is live.
  final bool fromCache;
}

/// Finds mosques around a point, using OpenStreetMap through Overpass.
///
/// OSM is the only source for this that does not need an API key, a billing
/// account, or the user's location leaving for a company that sells it. What
/// it costs instead is politeness: the public endpoint gives one address two
/// query slots and answers `504` with an HTML page past them, so this asks
/// once per search — never in a loop that widens the radius until something
/// turns up — and keeps what it gets.
class MosqueFinder {
  MosqueFinder._();

  static const String host = 'overpass-api.de';
  static const String endpoint = 'https://overpass-api.de/api/interpreter';

  static const String cacheKey = 'mosques_last_search';

  /// Mosques do not move, and this is a fallback for a failed search rather
  /// than a substitute for one, so a week is not too long to keep an answer.
  static const Duration cacheLife = Duration(days: 7);

  /// How far the searcher may have moved before the cached answer stops being
  /// about where they are.
  static const double cacheRadiusMetres = 700;

  static Future<MosqueSearchResult> search({
    required double latitude,
    required double longitude,
    int radiusMetres = MosqueSearch.defaultRadius,
    Dio? client,
    SharedPreferences? preferences,
  }) async {
    final dio = client ?? SecureHttpClient.create();
    final query = MosqueSearch.query(
      latitude: latitude,
      longitude: longitude,
      radiusMetres: radiusMetres,
    );

    Response<dynamic> response;
    try {
      response = await dio.get<dynamic>(
        endpoint,
        queryParameters: {'data': query},
        options: Options(
          // Overpass answers a rate-limited or slow query with an HTML error
          // page, so this must not insist on JSON at the transport layer —
          // it would turn a readable "server busy" into a parse failure.
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
    } on DioException catch (e) {
      AppLogger.warning('Mosque search failed: ${e.type}');
      throw MosqueLookupException(_failureFor(e), detail: e.message);
    }

    final Map<String, dynamic> json;
    try {
      final body = response.data;
      json =
          body is String
              ? jsonDecode(body) as Map<String, dynamic>
              : Map<String, dynamic>.from(body as Map);
    } catch (e) {
      // An HTML body with a 200 is what a proxy or a captive portal returns.
      AppLogger.warning('Mosque search answer unreadable: $e');
      throw const MosqueLookupException(MosqueLookupFailure.unreadable);
    }

    final mosques = MosqueSearch.parse(
      json,
      latitude: latitude,
      longitude: longitude,
    );

    final result = MosqueSearchResult(
      mosques: mosques,
      latitude: latitude,
      longitude: longitude,
      radiusMetres: radiusMetres,
      fetchedAt: DateTime.now(),
    );

    await _store(result, preferences);
    return result;
  }

  /// Overpass says "too many at once" with a `504` and an HTML page, not a
  /// `429` and a JSON body, so a status-only reading would call that offline.
  static MosqueLookupFailure _failureFor(DioException error) {
    final status = error.response?.statusCode;
    if (status == 429 || status == 504 || status == 503) {
      return MosqueLookupFailure.busy;
    }
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return MosqueLookupFailure.busy;
    }
    if (status != null && status >= 400 && status < 500) {
      return MosqueLookupFailure.unreadable;
    }
    return MosqueLookupFailure.offline;
  }

  /// The last search, if it was near enough and recent enough to still answer
  /// the question being asked.
  ///
  /// The distances are recomputed from where the user is standing now rather
  /// than replayed from the cache, so a saved list stays honestly ordered even
  /// after walking a few streets.
  static Future<MosqueSearchResult?> cached({
    required double latitude,
    required double longitude,
    required int radiusMetres,
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedLat = (json['lat'] as num).toDouble();
      final savedLon = (json['lon'] as num).toDouble();
      final savedRadius = (json['radius'] as num).toInt();
      final at = DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num).toInt(),
      );

      if ((now ?? DateTime.now()).difference(at) > cacheLife) {
        return null;
      }
      // A wider search than the saved one would be answered short.
      if (savedRadius < radiusMetres) {
        return null;
      }
      final moved = Geo.distanceMetres(latitude, longitude, savedLat, savedLon);
      if (moved > cacheRadiusMetres) {
        return null;
      }

      final mosques = MosqueSearch.parse(
        {'elements': json['elements']},
        latitude: latitude,
        longitude: longitude,
      );
      // Trim to what the narrower request actually asked for, so switching to
      // a smaller radius does not keep showing the wider result.
      final within =
          mosques
              .where((mosque) => mosque.distanceMetres <= radiusMetres)
              .toList();

      return MosqueSearchResult(
        mosques: within,
        latitude: latitude,
        longitude: longitude,
        radiusMetres: radiusMetres,
        fetchedAt: at,
        fromCache: true,
      );
    } catch (e) {
      AppLogger.warning('Stored mosque search unreadable: $e');
      return null;
    }
  }

  static Future<void> _store(
    MosqueSearchResult result,
    SharedPreferences? preferences,
  ) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'lat': result.latitude,
          'lon': result.longitude,
          'radius': result.radiusMetres,
          'at': result.fetchedAt.millisecondsSinceEpoch,
          'elements': [
            for (final mosque in result.mosques)
              {
                'type': mosque.osmType,
                'id': mosque.osmId,
                'lat': mosque.latitude,
                'lon': mosque.longitude,
                'tags': {
                  if (mosque.nameAr.isNotEmpty) 'name:ar': mosque.nameAr,
                  if (mosque.nameEn.isNotEmpty) 'name:en': mosque.nameEn,
                  if (mosque.nameAny.isNotEmpty) 'name': mosque.nameAny,
                  if (mosque.street.isNotEmpty) 'addr:street': mosque.street,
                  if (mosque.isMusalla) 'place_of_worship': 'musalla',
                },
              },
          ],
        }),
      );
    } catch (e) {
      // A search that worked is not worth failing over a cache that did not.
      AppLogger.warning('Could not store the mosque search: $e');
    }
  }
}
