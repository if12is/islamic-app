import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/prayer_times_model.dart';

/// Exception thrown when a remote API call fails.
class RemoteException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  RemoteException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'RemoteException: $message (Status: $statusCode)';
}

/// Remote data source for Prayer Times.
///
/// This class handles all API communication with the Aladhan Prayer Times API.
/// It encapsulates the HTTP logic and transforms API responses to models.
class PrayerTimesRemoteDataSource {
  /// Dio HTTP client instance
  final Dio _dio;

  /// Constructor
  /// 
  /// Creates a new instance with the provided Dio client.
  /// If no Dio instance is provided, a default one will be created.
  PrayerTimesRemoteDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.aladhanApiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                responseType: ResponseType.json,
              ),
            ) {
    // Ensure a base URL exists even when a preconfigured Dio instance is injected.
    if (_dio.options.baseUrl.isEmpty) {
      _dio.options.baseUrl = AppConstants.aladhanApiBaseUrl;
    }
    _setupInterceptors();
  }

  /// Setup Dio interceptors for logging and error handling.
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Log request
          print('📤 [API Request] ${options.method.toUpperCase()} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Log response
          print(
              '📥 [API Response] Status: ${response.statusCode} - ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          // Log error
          print(
              '❌ [API Error] ${error.type} - ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// Fetch prayer times for a given location.
  ///
  /// Parameters:
  /// - [latitude]: Geographic latitude of the location
  /// - [longitude]: Geographic longitude of the location
  /// - [method]: Prayer calculation method (default: 3 for Muslim World League)
  /// - [date]: Specific date in YYYY-MM-DD format (optional, defaults to today)
  /// - [location]: Human-readable location name
  ///
  /// Returns: [PrayerTimesModel] with parsed prayer times
  ///
  /// Throws: [RemoteException] on network or API errors
  Future<PrayerTimesModel> getPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    required String location,
    String? date,
  }) async {
    try {
      final dateKey = _resolveDatePath(date);

      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'latitude': latitude,
        'longitude': longitude,
        'method': method,
      };

      // Make API request
      final response = await _dio.get(
        '/timings/$dateKey',
        queryParameters: queryParams,
      );

      // Validate response status
      if (response.statusCode == null || response.statusCode! > 299) {
        throw RemoteException(
          message: 'API returned error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse response and check for success
      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        throw RemoteException(
          message: 'Invalid response format: null data',
          statusCode: response.statusCode,
        );
      }

      final code = data['code'] as int?;
      if (code != 200) {
        throw RemoteException(
          message: data['status'] as String? ??
              'API returned non-200 code: $code',
          statusCode: code,
        );
      }

      // Map API response to model
      final model = PrayerTimesModel.fromAladhanResponse(
        apiResponse: data,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );

      return model;
    } on RemoteException {
      rethrow;
    } on DioException catch (e) {
      String message;
      int? statusCode;

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message =
              'Connection timeout. Please check your internet connection.';
          break;

        case DioExceptionType.badResponse:
          statusCode = e.response?.statusCode;
          message =
              'Server error: ${e.response?.statusCode} - ${e.response?.statusMessage}';
          break;

        case DioExceptionType.connectionError:
          message = 'No internet connection. Please check your network.';
          break;

        case DioExceptionType.unknown:
          message = 'An unknown error occurred: ${e.message}';
          break;

        case DioExceptionType.badCertificate:
          message = 'SSL certificate error';
          break;

        case DioExceptionType.cancel:
          message = 'Request was cancelled';
          break;
      }

      throw RemoteException(
        message: message,
        statusCode: statusCode,
        originalError: e,
      );
    } catch (e) {
      throw RemoteException(
        message: 'Unexpected error: $e',
        originalError: e,
      );
    }
  }

  String _resolveDatePath(String? date) {
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        return _formatAsApiDate(parsed);
      }
      return date;
    }

    return _formatAsApiDate(DateTime.now());
  }

  String _formatAsApiDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }
}
