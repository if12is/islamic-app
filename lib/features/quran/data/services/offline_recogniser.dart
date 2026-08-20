import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../../core/utils/app_logger.dart';
import 'stt_model_catalogue.dart';
import 'stt_model_store.dart';

/// Recognition that runs entirely on the phone, with a model the user chose.
///
/// This is the alternative to the device's built-in recogniser: no Google, no
/// network, no account, and it keeps working in airplane mode. The cost is the
/// download and the CPU — which is exactly why it is opt-in, one model at a
/// time, and deletable.
///
/// Whisper was trained on ordinary modern speech, not on tajwid. It is better
/// than nothing and often better than a phone with no Arabic pack at all, but
/// the recitation screen still calls itself experimental, whichever engine is
/// behind it.
class OfflineRecogniser {
  OfflineRecogniser._();

  static sherpa.OfflineRecognizer? _recognizer;
  static String? _loadedId;

  static bool get isLoaded => _recognizer != null;

  static String? get loadedModelId => _loadedId;

  /// Load [model], replacing whatever was loaded before.
  ///
  /// Returns false when the files are not there — the caller should fall back
  /// to the device recogniser rather than failing the whole screen.
  static Future<bool> load(SttModel model) async {
    if (_loadedId == model.id && _recognizer != null) {
      return true;
    }

    if (!await SttModelStore.isInstalled(model)) {
      return false;
    }

    try {
      sherpa.initBindings();
      final directory = await SttModelStore.directoryFor(model);

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '${directory.path}/${model.encoder}',
            decoder: '${directory.path}/${model.decoder}',
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: '${directory.path}/${model.tokens}',
          modelType: 'whisper',
          numThreads: 2,
          debug: false,
        ),
      );

      unload();
      _recognizer = sherpa.OfflineRecognizer(config);
      _loadedId = model.id;
      AppLogger.info('Offline recogniser loaded: ${model.id}');
      return true;
    } catch (e, stack) {
      AppLogger.error('Could not load the offline model', e, stack);
      unload();
      return false;
    }
  }

  /// Transcribe one buffer of 16 kHz mono samples.
  static String transcribe(Float32List samples, {int sampleRate = 16000}) {
    final recognizer = _recognizer;
    if (recognizer == null) {
      return '';
    }

    try {
      final stream = recognizer.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text;
      stream.free();
      return text;
    } catch (e, stack) {
      AppLogger.error('Offline transcription failed', e, stack);
      return '';
    }
  }

  static void unload() {
    _recognizer?.free();
    _recognizer = null;
    _loadedId = null;
  }
}
