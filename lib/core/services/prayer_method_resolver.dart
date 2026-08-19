import 'package:geocoding/geocoding.dart';

/// Resolves a recommended prayer calculation method based on country.
class PrayerMethodResolver {
  PrayerMethodResolver._();

  static const Map<String, int> _countryMethodMap = {
    'SA': 4, // Umm al-Qura
    'AE': 4,
    'QA': 4,
    'KW': 4,
    'EG': 5, // Egyptian Authority
    'JO': 5,
    'PS': 5,
    'LB': 5,
    'SY': 5,
    'IQ': 5,
    'MA': 5,
    'TN': 5,
    'DZ': 5,
    'LY': 5,
    'TR': 3, // Muslim World League
    'GB': 2, // ISNA-style commonly used by communities/apps
    'US': 2,
    'CA': 2,
  };

  static Future<int> resolveMethodFromCoordinates({
    required double latitude,
    required double longitude,
    int fallbackMethod = 3,
  }) async {
    try {
      final placemarks =
          await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return fallbackMethod;
      }

      final countryCode = placemarks.first.isoCountryCode?.toUpperCase();
      if (countryCode == null) {
        return fallbackMethod;
      }

      return _countryMethodMap[countryCode] ?? fallbackMethod;
    } catch (_) {
      return fallbackMethod;
    }
  }
}
