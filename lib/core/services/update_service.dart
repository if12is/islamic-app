import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

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

/// Checks GitHub for a newer build and fetches it.
///
/// **There is no such thing as a partial update for an app installed outside
/// the Play Store.** Delta patching is something Play does on its own servers
/// to APKs it signed; a sideloaded APK is one indivisible signed archive, and
/// patching it would break the signature that lets Android treat the new file
/// as an upgrade of the old one rather than a different app.
///
/// So the whole APK is downloaded — but only the APK for the phone's own CPU.
/// The CI build splits per ABI, which is roughly a third of the size of the
/// universal file, and that is the real saving available here.
class UpdateService {
  UpdateService._();

  static const String _owner = 'if12is';
  static const String _repo = 'islamic-app';

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
  /// Returns null when the network is unavailable or the repository has no
  /// release yet — neither is worth interrupting anyone about.
  static Future<AppRelease?> fetchLatest({Dio? client}) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final dio = client ?? Dio();
      final response = await dio.get<dynamic>(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final body = response.data;
      final json =
          body is String
              ? jsonDecode(body) as Map<String, dynamic>
              : Map<String, dynamic>.from(body as Map);

      return parseRelease(json);
    } catch (e) {
      AppLogger.warning('Update check failed: $e');
      return null;
    }
  }

  /// Read a GitHub release payload. Kept separate so it can be tested.
  static AppRelease? parseRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final assets = (json['assets'] as List?) ?? const [];

    Map<String, dynamic>? apk;
    for (final raw in assets) {
      if (raw is! Map) {
        continue;
      }
      final asset = Map<String, dynamic>.from(raw);
      final assetName = (asset['name'] as String? ?? '').toLowerCase();
      if (!assetName.endsWith('.apk')) {
        continue;
      }
      // Prefer the file named for a version over the rolling "latest" copy:
      // its name carries the build number the comparison needs.
      if (apk == null || !assetName.contains('latest')) {
        apk = asset;
      }
    }

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

  /// Pull "1.0.1" and the build number out of whatever the release is called.
  ///
  /// The APK is named `islamic-app-1.0.1-build47.apk`, and the title carries
  /// the same pair, so either will do — but the build number is what decides
  /// newer, and a release without one cannot be compared at all.
  static (String, int)? _versionFrom(String tag, String name, String? asset) {
    final pattern = RegExp(r'(\d+\.\d+\.\d+)(?:[-+ ]?(?:build)?(\d+))?');

    for (final candidate in [asset ?? '', name, tag]) {
      final match = pattern.firstMatch(candidate);
      if (match != null) {
        return (match.group(1)!, int.tryParse(match.group(2) ?? '') ?? 0);
      }
    }
    return null;
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
