import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logger. Debug-only verbose logs; never dumps response bodies.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 80,
      colors: false,
      printEmojis: false,
    ),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  static void debug(String message) {
    if (kReleaseMode) {
      return;
    }
    _logger.d(message);
  }

  static void info(String message) => _logger.i(message);

  static void warning(String message) => _logger.w(message);

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
