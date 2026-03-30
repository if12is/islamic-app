import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/app_services.dart';
import '../../data/datasources/prayer_times_local_datasource.dart';
import '../../data/datasources/prayer_times_remote_datasource.dart';
import '../../data/repositories/prayer_times_repository_impl.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../../domain/repositories/prayer_times_repository.dart';
import '../../domain/usecases/get_prayer_times_usecase.dart';

// ========================
// Dio Provider
// ========================

/// Provides a configured Dio HTTP client instance.
final dioProvider = Provider<Dio>((ref) {
  return AppServices.createDioClient();
});

// ========================
// Data Source Providers
// ========================

/// Provides the remote data source for prayer times API calls.
final prayerTimesRemoteDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return PrayerTimesRemoteDataSource(dio: dio);
});

/// Provides the local data source for prayer times caching.
final prayerTimesLocalDataSourceProvider =
    Provider<PrayerTimesLocalDataSource>((ref) {
  return PrayerTimesLocalDataSource();
});

// ========================
// Repository Provider
// ========================

/// Provides the prayer times repository implementation.
/// 
/// Combines both remote and local data sources for smart caching.
final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  final remoteDataSource = ref.watch(prayerTimesRemoteDataSourceProvider);
  final localDataSource = ref.watch(prayerTimesLocalDataSourceProvider);

  return PrayerTimesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

// ========================
// Use Case Providers
// ========================

/// Provides the get prayer times use case.
final getPrayerTimesUseCaseProvider = Provider<GetPrayerTimesUseCase>((ref) {
  final repository = ref.watch(prayerTimesRepositoryProvider);
  return GetPrayerTimesUseCase(repository: repository);
});

/// Provides the get cached prayer times use case.
final getCachedPrayerTimesUseCaseProvider =
    Provider<GetCachedPrayerTimesUseCase>((ref) {
  final repository = ref.watch(prayerTimesRepositoryProvider);
  return GetCachedPrayerTimesUseCase(repository: repository);
});

// ========================
// State Management Providers
// ========================

/// State for prayer times async operation.
enum PrayerTimesAsyncState { idle, loading, success, error }

/// Riverpod parameter for prayer times request.
class PrayerTimesParams {
  final double latitude;
  final double longitude;
  final int method;
  final String? date;

  const PrayerTimesParams({
    required this.latitude,
    required this.longitude,
    this.method = 3,
    this.date,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is PrayerTimesParams &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.method == method &&
      other.date == date;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
      longitude.hashCode ^
      method.hashCode ^
      date.hashCode;
  }
}

/// Fetch prayer times with async state management.
///
/// Usage:
/// ```dart
/// final prayerTimes = ref.watch(
///   prayerTimesProvider(
///     PrayerTimesParams(latitude: 40.7128, longitude: -74.0060)
///   )
/// );
/// ```
final prayerTimesProvider =
  FutureProvider.family<PrayerTimesEntity, PrayerTimesParams>((ref, params) async {
  final useCase = ref.watch(getPrayerTimesUseCaseProvider);

  final result = await useCase(
    latitude: params.latitude,
    longitude: params.longitude,
    method: params.method,
    date: params.date,
  );

  return result.fold(
    (failure) => throw Exception(failure.message ?? 'Unknown error'),
    (prayerTimes) => prayerTimes,
  );
});

/// Get cached prayer times.
///
/// Returns cached prayer times without making an API call.
final cachedPrayerTimesProvider =
    FutureProvider<PrayerTimesEntity?>((ref) async {
  final useCase = ref.watch(getCachedPrayerTimesUseCaseProvider);
  return await useCase();
});
