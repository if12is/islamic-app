import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// HTTPS-only Dio client with host allowlisting and safe logging.
class SecureHttpClient {
  SecureHttpClient._();

  static const Set<String> allowedHosts = {
    'api.aladhan.com',
    'api.quran.com',
    'api.alquran.cloud',
    'cdn.islamic.network',
    // Per-ayah recitation. The video exporter downloads each verse through
    // this client, so leaving it out breaks every export.
    'everyayah.com',
    'api.github.com',
    // The `www` matters: the bare domain answers 301, and this client does not
    // follow redirects, so mp3quran.net would be rejected as a bad response.
    'www.mp3quran.net',
  };

  static Dio create({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        followRedirects: false,
        maxRedirects: 0,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'AlFajrIslamicApp/1.0',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uri = options.uri;
          if (uri.scheme != 'https') {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                message: 'Blocked non-HTTPS request',
              ),
            );
          }
          if (!allowedHosts.contains(uri.host)) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                message: 'Blocked request to untrusted host',
              ),
            );
          }
          if (!kReleaseMode) {
            AppLogger.debug('HTTP ${options.method} ${uri.host}${uri.path}');
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          AppLogger.warning(
            'HTTP error ${error.type} ${error.requestOptions.uri.host}',
          );
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  static Dio forAladhan() => create(baseUrl: AppConstants.aladhanApiBaseUrl);

  static Dio forQuran() => create(baseUrl: AppConstants.quranApiBaseUrl);
}
