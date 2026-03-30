import 'package:dartz/dartz.dart';
import '../../../../core/utils/failure.dart';
import '../entities/prayer_times_entity.dart';
import '../repositories/prayer_times_repository.dart';

/// Use case for fetching prayer times.
///
/// Encapsulates the business logic for retrieving prayer times for a given location.
/// This follows the Clean Architecture principle of separating business logic from
/// presentation and data layers.
class GetPrayerTimesUseCase {
  /// The prayer times repository
  final PrayerTimesRepository repository;

  /// Constructor
  GetPrayerTimesUseCase({required this.repository});

  /// Execute the use case.
  ///
  /// Parameters:
  /// - [latitude]: Geographic latitude of the location
  /// - [longitude]: Geographic longitude of the location
  /// - [method]: Prayer calculation method (default: 3 for Muslim World League)
  /// - [date]: Specific date in YYYY-MM-DD format (optional)
  ///
  /// Returns: Either a [Failure] or [PrayerTimesEntity]
  Future<Either<Failure, PrayerTimesEntity>> call({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  }) async {
    return await repository.getPrayerTimes(
      latitude: latitude,
      longitude: longitude,
      method: method,
      date: date,
    );
  }
}

/// Use case for getting cached prayer times.
///
/// Allows retrieving previously cached prayer times without network access.
class GetCachedPrayerTimesUseCase {
  /// The prayer times repository
  final PrayerTimesRepository repository;

  /// Constructor
  GetCachedPrayerTimesUseCase({required this.repository});

  /// Execute the use case.
  ///
  /// Returns: [PrayerTimesEntity] or null if no cache exists
  Future<PrayerTimesEntity?> call() async {
    return await repository.getCachedPrayerTimes();
  }
}
