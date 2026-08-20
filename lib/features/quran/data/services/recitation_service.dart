import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/utils/app_logger.dart';

/// Why a recitation session could not start.
enum RecitationFailure { unavailable, permissionDenied, noArabicLocale, error }

/// Listens to a recitation and returns what it heard.
///
/// The engine is the device's own recogniser, so nothing is recorded, nothing
/// is uploaded by the app, and there is no model to download. It is also not
/// built for classical recitation: it returns modern spelling and stumbles on
/// elongation. That is why the app treats its output as a hint to be aligned
/// against the text, never as a verdict.
class RecitationService {
  RecitationService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool _initialized = false;
  String? _localeId;

  /// Locale ids tried in order; the first one the device has wins.
  static const List<String> preferredLocales = [
    'ar_SA',
    'ar_EG',
    'ar_AE',
    'ar_JO',
    'ar',
  ];

  bool get isListening => _speech.isListening;

  /// The Arabic locale the device will use, once known.
  String? get localeId => _localeId;

  /// Prepare the recogniser and pick an Arabic locale.
  Future<RecitationFailure?> prepare() async {
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onError:
              (error) => AppLogger.warning('Speech error: ${error.errorMsg}'),
          onStatus: (status) => AppLogger.debug('Speech status: $status'),
        );
      }

      if (!_initialized) {
        return RecitationFailure.unavailable;
      }
      if (!await _speech.hasPermission) {
        return RecitationFailure.permissionDenied;
      }

      _localeId ??= await _resolveArabicLocale();
      if (_localeId == null) {
        return RecitationFailure.noArabicLocale;
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Could not start speech recognition', e, stack);
      return RecitationFailure.error;
    }
  }

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
        onResult:
            (result) => onResult(result.recognizedWords, result.finalResult),
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

  /// The first Arabic locale the device offers.
  Future<String?> _resolveArabicLocale() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) {
      return null;
    }

    for (final preferred in preferredLocales) {
      for (final locale in locales) {
        if (locale.localeId.replaceAll('-', '_') == preferred) {
          return locale.localeId;
        }
      }
    }

    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('ar')) {
        return locale.localeId;
      }
    }
    return null;
  }
}
