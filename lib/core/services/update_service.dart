import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import 'delivery_check.dart';
import 'secure_http_client.dart';

/// A release published on GitHub.
class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.buildNumber,
    required this.notes,
    required this.pageUrl,
    required this.apkUrl,
    required this.apkBytes,
  });

  /// "1.0.1" — the marketing version.
  final String versionName;

  /// The versionCode. This, not [versionName], decides what is newer: CI
  /// takes it from the run number, so it only ever increases.
  final int buildNumber;

  final String notes;

  /// The release page, for anyone who would rather install by hand.
  final String pageUrl;

  /// The APK asset to fetch, if the release carries one.
  final String? apkUrl;

  /// Its size, so the download can be weighed before it starts.
  final int apkBytes;

  String get label =>
      buildNumber > 0 ? '$versionName ($buildNumber)' : versionName;
}

/// Why a check produced no answer.
enum UpdateCheckFailure {
  /// The request never reached GitHub.
  offline,

  /// GitHub answered, but refused — usually the unauthenticated hourly limit.
  rateLimited,

  /// GitHub answered, and there is no release to read.
  notFound,

  /// A release exists but carries no version anyone can compare.
  unreadable,
}

/// The check could not be completed.
///
/// This exists because the absence of an answer was being reported as an
/// answer: every failure returned null, and null was read as "nothing newer",
/// so a phone with no signal — or a repository that had briefly rate-limited
/// the request — was told it was up to date. Not knowing and knowing there is
/// nothing are different facts and the user is owed the difference.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.reason, {this.detail});

  final UpdateCheckFailure reason;
  final String? detail;

  /// What to say about it.
  String get messageKey => switch (reason) {
    UpdateCheckFailure.offline => 'update_check_offline',
    UpdateCheckFailure.rateLimited => 'update_check_rate_limited',
    UpdateCheckFailure.notFound => 'update_check_no_release',
    UpdateCheckFailure.unreadable => 'update_check_unreadable',
  };

  @override
  String toString() => 'UpdateCheckException(${reason.name}: $detail)';
}

/// Checks GitHub for a newer build and fetches it.
///
/// Play Store delta patches are not available for a sideloaded APK: the
/// installer needs a complete signed package. What we can save is the unused
/// CPUs — CI publishes one APK per ABI, and this picks the one that matches
/// the phone (typically a third of the fat 150 MB file).
class UpdateService {
  UpdateService._();

  static const String _owner = 'if12is';
  static const String _repo = 'islamic-app';
  static const String rollingTag = 'apk-latest';

  /// When the last check ran, so startup does not hit the network every launch.
  static const String lastCheckKey = 'update_last_check';

  /// A build the user asked not to be told about again.
  static const String skippedBuildKey = 'update_skipped_build';

  static const Duration checkInterval = Duration(hours: 12);

  static Future<int> currentBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<String> currentVersionName() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Ask GitHub what the newest release is.
  ///
  /// The rolling [rollingTag] release is what testers install from. GitHub's
  /// `/releases/latest` points at a kept versioned tag and is only a fallback.
  ///
  /// Throws [UpdateCheckException] when the check could not be completed.
  ///
  /// It never returns null on a failure. Reporting "nothing newer" for a
  /// request that never arrived is how a phone with no signal came to be told
  /// it was on the latest build for as long as it stayed offline.
  static Future<AppRelease?> fetchLatest({
    Dio? client,
    List<String>? preferredAbis,
  }) async {
    if (kIsWeb) {
      return null;
    }

    final abis = preferredAbis ?? await DeliveryCheck.deviceAbis();
    final dio = client ?? SecureHttpClient.create();

    // The rolling release is what testers install from; the kept versioned
    // tag is the fallback. Both are tried before giving up, and the first
    // failure is remembered so the message names what actually went wrong
    // rather than whatever the second attempt happened to hit.
    UpdateCheckException? firstFailure;

    for (final url in [
      'https://api.github.com/repos/$_owner/$_repo/releases/tags/$rollingTag',
      'https://api.github.com/repos/$_owner/$_repo/releases/latest',
    ]) {
      try {
        return await _fetchRelease(dio, url, abis);
      } on UpdateCheckException catch (e) {
        firstFailure ??= e;
      }
    }

    throw firstFailure ??
        const UpdateCheckException(UpdateCheckFailure.offline);
  }

  static Future<AppRelease> _fetchRelease(
    Dio dio,
    String url,
    List<String> abis,
  ) async {
    Response<dynamic> response;
    try {
      response = await dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
    } on DioException catch (e) {
      AppLogger.warning('Update check failed ($url): $e');
      throw UpdateCheckException(failureFor(e.response?.statusCode, e.type));
    } catch (e) {
      AppLogger.warning('Update check failed ($url): $e');
      throw UpdateCheckException(
        UpdateCheckFailure.offline,
        detail: e.toString(),
      );
    }

    try {
      final body = response.data;
      final json =
          body is String
              ? jsonDecode(body) as Map<String, dynamic>
              : Map<String, dynamic>.from(body as Map);

      final release = parseRelease(json, preferredAbis: abis);
      if (release == null) {
        throw const UpdateCheckException(UpdateCheckFailure.unreadable);
      }
      return release;
    } on UpdateCheckException {
      rethrow;
    } catch (e) {
      AppLogger.warning('Release payload unreadable ($url): $e');
      throw UpdateCheckException(
        UpdateCheckFailure.unreadable,
        detail: e.toString(),
      );
    }
  }

