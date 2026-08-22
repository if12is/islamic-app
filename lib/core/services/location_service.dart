import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/app_logger.dart';
import 'nearest_city_service.dart';

/// A place the user can pick.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

/// Turns coordinates into a place name, and a typed name into coordinates.
///
/// Two numbers tell nobody where they are. Every screen that shows a location
/// shows the name; the coordinates stay under the hood.
class LocationService {
  LocationService._();

  /// Whether the user pinned a place instead of following GPS.
  static const String manualKey = 'location_is_manual';

  static Future<bool> isManual([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return prefs.getBool(manualKey) ?? false;
  }

  /// Cached label, or an empty string when nothing is known yet.
  static Future<String> savedLabel([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userCityKey) ?? '';
  }

  /// Forget the cached name, so the next lookup describes the new place.
  ///
  /// Moving without this leaves the old city on screen next to the new city's
  /// prayer times, which is worse than showing neither.
  static Future<void> clearLabel([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userCityKey);
  }

  /// Name a point: nearest bundled city first, platform geocoder second.
  ///
  /// The bundled table wins because it is the only one that always answers —
  /// offline, on the web, and on devices with no geocoding backend — and
  /// because it answers at city level. A street name is not what someone
  /// checking prayer times wants to read; "دمنهور، البحيرة، مصر" is.
  static Future<String> describe({
    required double latitude,
    required double longitude,
    String languageCode = 'ar',
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();

    await NearestCityService.ensureLoaded();
    final city = NearestCityService.nearest(latitude, longitude);
    if (city != null) {
      final label = city.label(languageCode);
      await prefs.setString(AppConstants.userCityKey, label);
      return label;
    }

    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final label = _labelFor(placemarks.first);
        if (label.isNotEmpty) {
          await prefs.setString(AppConstants.userCityKey, label);
          return label;
        }
      }
    } catch (e) {
      AppLogger.warning('Reverse geocoding failed: $e');
    }

    return prefs.getString(AppConstants.userCityKey) ?? '';
  }

  /// Look up a place by name — bundled table first, network as a top-up.
  static Future<List<PlaceSuggestion>> search(
    String query, {
    String languageCode = 'ar',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const [];
    }

    await NearestCityService.ensureLoaded();
    final offline = [
      for (final city in NearestCityService.search(trimmed))
        PlaceSuggestion(
          label: city.label(languageCode),
          latitude: city.latitude,
          longitude: city.longitude,
        ),
    ];
    if (offline.length >= 5) {
      return offline;
    }

    try {
      final locations = await Geocoding().locationFromAddress(trimmed);
      final suggestions = <PlaceSuggestion>[];

      for (final location in locations.take(5)) {
        var label = trimmed;
        try {
          final placemarks = await Geocoding().placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );
          if (placemarks.isNotEmpty) {
            final resolved = _labelFor(placemarks.first);
            if (resolved.isNotEmpty) {
              label = resolved;
            }
          }
        } catch (_) {
          // Keep the typed name if the reverse lookup fails.
        }

        suggestions.add(
          PlaceSuggestion(
            label: label,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        );
      }
      return [...offline, ...suggestions];
    } catch (e) {
      AppLogger.warning('Place search failed: $e');
      return offline;
    }
  }

  /// Pin a place: prayer times and the qibla use it until GPS is re-enabled.
  static Future<void> saveManual(
    PlaceSuggestion place, {
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(manualKey, true);
    await prefs.setDouble(AppConstants.userLatitudeKey, place.latitude);
    await prefs.setDouble(AppConstants.userLongitudeKey, place.longitude);
    await prefs.setString(AppConstants.userCityKey, place.label);
  }

  /// Go back to following the device location.
  static Future<void> useAutomatic([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(manualKey, false);
  }

  /// "Mansoura, Egypt" — the most specific parts that exist.
  static String _labelFor(Placemark placemark) {
    final parts = <String>[
      if ((placemark.locality ?? '').isNotEmpty) placemark.locality!,
      if ((placemark.locality ?? '').isEmpty &&
          (placemark.subAdministrativeArea ?? '').isNotEmpty)
        placemark.subAdministrativeArea!,
      if ((placemark.administrativeArea ?? '').isNotEmpty &&
          placemark.administrativeArea != placemark.locality)
        placemark.administrativeArea!,
      if ((placemark.country ?? '').isNotEmpty) placemark.country!,
    ];

    return parts.take(2).join('، ');
  }
}
