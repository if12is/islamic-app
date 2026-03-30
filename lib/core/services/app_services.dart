import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'notification_service.dart';

/// Service for initializing and managing application services.
///
/// Handles initialization of:
/// - Hive (local database)
/// - Dio (HTTP client)
/// - Other dependencies
class AppServices {
  /// Initialize all app services.
  ///
  /// This should be called during app startup, typically in main() before runApp().
  /// Sets up Hive for local storage and other essential services.
  static Future<void> initialize() async {
    // Initialize Hive for local storage
    await Hive.initFlutter();

    // Initialize local notifications framework
    await NotificationService.initialize();
    
    print('✅ Hive initialized');
    print('✅ Notifications initialized');
    print('✅ App services initialized');
  }

  /// Get a configured Dio instance for API calls.
  ///
  /// Returns a Dio instance with proper timeouts and interceptors configured.
  static Dio createDioClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
  }

  /// Close all services and clean up resources.
  ///
  /// Should be called when the app is shutting down.
  static Future<void> dispose() async {
    // Close all Hive boxes
    await Hive.close();
    print('✅ App services disposed');
  }
}
