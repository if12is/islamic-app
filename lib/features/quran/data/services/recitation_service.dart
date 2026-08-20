import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/utils/app_logger.dart';
import 'offline_recitation_engine.dart';
import 'offline_recogniser.dart';
import 'stt_model_catalogue.dart';
import 'stt_model_store.dart';

/// Why a recitation session could not start.
enum RecitationFailure { unavailable, permissionDenied, noArabicLocale, error }

/// Who is doing the listening.
enum RecitationEngine {
  /// The phone's own recogniser, using one of its installed voice packs.
  device,

  /// A model the user downloaded, running on the phone with no network.
  offline,
}

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
/// There are two engines, and the user picks. By default it is the device's
/// own recogniser: nothing is recorded, nothing is uploaded by the app, and
/// there is nothing to download. If the user downloaded a model instead, that
/// one wins — it needs no Arabic pack and no network at all, which is the whole
/// reason it exists.
///
/// Neither is built for classical recitation: both return modern spelling and
/// stumble on elongation. That is why the app treats their output as a hint to
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

  /// Built only when a downloaded model is actually chosen — the microphone
  /// plugin should not be touched by people using the device recogniser.
  OfflineRecitationEngine? _offline;

  RecitationEngine _engine = RecitationEngine.device;
  SttModel? _activeModel;

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

  bool get isListening => _offline?.isListening == true || _speech.isListening;

  /// The pack in use, once known.
  String? get localeId => _localeId;

  /// Which engine the last [prepare] settled on.
  RecitationEngine get engine => _engine;

  /// The downloaded model doing the listening, when one is.
  SttModel? get activeModel => _activeModel;

  /// The downloaded model the user picked, if it is still on disk.
  ///
  /// Returns null when nothing was chosen, when the choice names a model that
  /// is no longer in the catalogue, or when its files were deleted — in every
  /// one of those cases the device recogniser is the honest fallback.
  static Future<SttModel?> preferredOfflineModel() async {
    try {
      final id = await SttModelStore.selectedId();
      if (id == null) {
        return null;
      }
      final model = SttModelCatalogue.byId(id);
      if (model == null) {
        return null;
      }
      return await SttModelStore.isInstalled(model) ? model : null;
    } catch (e, stack) {
      // Storage that will not answer is not a reason to refuse to listen.
      AppLogger.error('Could not read the offline model choice', e, stack);
      return null;
    }
  }

  /// Bring the recogniser up without starting to listen.
  Future<bool> ensureInitialized() async {
    if (_initialized) {
      return true;
    }
    try {
      _initialized = await _speech.initialize(
        onError:
            (error) => AppLogger.warning('Speech error: ${error.errorMsg}'),
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
  ///
  /// A downloaded model wins when there is one: the user went and fetched it,
  /// and it is the only engine that works on a phone with no Arabic pack. If
  /// loading it fails, this falls through to the device recogniser rather than
  /// dead-ending on a model the user cannot fix from here.
  Future<RecitationFailure?> prepare() async {
    try {
      final model = await preferredOfflineModel();
      if (model != null) {
        final engine = _offline ??= OfflineRecitationEngine();
        if (!await engine.hasPermission()) {
          return RecitationFailure.permissionDenied;
        }
        if (await OfflineRecogniser.load(model)) {
          _engine = RecitationEngine.offline;
          _activeModel = model;
          return null;
        }
        AppLogger.warning(
          'Offline model ${model.id} would not load; using the device engine',
        );
      }

      _engine = RecitationEngine.device;
      _activeModel = null;

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

  /// Forget the resolved pack and engine, so the next session re-reads both.
  void invalidateLocale() {
    _localeId = null;
    _activeModel = null;
    _engine = RecitationEngine.device;
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

    if (_engine == RecitationEngine.offline) {
      final started = await _offline!.start(onResult: onResult);
      return started ? null : RecitationFailure.error;
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
    if (_offline?.isListening == true) {
      await _offline!.stop();
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    await _offline?.cancel();
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// Release the microphone for good. Called when the screen goes away.
  void dispose() {
    _offline?.dispose();
    _offline = null;
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
