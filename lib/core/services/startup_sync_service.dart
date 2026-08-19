import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../features/prayer_times/data/datasources/prayer_times_calculator_datasource.dart';
import '../../features/prayer_times/data/datasources/prayer_times_local_datasource.dart';
import 'azkar_data_service.dart';
import 'notification_scheduler.dart';
import 'prayer_method_resolver.dart';
import '../utils/app_logger.dart';

/// Prepares offline data at app startup.
///
/// The Quran no longer appears here: its text ships with the app, so there is
/// nothing to download. What is left is refreshing the location-dependent
/// pieces — prayer times (calculated on device) and the notification schedule
/// that depends on them — plus the Azkar dataset.
class StartupSyncService {
  StartupSyncService._();

  static Future<void> warmCaches({required SharedPreferences prefs}) async {
    await Future.wait([_warmAzkar(), _warmPrayerTimes(prefs: prefs)]);

    // Re-arm reminders last, so they use the freshest location and method.
    await NotificationScheduler.refresh(preferences: prefs);
  }

  static Future<void> _warmAzkar() async {
    try {
      await AzkarDataService().loadAzkarData();
      AppLogger.info('Startup sync: Azkar cache is ready');
    } catch (e) {
      AppLogger.warning('Startup sync: Azkar warm-up failed: $e');
    }
  }

  /// Refresh the saved location and recompute today's prayer times locally.
  static Future<void> _warmPrayerTimes({
    required SharedPreferences prefs,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await prefs.setDouble(AppConstants.userLatitudeKey, position.latitude);
      await prefs.setDouble(AppConstants.userLongitudeKey, position.longitude);

      final savedMethod = prefs.getInt(AppConstants.prayerMethodKey) ?? 3;
      final resolvedMethod =
          await PrayerMethodResolver.resolveMethodFromCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
            fallbackMethod: savedMethod,
          );

      final method = savedMethod == 3 ? resolvedMethod : savedMethod;
      if (method != savedMethod) {
        await prefs.setInt(AppConstants.prayerMethodKey, method);
      }

      final date = DateTime.now().toIso8601String().split('T').first;

      // Calculated on device: no network call, works in airplane mode.
      const calculator = PrayerTimesCalculatorDataSource();
      final prayerModel = calculator.getPrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
        method: method,
        location:
            '${position.latitude.toStringAsFixed(4)}, '
            '${position.longitude.toStringAsFixed(4)}',
      );

      await PrayerTimesLocalDataSource().cachePrayerTimes(
        prayerTimes: prayerModel,
        latitude: position.latitude,
        longitude: position.longitude,
        method: method,
        date: date,
      );

      AppLogger.info('Startup sync: Prayer cache is ready');
    } catch (e) {
      AppLogger.warning('Startup sync: Prayer warm-up failed: $e');
    }
  }
}
