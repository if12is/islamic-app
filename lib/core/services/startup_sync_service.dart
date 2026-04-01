import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../features/prayer_times/data/datasources/prayer_times_local_datasource.dart';
import '../../features/prayer_times/data/datasources/prayer_times_remote_datasource.dart';
import 'app_services.dart';
import 'azkar_data_service.dart';
import 'prayer_method_resolver.dart';
import 'quran_cache_service.dart';

/// Warms offline-first caches at app startup.
///
/// This runs in background to make first screen interactions faster and
/// keep core content available when offline.
class StartupSyncService {
  StartupSyncService._();

  static Future<void> warmCaches({
    required SharedPreferences prefs,
  }) async {
    await Future.wait([
      _warmAzkar(),
      _warmQuran(),
      _warmPrayerTimes(prefs: prefs),
    ]);
  }

  static Future<void> _warmAzkar() async {
    try {
      await AzkarDataService().loadAzkarData();
      print('✅ Startup sync: Azkar cache is ready');
    } catch (e) {
      print('⚠️ Startup sync: Azkar warm-up failed: $e');
    }
  }

  static Future<void> _warmQuran() async {
    try {
      final dio = AppServices.createDioClient();
      dio.options.baseUrl = AppConstants.quranApiBaseUrl;
      final cache = QuranCacheService();

      final chapters = await cache.getChapters(dio: dio);
      if (chapters.isNotEmpty) {
        final firstChapterId = (chapters.first['id'] as int?) ?? 1;
        await cache.getVerses(dio: dio, chapterId: firstChapterId);
      }

      print('✅ Startup sync: Quran cache is ready');
    } catch (e) {
      print('⚠️ Startup sync: Quran warm-up failed: $e');
    }
  }

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
        desiredAccuracy: LocationAccuracy.medium,
      );

      await prefs.setDouble(AppConstants.userLatitudeKey, position.latitude);
      await prefs.setDouble(AppConstants.userLongitudeKey, position.longitude);

      final savedMethod = prefs.getInt(AppConstants.prayerMethodKey) ?? 3;
      final resolvedMethod = await PrayerMethodResolver.resolveMethodFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        fallbackMethod: savedMethod,
      );

      final method = savedMethod == 3 ? resolvedMethod : savedMethod;
      if (method != savedMethod) {
        await prefs.setInt(AppConstants.prayerMethodKey, method);
      }

      final date = DateTime.now().toIso8601String().split('T').first;
      final remote = PrayerTimesRemoteDataSource(dio: AppServices.createDioClient());
      final local = PrayerTimesLocalDataSource();

      final prayerModel = await remote.getPrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
        method: method,
        date: date,
        location:
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      );

      await local.cachePrayerTimes(
        prayerTimes: prayerModel,
        latitude: position.latitude,
        longitude: position.longitude,
        method: method,
        date: date,
      );

      print('✅ Startup sync: Prayer cache is ready');
    } catch (e) {
      print('⚠️ Startup sync: Prayer warm-up failed: $e');
    }
  }
}
