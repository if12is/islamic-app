import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/app_logger.dart';
import 'notification_service.dart';
import 'secure_http_client.dart';

/// Service for initializing and managing application services.
class AppServices {
  /// Initialize all app services before runApp().
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await NotificationService.initialize();
    AppLogger.info('App services initialized');
  }

  /// HTTPS-only Dio client with host allowlisting.
  static Dio createDioClient({String? baseUrl}) {
    return SecureHttpClient.create(baseUrl: baseUrl);
  }

  static Future<void> dispose() async {
    await Hive.close();
    AppLogger.info('App services disposed');
  }
}
