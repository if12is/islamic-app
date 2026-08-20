import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../../../core/utils/app_logger.dart';
import 'offline_recogniser.dart';

/// Captures the microphone and hands the audio to the downloaded model.
///
/// The device recogniser does its own listening, so nothing like this is needed
/// for it. An offline model does not listen — it is handed a buffer of samples
/// and returns text — which is why the raw microphone lives here.
///
/// Whisper reads a whole utterance rather than a stream, so this decodes the
/// audio so far every couple of seconds and again when the reciter stops. Words
/// therefore appear a beat behind the voice, not letter by letter.
class OfflineRecitationEngine {
  /// What every offline model here expects: 16 kHz, mono.
  static const int sampleRate = 16000;

  /// Whisper only ever looks at the last thirty seconds. Keeping more would
  /// slow every decode down for audio the model is going to discard.
  static const int windowSamples = sampleRate * 30;

  /// How much new audio to gather before decoding again.
  static const int decodeEvery = sampleRate * 2;

  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _subscription;
  final List<double> _samples = <double>[];

  int _sinceDecode = 0;
  bool _decoding = false;
  bool _running = false;
  String _text = '';

  void Function(String text, bool isFinal)? _onResult;

  bool get isListening => _running;

  /// Everything heard in this session, as the model last transcribed it.
  String get text => _text;

  /// Ask for the microphone, prompting if it has not been granted yet.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e, stack) {
      AppLogger.error('Microphone permission check failed', e, stack);
      return false;
    }
  }

  /// Begin capturing. [onResult] fires on every decode, final on [stop].
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (_running) {
      return true;
    }

    _onResult = onResult;
    _samples.clear();
    _sinceDecode = 0;
    _text = '';

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          // The model was trained on ordinary speech in ordinary rooms; the
          // phone's own cleanup helps it more than it hurts.
          echoCancel: true,
          noiseSuppress: true,
        ),
      );

      _running = true;
      _subscription = stream.listen(
        _onChunk,
        onError: (Object error, StackTrace stack) {
          AppLogger.error('Microphone stream failed', error, stack);
        },
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('Could not open the microphone', e, stack);
      _running = false;
      return false;
    }
  }

  /// Stop capturing and decode whatever is left, so the last words are not lost.
  Future<String> stop() async {
    if (!_running) {
      return _text;
    }
    _running = false;

    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (e) {
      AppLogger.warning('Recorder did not stop cleanly: $e');
    }

    await _decode(isFinal: true);
    return _text;
  }

  /// Stop capturing and throw the audio away without a final decode.
  Future<void> cancel() async {
    _running = false;
    _onResult = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      // Nothing was recording; there is nothing to undo.
    }
    _samples.clear();
    _sinceDecode = 0;
  }

  void dispose() {
    unawaited(cancel());
    _recorder.dispose();
  }

  void _onChunk(Uint8List bytes) {
    if (!_running) {
      return;
    }
    _samples.addAll(pcm16ToFloat32(bytes));
    _sinceDecode += bytes.length ~/ 2;

    if (_sinceDecode >= decodeEvery && !_decoding) {
      _sinceDecode = 0;
      unawaited(_decode(isFinal: false));
    }
  }

  /// Run the model over the trailing window.
  ///
  /// Decoding blocks, so this waits for the current frame to finish first —
  /// otherwise the tap that started the session would stutter before it paints.
  Future<void> _decode({required bool isFinal}) async {
    if (_decoding || _samples.isEmpty) {
      if (isFinal) {
        _onResult?.call(_text, true);
      }
      return;
    }

    _decoding = true;
    await Future<void>.delayed(Duration.zero);

    try {
      final start =
          _samples.length > windowSamples ? _samples.length - windowSamples : 0;
      final window = Float32List.fromList(_samples.sublist(start));
      final heard =
          OfflineRecogniser.transcribe(window, sampleRate: sampleRate).trim();

      if (heard.isNotEmpty) {
        _text = heard;
      }
      _onResult?.call(_text, isFinal);
    } catch (e, stack) {
      AppLogger.error('Offline decode failed', e, stack);
      if (isFinal) {
        _onResult?.call(_text, true);
      }
    } finally {
      _decoding = false;
    }
  }

  /// Little-endian signed 16-bit samples to the floats the model wants.
  static Float32List pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final samples = Float32List(count);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
