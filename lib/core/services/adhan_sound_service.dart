import 'package:flutter/services.dart';

import '../models/adhan_sound.dart';
import '../utils/app_logger.dart';

/// Lets the user bring their own adhan.
///
/// Android only plays a notification sound it can read itself, so an imported
/// file is copied into the shared MediaStore notifications collection by the
/// native side and comes back as a `content://` URI.
class AdhanSoundService {
  AdhanSoundService._();

  static const MethodChannel _channel = MethodChannel(
    'islamic_app/adhan_sound',
  );

  /// Open the file picker and import the chosen audio file.
  ///
  /// Returns null when the user cancels; throws [AdhanImportException] when the
  /// device cannot import (Android 9 or older) or the copy fails.
  static Future<AdhanSoundSelection?> importFile() async {
    return _invoke('importAudioFile');
  }

  /// Pick one of the notification sounds already on the device.
  static Future<AdhanSoundSelection?> pickSystemSound() async {
    return _invoke('pickSystemSound');
  }

  /// Human-readable name for a sound URI, when the system knows one.
  static Future<String?> titleFor(String uri) async {
    try {
      return await _channel.invokeMethod<String>('soundTitle', {'uri': uri});
    } on PlatformException catch (e) {
      AppLogger.warning('Could not read sound title: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<AdhanSoundSelection?> _invoke(String method) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(method);
      if (result == null) {
        return null;
      }

      final uri = result['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        return null;
      }

      return AdhanSoundSelection(
        id: AdhanSoundSelection.customId,
        uri: uri,
        title: (result['title'] as String?)?.trim(),
      );
    } on PlatformException catch (e) {
      AppLogger.warning('Adhan sound picker failed: ${e.code} ${e.message}');
      throw AdhanImportException(e.code, e.message);
    } on MissingPluginException {
      throw const AdhanImportException('unsupported', 'Not available here');
    }
  }
}

/// Raised when importing an adhan is impossible on this device.
class AdhanImportException implements Exception {
  const AdhanImportException(this.code, this.message);

  final String code;
  final String? message;

  /// True when the platform itself cannot do it (old Android, or desktop).
  bool get isUnsupported => code == 'unsupported';

  @override
  String toString() => 'AdhanImportException($code): $message';
}
