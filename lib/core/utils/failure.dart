/// Base class for all failures/errors in the application.
/// 
/// This class represents an error state in the application.
/// All specific failure types should extend this class.
abstract class Failure {
  /// Error message
  final String? message;
  
  /// Stack trace for debugging
  final String? stackTrace;

  Failure({
    this.message,
    this.stackTrace,
  });
}

/// Failure for network-related errors.
class NetworkFailure extends Failure {
  NetworkFailure({
    String? message,
    String? stackTrace,
  }) : super(
    message: message ?? 'An error occurred with the network',
    stackTrace: stackTrace,
  );
}

/// Failure for API/server-related errors.
class ServerFailure extends Failure {
  /// HTTP status code
  final int? statusCode;

  ServerFailure({
    String? message,
    String? stackTrace,
    this.statusCode,
  }) : super(
    message: message ?? 'An error occurred with the server',
    stackTrace: stackTrace,
  );
}

/// Failure for data parsing/serialization errors.
class DataFailure extends Failure {
  DataFailure({
    String? message,
    String? stackTrace,
  }) : super(
    message: message ?? 'An error occurred parsing data',
    stackTrace: stackTrace,
  );
}

/// Failure for cache-related errors.
class CacheFailure extends Failure {
  CacheFailure({
    String? message,
    String? stackTrace,
  }) : super(
    message: message ?? 'An error occurred with the cache',
    stackTrace: stackTrace,
  );
}

/// Failure when data is not found.
class NotFoundFailure extends Failure {
  NotFoundFailure({
    String? message,
    String? stackTrace,
  }) : super(
    message: message ?? 'Data not found',
    stackTrace: stackTrace,
  );
}

/// Generic/unknown failure.
class UnknownFailure extends Failure {
  UnknownFailure({
    String? message,
    String? stackTrace,
  }) : super(
    message: message ?? 'An unknown error occurred',
    stackTrace: stackTrace,
  );
}
