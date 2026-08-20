import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/utils/app_logger.dart';

/// Why a recitation session could not start.
enum RecitationFailure { unavailable, permissionDenied, noArabicLocale, error }

/// One voice pack the device has installed.
class RecitationLocale {
  const RecitationLocale({
    required this.id,
    required this.name,
    required this.isArabic,
  });

  final String id;
  final String name;

  /// Whether this pack understands Arabic.
  final bool isArabic;
}

/// Listens to a recitation and returns what it heard.
///
/// The engine is the device's own recogniser, so nothing is recorded, nothing
/// is uploaded by the app, and there is no model for us to download. It is
/// also not built for classical recitation: it returns modern spelling and
/// stumbles on elongation. That is why the app treats its output as a hint to
/// be aligned against the text, never as a verdict.
///
/// Which pack it uses is the user's choice, not ours. A phone may carry several
/// Arabic packs or none at all, so the app lists what is installed, remembers
/// the one that was picked, and can open the screen where more are downloaded.
/// It never insists on a particular dialect, and it never makes the download a
/// condition of using the rest of the app.
class RecitationService {
  RecitationService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool _initialized = false;
  String? _localeId;

  static const MethodChannel _channel = MethodChannel(
    'islamic_app/adhan_sound',
  );

  /// Where the chosen pack is remembered.
  static const String preferenceKey = 'recitation_locale_id';

  /// Tried in order when the user has not chosen one; the first the device has
  /// wins. Nothing here is required — it is only a sensible first guess.
  static const List<String> preferredLocales = [
    'ar_SA',
    'ar_EG',
    'ar_AE',
    'ar_JO',
    'ar',
  ];

  bool get isListening => _speech.isListening;

  /// The pack in use, once known.
  String? get localeId => _localeId;

  /// Bring the recogniser up without starting to listen.
  Future<bool> ensureInitialized() async {
    if (_initialized) {
      return true;
    }
    try {
      _initialized = await _speech.initialize(
        onError: (error) =>
            AppLogger.warning('Speech error: ${error.errorMsg}'),
        onStatus: (status) => AppLogger.debug('Speech status: $status'),
      );
    } catch (e, stack) {
      AppLogger.error('Speech recognition unavailable', e, stack);
      _initialized = false;
    }
    return _initialized;
  }

  /// Every pack the device has, Arabic ones first.
  Future<List<RecitationLocale>> installedLocales() async {
    if (!await ensureInitialized()) {
      return const [];
    }

    try {
      final locales = await _speech.locales();
      return [
        for (final locale in locales)
          RecitationLocale(
            id: locale.localeId,
            name: locale.name,
            isArabic: isArabic(locale.localeId),
          ),
      ]..sort((a, b) {
        if (a.isArabic != b.isArabic) {
          return a.isArabic ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
    } catch (e, stack) {
      AppLogger.error('Could not list voice packs', e, stack);
      return const [];
    }
  }

  /// Remember which pack to use. Pass null to go back to automatic.
  static Future<void> setPreferredLocale(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(preferenceKey);
    } else {
      await prefs.setString(preferenceKey, id);
    }
  }

  static Future<String?> savedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(preferenceKey);
  }

  /// Open wherever this device downloads offline voice packs.
  ///
  /// Returns false when no such screen exists, so the caller can say so rather
  /// than leaving a button that quietly does nothing.
  static Future<bool> openSystemSpeechSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openSpeechSettings');
      return opened ?? false;
    } catch (e) {
      AppLogger.warning('Could not open speech settings: $e');
      return false;
    }
  }

  /// Prepare the recogniser and settle on a pack.
  Future<RecitationFailure?> prepare() async {
    try {
      if (!await ensureInitialized()) {
        return RecitationFailure.unavailable;
      }
      if (!await _speech.hasPermission) {
        return RecitationFailure.permissionDenied;
      }

      _localeId ??= await _resolveLocale();
      if (_localeId == null) {
        return RecitationFailure.noArabicLocale;
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Could not start speech recognition', e, stack);
      return RecitationFailure.error;
    }
  }

  /// Forget the resolved pack, so the next session re-reads the choice.
  void invalidateLocale() => _localeId = null;

  /// Start listening. [onResult] fires for partial results too, so the page
  /// can colour words while the reciter is still going.
  Future<RecitationFailure?> start({
    required void Function(String text, bool isFinal) onResult,
    Duration listenFor = const Duration(minutes: 2),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    final failure = await prepare();
    if (failure != null) {
      return failure;
    }

    try {
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
      return null;
    } catch (e, stack) {
      AppLogger.error('Listening failed', e, stack);
      return RecitationFailure.error;
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// The user's choice if they made one and it is still installed, otherwise
  /// the best Arabic pack on the device.
  Future<String?> _resolveLocale() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) {
      return null;
    }

    final chosen = await savedLocale();
    if (chosen != null) {
      for (final locale in locales) {
        if (locale.localeId == chosen) {
          return locale.localeId;
        }
      }
      // The pack was removed since it was chosen; fall through and pick again.
    }

    for (final preferred in preferredLocales) {
      for (final locale in locales) {
        if (locale.localeId.replaceAll('-', '_') == preferred) {
          return locale.localeId;
        }
      }
    }

    for (final locale in locales) {
      if (isArabic(locale.localeId)) {
        return locale.localeId;
      }
    }
    return null;
  }

  static bool isArabic(String localeId) =>
      localeId.toLowerCase().startsWith('ar');
}
