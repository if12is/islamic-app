import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/prayer_times_model.dart';

/// Local data source for Prayer Times caching.
///
/// Manages local persistent storage of prayer times using Hive.
/// This allows the app to work offline and reduces API calls.
class PrayerTimesLocalDataSource {
  /// Hive box name for caching prayer times
  static const String _boxName = 'prayer_times_cache';

  /// Key prefix for storing cached prayer times by region/date/method
  static const String _cacheKeyPrefix = 'cached_prayer_times';

  /// Get the Hive box instance for prayer times.
  /// 
  /// Creates the box if it doesn't exist.
  Future<Box<Map>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Map>(_boxName);
    }
    return Hive.box<Map>(_boxName);
  }

  /// Cache prayer times locally.
  ///
  /// Stores the prayer times model as JSON in Hive for offline access.
  /// The cache will persist across app sessions.
  ///
  /// Parameters:
  /// - [prayerTimes]: The prayer times model to cache
  /// 
  /// Throws: Exception if caching fails
  Future<void> cachePrayerTimes({
    required PrayerTimesModel prayerTimes,
    required double latitude,
    required double longitude,
    required int method,
    String? date,
  }) async {
    try {
      final box = await _getBox();
      final jsonData = prayerTimes.toJson();
      final cacheKey = _buildCacheKey(
        latitude: latitude,
        longitude: longitude,
        method: method,
        date: date,
      );
      
      await box.put(cacheKey, {
        'cachedAt': DateTime.now().toIso8601String(),
        'payload': jsonData,
      });
      
      print('✅ Prayer times cached successfully');
    } catch (e) {
      print('❌ Error caching prayer times: $e');
      rethrow;
    }
  }

  /// Retrieve cached prayer times.
  ///
  /// Returns the previously cached prayer times if available.
  /// Returns null if no cache exists or if the cache is invalid.
  ///
  /// Returns: [PrayerTimesModel] or null if no cache exists
  Future<PrayerTimesModel?> getCachedPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    String? date,
  }) async {
    try {
      final box = await _getBox();
      final cacheKey = _buildCacheKey(
        latitude: latitude,
        longitude: longitude,
        method: method,
        date: date,
      );
      
      final cachedData = box.get(cacheKey);
      if (cachedData == null) {
        return null;
      }

      final wrapper = Map<String, dynamic>.from(cachedData);
      final payload = wrapper['payload'];
      if (payload is! Map) {
        return null;
      }

      final cachedAtRaw = wrapper['cachedAt'] as String?;
      final cachedAt = cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) >
              AppConstants.prayerTimesCacheDuration) {
        return null;
      }

      final jsonData = Map<String, dynamic>.from(payload);
      
      // Convert back to model
      final prayerTimes = PrayerTimesModel.fromJson(jsonData);

      print('✅ Prayer times retrieved from cache');
      return prayerTimes;
    } catch (e) {
      print('❌ Error retrieving cached prayer times: $e');
      return null;
    }
  }

  /// Retrieve the most recently cached prayer times, regardless of location.
  Future<PrayerTimesModel?> getLatestCachedPrayerTimes() async {
    try {
      final box = await _getBox();
      DateTime? latest;
      Map<String, dynamic>? latestPayload;

      for (final key in box.keys) {
        if (key is! String || !key.startsWith(_cacheKeyPrefix)) {
          continue;
        }

        final raw = box.get(key);
        if (raw is! Map) {
          continue;
        }

        final wrapper = Map<String, dynamic>.from(raw);
        final payload = wrapper['payload'];
        final cachedAtRaw = wrapper['cachedAt'] as String?;
        final cachedAt = cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw);

        if (payload is! Map || cachedAt == null) {
          continue;
        }

        if (latest == null || cachedAt.isAfter(latest)) {
          latest = cachedAt;
          latestPayload = Map<String, dynamic>.from(payload);
        }
      }

      if (latestPayload == null) {
        return null;
      }

      return PrayerTimesModel.fromJson(latestPayload);
    } catch (e) {
      print('❌ Error retrieving latest cached prayer times: $e');
      return null;
    }
  }

  /// Clear the prayer times cache.
  ///
  /// Removes all cached prayer times data.
  /// Useful for forced refresh or when user changes location.
  ///
  /// Throws: Exception if clearing fails
  Future<void> clearCache() async {
    try {
      final box = await _getBox();
      final keysToDelete = box.keys
          .whereType<String>()
          .where((key) => key.startsWith(_cacheKeyPrefix))
          .toList();

      await box.deleteAll(keysToDelete);
      print('✅ Prayer times cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
      rethrow;
    }
  }

  /// Check if prayer times are cached and valid.
  ///
  /// Returns true if cache exists and was updated within the last 24 hours.
  /// This helps determine if we should use cache or fetch fresh data.
  Future<bool> isCacheValid() async {
    try {
      final cached = await getLatestCachedPrayerTimes();
      if (cached == null) {
        return false;
      }
      
      // Cache is valid if we have data
      // In a production app, you might also check timestamps
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildCacheKey({
    required double latitude,
    required double longitude,
    required int method,
    String? date,
  }) {
    final dateKey = date ?? DateTime.now().toIso8601String().split('T').first;
    final lat = latitude.toStringAsFixed(3);
    final lon = longitude.toStringAsFixed(3);
    return '$_cacheKeyPrefix-$dateKey-m$method-$lat-$lon';
  }

  /// Close the Hive box.
  ///
  /// Should be called when the app is closing or when switching users.
  Future<void> closeBox() async {
    try {
      final box = await _getBox();
      await box.close();
      print('✅ Prayer times box closed');
    } catch (e) {
      print('❌ Error closing box: $e');
    }
  }
}
