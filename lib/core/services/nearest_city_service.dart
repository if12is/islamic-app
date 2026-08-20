import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// A named place with coordinates.
class NearestCity {
  const NearestCity({
    required this.nameAr,
    required this.nameEn,
    required this.adminAr,
    required this.adminEn,
    required this.countryAr,
    required this.countryEn,
    required this.latitude,
    required this.longitude,
    required this.tier,
  });

  factory NearestCity.fromJson(Map<String, dynamic> json) => NearestCity(
    nameAr: json['ar'] as String? ?? '',
    nameEn: json['en'] as String? ?? '',
    adminAr: json['aAr'] as String? ?? '',
    adminEn: json['aEn'] as String? ?? '',
    countryAr: json['cAr'] as String? ?? '',
    countryEn: json['cEn'] as String? ?? '',
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    tier: json['t'] as int? ?? 0,
  );

  final String nameAr;
  final String nameEn;
  final String adminAr;
  final String adminEn;
  final String countryAr;
  final String countryEn;
  final double latitude;
  final double longitude;

  /// Coarse size, 0 (town) to 4 (metropolis).
  final int tier;

  /// "دمنهور، البحيرة، مصر" — city, governorate, country.
  String label(String languageCode) {
    final arabic = languageCode == 'ar';
    final parts = <String>[
      arabic ? nameAr : (nameEn.isEmpty ? nameAr : nameEn),
      if (arabic ? adminAr.isNotEmpty : adminEn.isNotEmpty)
        arabic ? adminAr : adminEn,
      arabic ? countryAr : (countryEn.isEmpty ? countryAr : countryEn),
    ];
    return parts.where((part) => part.isNotEmpty).join('، ');
  }
}

/// Names the user's place from a bundled table instead of the network.
///
/// A prayer app that cannot say where it is calculating for is asking to be
/// mistrusted, and the platform geocoder is exactly the part that is missing
/// offline, on the web, and on devices without Google services. So the table
/// ships with the app: ~3,500 cities across the Arab world and every place
/// with a sizeable Muslim community, each with its governorate and country.
class NearestCityService {
  NearestCityService._();

  static const String asset = 'assets/data/cities.json';

  /// Beyond this, the nearest name would be a lie rather than a location.
  static const double maxDistanceKm = 120;

  static List<NearestCity>? _cities;

  static bool get isLoaded => _cities != null;

  /// How many places the table holds.
  static int get count => _cities?.length ?? 0;

  static Future<void> ensureLoaded() async {
    if (_cities != null) {
      return;
    }
    try {
      final raw = await rootBundle.loadString(asset);
      final decoded = jsonDecode(raw) as List<dynamic>;
      _cities = [
        for (final entry in decoded)
          NearestCity.fromJson(entry as Map<String, dynamic>),
      ];
      AppLogger.debug('Loaded ${_cities!.length} cities');
    } catch (e, stack) {
      AppLogger.error('Could not load the city table', e, stack);
      _cities = const [];
    }
  }

  /// The best name for a point: nearest place, with big cities given a small
  /// head start so a suburb does not outrank the city it sits inside.
  static NearestCity? nearest(double latitude, double longitude) {
    final cities = _cities;
    if (cities == null || cities.isEmpty) {
      return null;
    }

    NearestCity? best;
    var bestScore = double.infinity;
    var bestDistance = double.infinity;

    for (final city in cities) {
      final distance = distanceKm(
        latitude,
        longitude,
        city.latitude,
        city.longitude,
      );
      final score = distance - city.tier * 3.0;
      if (score < bestScore) {
        best = city;
        bestScore = score;
        bestDistance = distance;
      }
    }

    return bestDistance <= maxDistanceKm ? best : null;
  }

  /// Offline place search, so pinning a city works with no network.
  static List<NearestCity> search(String query, {int limit = 12}) {
    final cities = _cities;
    final needle = _fold(query);
    if (cities == null || needle.length < 2) {
      return const [];
    }

    final starts = <NearestCity>[];
    final contains = <NearestCity>[];

    for (final city in cities) {
      final ar = _fold(city.nameAr);
      final en = _fold(city.nameEn);
      if (ar.startsWith(needle) || en.startsWith(needle)) {
        starts.add(city);
      } else if (ar.contains(needle) || en.contains(needle)) {
        contains.add(city);
      }
      if (starts.length >= limit) {
        break;
      }
    }

    final results = [...starts, ...contains];
    results.sort((a, b) => b.tier.compareTo(a.tier));
    return results.take(limit).toList();
  }

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Lowercase, and Arabic folded so "الاسكندريه" finds "الإسكندرية".
  static String _fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          buffer.write('ا');
        case 'ة':
          buffer.write('ه');
        case 'ى':
          buffer.write('ي');
        case 'ـ':
          break;
        default:
          if (rune < 0x064B || rune > 0x0652) {
            buffer.write(char);
          }
      }
    }
    return buffer.toString();
  }
}
