import 'package:dartz/dartz.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../datasources/prayer_times_local_datasource.dart';
import '../datasources/prayer_times_remote_datasource.dart';

/// Implementation of [PrayerTimesRepository].
///
/// This repository acts as a bridge between the data sources (remote API and local cache)
/// and the domain layer. It implements the core business logic for fetching prayer times,
/// including error handling, retry logic, and cache management.
class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  /// Remote API data source
  final PrayerTimesRemoteDataSource remoteDataSource;
  
  /// Local cache data source
  final PrayerTimesLocalDataSource localDataSource;

  /// Constructor
  PrayerTimesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Fetch prayer times, preferring fresh API data but using cache as fallback.
  ///
  /// This method implements a smart caching strategy:
  /// 1. Tries to get data from remote API first
  /// 2. If API fails and cache exists, uses cached data
  /// 3. If both fail, returns an error
  /// 4. After successful API call, updates the cache
  ///
  /// This ensures the app has the latest data while gracefully
  /// degrading to cached data if network is unavailable.
  @override
  Future<Either<Failure, PrayerTimesEntity>> getPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 3,
    String? date,
  }) async {
    try {
      // Attempt to fetch from remote API
      final remoteModel = await remoteDataSource.getPrayerTimes(
        latitude: latitude,
        longitude: longitude,
        method: method,
        location: _getLocationName(latitude, longitude),
        date: date,
      );

      // Cache the fresh data
      try {
        await localDataSource.cachePrayerTimes(
          prayerTimes: remoteModel,
          latitude: latitude,
          longitude: longitude,
          method: method,
          date: date,
        );
      } catch (e) {
        // Log cache error but don't fail the operation
        AppLogger.warning('Failed to cache prayer times: $e');
      }

      return Right(remoteModel);
    } on RemoteException catch (e) {
      // API call failed, try to use cache
      AppLogger.warning('API call failed: ${e.message}, attempting to use cache');
      
      try {
        final cachedData = await localDataSource.getCachedPrayerTimes(
          latitude: latitude,
          longitude: longitude,
          method: method,
          date: date,
        );
        
        if (cachedData != null) {
          AppLogger.info('Using cached prayer times');
          return Right(cachedData);
        }
      } catch (_) {
        // Cache retrieval also failed, continue to error handling
      }

      // No cache available, return the API error
      return Left(_mapRemoteExceptionToFailure(e));
    } catch (e) {
      // Unexpected error
      return Left(
        UnknownFailure(
          message: 'Unexpected error fetching prayer times: $e',
          stackTrace: e.toString(),
        ),
      );
    }
  }

  /// Get cached prayer times without making an API call.
  @override
  Future<PrayerTimesEntity?> getCachedPrayerTimes() async {
    try {
      return await localDataSource.getLatestCachedPrayerTimes();
    } catch (e) {
      AppLogger.warning('Error retrieving cached prayer times: $e');
      return null;
    }
  }

  /// Map [RemoteException] to domain [Failure].
  ///
  /// Converts the data layer exception to a domain-level failure,
  /// abstracting away HTTP details.
  Failure _mapRemoteExceptionToFailure(RemoteException exception) {
    if (exception.statusCode == null) {
      // Network error
      return NetworkFailure(
        message: exception.message,
        stackTrace: exception.originalError?.toString(),
      );
    } else if (exception.statusCode! >= 500) {
      // Server error
      return ServerFailure(
        message: exception.message,
        statusCode: exception.statusCode,
        stackTrace: exception.originalError?.toString(),
      );
    } else if (exception.statusCode! >= 400) {
      // Client error (4xx)
      if (exception.statusCode == 404) {
        return NotFoundFailure(
          message: exception.message,
          stackTrace: exception.originalError?.toString(),
        );
      }
      return ServerFailure(
        message: exception.message,
        statusCode: exception.statusCode,
        stackTrace: exception.originalError?.toString(),
      );
    } else {
      // Unknown error
      return UnknownFailure(
        message: exception.message,
        stackTrace: exception.originalError?.toString(),
      );
    }
  }

  /// Get a human-readable location name from coordinates.
  ///
  /// In a production app, this could use reverse geocoding.
  /// For now, it returns a formatted coordinate string.
  String _getLocationName(double latitude, double longitude) {
    return 'Location ($latitude, $longitude)';
  }
}
