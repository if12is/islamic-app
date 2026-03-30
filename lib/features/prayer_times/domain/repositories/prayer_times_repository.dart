import 'package:dartz/dartz.dart';
import '../../../../core/utils/failure.dart';
import '../entities/prayer_times_entity.dart';

/// Abstract repository for Prayer Times.
/// 
/// This interface defines all operations that can be performed to retrieve prayer times.
/// The actual implementation sits in the Data layer, following Clean Architecture principles.
abstract class PrayerTimesRepository {
  /// Fetch prayer times for a given location and date.
  /// 
  /// Parameters:
  /// - [latitude]: The latitude of the location
  /// - [longitude]: The longitude of the location
  /// - [method]: The prayer calculation method (default: 3 for Muslim World League)
  /// - [date]: The date in format YYYY-MM-DD (optional, defaults to today)
  /// 
  /// Returns:
  /// - Right([PrayerTimesEntity]) on success
  /// - Left([Failure]) on failure
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  });
  
  /// Get cached prayer times if available.
  /// 
  /// This method attempts to retrieve prayer times from local cache
  /// without making an API call. Returns null if no cache is available.
  Future<PrayerTimesEntity?> getCachedPrayerTimes();
}
