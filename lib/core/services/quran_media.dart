import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import 'delivery_check.dart';
import 'notification_service.dart';

/// Shared [MediaItem] for Quran (and other) playback.
///
/// Honor Magic Capsule — the Dynamic Island clone on MagicOS — only attaches
/// to a real media-style notification. That means a monochrome status icon
/// (set at init), album art on the item, and a notification channel louder
/// than the LOW importance `audio_service` would otherwise create.
class QuranMedia {
  QuranMedia._();

  static const String albumName = 'القرآن الكريم';
  static const String coverAsset = 'assets/images/quran_cover.png';

  static Uri? _artUri;
  static bool _permissionAsked = false;
  static bool _batteryAsked = false;

  /// Notification permission so Honor can show the capsule.
  ///
  /// Battery exemption is requested in the background: waiting on Honor's
  /// dialog would hold the recitation until the listener taps Allow.
  static Future<void> prepareSession() async {
    if (kIsWeb) {
      return;
    }
    if (!_permissionAsked) {
      _permissionAsked = true;
      try {
        await NotificationService.requestPermissions();
      } catch (e) {
        AppLogger.warning('Media notification permission failed: $e');
      }
    }
    unawaited(_askBatteryExemption());
  }

  static Future<void> _askBatteryExemption() async {
    if (_batteryAsked) {
      return;
    }
    _batteryAsked = true;
    try {
      final report = await DeliveryCheck.run();
      final batteryRestricted = report.conditions.any(
        (condition) => condition.id == 'battery' && condition.ok != true,
      );
      if (report.vendorRestricts && batteryRestricted) {
        await DeliveryCheck.requestBatteryExemption();
      }
    } catch (e) {
      AppLogger.warning('Media battery check failed: $e');
    }
  }

  static Future<Uri?> coverUri() async {
    if (kIsWeb) {
      return null;
    }
    if (_artUri != null) {
      return _artUri;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/quran_cover.png');
      if (!await file.exists()) {
        final data = await rootBundle.load(coverAsset);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      _artUri = Uri.file(file.path);
      return _artUri;
    } catch (e) {
      AppLogger.warning('Quran cover art missing: $e');
      return null;
    }
  }

  static Future<MediaItem> item({
    required String id,
    required String title,
    required String artist,
    String album = albumName,
  }) async {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: await coverUri(),
    );
  }
}
