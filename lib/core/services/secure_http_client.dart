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
    // The Warsh mushaf, and every other riwayah whose text the reader can be
    // shown. Answers 200 directly with no redirect, so it needs no exception
    // to the rule below.
    'api.quranpedia.net',
    // The `www` matters: the bare domain answers 301, and this client does not
    // follow redirects, so mp3quran.net would be rejected as a bad response.
    'www.mp3quran.net',
    // The Internet Archive's metadata API, which lists the files of the
    // curated rare recitations and Taraweeh collections. Answers 200 with no
    // redirect. The audio itself streams through the player, not this client,
    // from storage nodes the download path redirects to.
    'archive.org',
    // OpenStreetMap's query endpoint, for finding the nearest mosques. Only
    // this one mirror: the alternatives that answer are hosted elsewhere
    // again, and a search sends the user's coordinates — so the fewer places
    // they go, the better. A busy server is reported as busy instead.
    'overpass-api.de',
    // Al-Madina newspaper, which reposts the Haramain weekly imams
    // announcement as plain text (its sitemaps and AMP article pages). The
    // `www` matters: the bare domain answers 301, which this client does not
    // follow. Nothing about the user is sent, only a GET for a public page.
    'www.al-madina.com',
  };

  /// Hosts allowed by their ending, where the exact name cannot be known.
  ///
  /// Only the Internet Archive's storage nodes. A download from
  /// `archive.org/download/…` answers 302 to whichever node holds the file —
  /// `ia801004.us.archive.org` or `dn720003.ca.archive.org` today, another
  /// tomorrow — so a fixed name would break the first time the archive moved
  /// an item. Every name under these endings belongs to the archive.
  static const Set<String> allowedHostSuffixes = {
    '.us.archive.org',
    '.ca.archive.org',
  };

  static bool isAllowedHost(String host) =>
      allowedHosts.contains(host) ||
      allowedHostSuffixes.any((suffix) => host.endsWith(suffix));

  /// The bytes at [url], following at most [maxRedirects] redirects — each
  /// one checked against the same rules as the first request.
  ///
  /// The client itself follows none, so that a redirect cannot carry a
  /// request somewhere the allowlist never agreed to. Following them here,
  /// one at a time and through the guard, keeps that promise while letting a
  /// download reach the node the archive sends it to.
  static Future<List<int>> getBytes(
    String url, {
    int maxRedirects = 3,
    Duration receiveTimeout = const Duration(seconds: 60),
  }) async {
    final dio = create();
    var target = Uri.parse(url);
    for (var hop = 0; hop <= maxRedirects; hop++) {
      final response = await dio.getUri<List<int>>(
        target,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
          headers: const {'Accept': '*/*'},
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null) {
          break;
        }
        target = target.resolve(location);
        continue;
      }
      return response.data ?? const [];
    }
    throw DioException(
      requestOptions: RequestOptions(path: url),
      type: DioExceptionType.badResponse,
      message: 'Too many redirects',
    );
  }

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
          if (!isAllowedHost(uri.host)) {
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