  /// Turn what the network said into a reason worth showing.
  static UpdateCheckFailure failureFor(int? status, [DioExceptionType? type]) {
    if (status == 404) {
      return UpdateCheckFailure.notFound;
    }
    // GitHub answers 403 with a rate-limit header, and 429 when it is stricter.
    if (status == 403 || status == 429) {
      return UpdateCheckFailure.rateLimited;
    }
    if (status != null && status >= 500) {
      return UpdateCheckFailure.offline;
    }
    if (type == DioExceptionType.badResponse && status != null) {
      return UpdateCheckFailure.unreadable;
    }
    return UpdateCheckFailure.offline;
  }

  /// Read a GitHub release payload. Kept separate so it can be tested.
  static AppRelease? parseRelease(
    Map<String, dynamic> json, {
    List<String> preferredAbis = const [],
  }) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final assets = (json['assets'] as List?) ?? const [];

    final apks = <Map<String, dynamic>>[];
    for (final raw in assets) {
      if (raw is! Map) {
        continue;
      }
      final asset = Map<String, dynamic>.from(raw);
      final assetName = (asset['name'] as String? ?? '').toLowerCase();
      if (assetName.endsWith('.apk')) {
        apks.add(asset);
      }
    }

    final apk = _pickApk(apks, preferredAbis);
    final version = _versionFrom(tag, name, apk?['name'] as String?);
    if (version == null) {
      return null;
    }

    return AppRelease(
      versionName: version.$1,
      buildNumber: version.$2,
      notes: (json['body'] as String? ?? '').trim(),
      pageUrl:
          json['html_url'] as String? ??
          'https://github.com/$_owner/$_repo/releases',
      apkUrl: apk?['browser_download_url'] as String?,
      apkBytes: (apk?['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Prefer the APK built for this phone's CPU over the fat universal file.
  static Map<String, dynamic>? _pickApk(
    List<Map<String, dynamic>> apks,
    List<String> preferredAbis,
  ) {
    if (apks.isEmpty) {
      return null;
    }

    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final apk in apks) {
      final score = _apkScore(apk['name'] as String? ?? '', preferredAbis);
      if (score > bestScore) {
        best = apk;
        bestScore = score;
      }
    }
    return best;
  }

  static int _apkScore(String name, List<String> preferredAbis) {
    final lower = name.toLowerCase();
    if (!lower.endsWith('.apk')) {
      return -1;
    }
    var score = 0;
    for (var i = 0; i < preferredAbis.length; i++) {
      if (lower.contains(preferredAbis[i].toLowerCase())) {
        score += 200 - i;
        break;
      }
    }
    if (lower.contains('universal')) {
      score -= 20;
    }
    // The versioned filename carries the build number the comparison needs.
    if (!lower.contains('latest')) {
      score += 10;
    }
    return score;
  }

  /// Pull "1.0.1" and the build number out of whatever the release is called.
  ///
  /// The APK is named `islamic-app-1.0.1-build47.apk`, and the title carries
  /// the same pair, so either will do — but the build number is what decides
  /// newer, and a release without one cannot be compared at all.
  static (String, int)? _versionFrom(String tag, String name, String? asset) {
    final pattern = RegExp(r'(\d+\.\d+\.\d+)(?:[-+ ]?(?:build)?(\d+))?');

    (String, int)? withoutBuild;

    for (final candidate in [asset ?? '', name, tag]) {
      final match = pattern.firstMatch(candidate);
      if (match == null) {
        continue;
      }
      final build = int.tryParse(match.group(2) ?? '');
      if (build != null && build > 0) {
        return (match.group(1)!, build);
      }
      // A version with no build number cannot be compared — build 0 is never
      // greater than what is installed, so taking it would report every
      // release as old. Keep looking, and only fall back to it if nothing
      // else carries one.
      withoutBuild ??= (match.group(1)!, 0);
    }

    return withoutBuild;
  }

  /// Whether [release] is worth telling the user about.
  static bool isNewer(AppRelease release, int currentBuild) =>
      release.buildNumber > currentBuild;

  /// Has enough time passed to look again?
  static bool isDue(SharedPreferences prefs, {DateTime? now}) {
    final last = prefs.getInt(lastCheckKey);
    if (last == null) {
      return true;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(last);
    return (now ?? DateTime.now()).difference(at) >= checkInterval;
  }

  static Future<void> markChecked(SharedPreferences prefs, {DateTime? now}) =>
      prefs.setInt(
        lastCheckKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );

  static Future<void> skip(SharedPreferences prefs, int buildNumber) =>
      prefs.setInt(skippedBuildKey, buildNumber);

  static bool wasSkipped(SharedPreferences prefs, int buildNumber) =>
      (prefs.getInt(skippedBuildKey) ?? -1) >= buildNumber;

  /// "12.4 MB" — a size someone can weigh against their data.
  static String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '';
    }
    if (bytes >= 1000000) {
      return '${(bytes / 1000000).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1000).round()} KB';
  }
}
