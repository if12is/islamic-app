import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../utils/app_logger.dart';
import 'prayer_calculation_service.dart';

/// Storage for the prayer calculation fine-tuning.
///
/// Kept out of Riverpod so the notification scheduler — which runs long before
/// any widget tree exists — reads exactly the same settings the screens show.
class PrayerSettingsStore {
  PrayerSettingsStore._();

  static PrayerCalculationSettings read(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.prayerCalculationSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const PrayerCalculationSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return PrayerCalculationSettings.fromJson(decoded);
      }
    } catch (e) {
      AppLogger.warning('Invalid prayer calculation settings: $e');
    }
    return const PrayerCalculationSettings();
  }

  static Future<void> write(
    SharedPreferences prefs,
    PrayerCalculationSettings settings,
  ) async {
    await prefs.setString(
      AppConstants.prayerCalculationSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
