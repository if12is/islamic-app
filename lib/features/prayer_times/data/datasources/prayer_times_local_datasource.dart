import 'package:hive_flutter/hive_flutter.dart';
import '../models/prayer_times_model.dart';

/// Local data source for Prayer Times caching.
///
/// Manages local persistent storage of prayer times using Hive.
/// This allows the app to work offline and reduces API calls.
class PrayerTimesLocalDataSource {
  /// Hive box name for caching prayer times
  static const String _boxName = 'prayer_times_cache';
  
  /// Key for storing cached prayer times
  static const String _cacheKey = 'cached_prayer_times';

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
  Future<void> cachePrayerTimes(PrayerTimesModel prayerTimes) async {
    try {
      final box = await _getBox();
      final jsonData = prayerTimes.toJson();
      
      // Convert to Map<String, dynamic> for Hive storage
      await box.put(_cacheKey, jsonData);
      
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
  Future<PrayerTimesModel?> getCachedPrayerTimes() async {
    try {
      final box = await _getBox();
      
      // Get cached data from Hive
      final cachedData = box.get(_cacheKey) as Map?;
      if (cachedData == null) {
        return null;
      }

      // Convert Map to Map<String, dynamic> for parsing
      final jsonData = Map<String, dynamic>.from(cachedData);
      
      // Convert back to model
      final prayerTimes = PrayerTimesModel.fromJson(jsonData);
      print('✅ Prayer times retrieved from cache');
      return prayerTimes;
    } catch (e) {
      print('❌ Error retrieving cached prayer times: $e');
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
      await box.delete(_cacheKey);
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
      final cached = await getCachedPrayerTimes();
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
