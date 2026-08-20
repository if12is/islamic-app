/// An offline recognition model the user may choose to download.
///
/// These are the "not Google" option: they run entirely on the phone, work in
/// airplane mode, and belong to the user rather than to a service. The trade is
/// size — a usable multilingual model is over a hundred megabytes — so nothing
/// here is downloaded unless it is asked for by name.
class SttModel {
  const SttModel({
    required this.id,
    required this.nameKey,
    required this.url,
    required this.downloadBytes,
    required this.installedBytes,
    required this.folder,
    required this.encoder,
    required this.decoder,
    required this.tokens,
    required this.licence,
    required this.quality,
  });

  final String id;

  /// Localization key for the display name.
  final String nameKey;

  /// Where the archive lives. GitHub release assets, served over HTTPS.
  final String url;

  /// Compressed size, for the confirmation before a download starts.
  final int downloadBytes;

  /// Roughly what it occupies once unpacked.
  final int installedBytes;

  /// Directory inside the archive, which becomes the install folder name.
  final String folder;

  final String encoder;
  final String decoder;
  final String tokens;

  final String licence;

  /// 1 (fast, rough) to 3 (slow, best). Shown so the choice is informed.
  final int quality;
}

/// The models the app offers.
///
/// Only multilingual Whisper builds are listed: the English-only and Chinese
/// models are smaller and better, and useless here. Even these were trained on
/// modern speech, not on tajwid — which is why the recitation screen calls
/// itself experimental whichever engine is in use.
class SttModelCatalogue {
  SttModelCatalogue._();

  static const String _base =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';

  static const List<SttModel> models = [
    SttModel(
      id: 'whisper-tiny',
      nameKey: 'stt_model_tiny',
      url: '$_base/sherpa-onnx-whisper-tiny.tar.bz2',
      downloadBytes: 116000000,
      installedBytes: 190000000,
      folder: 'sherpa-onnx-whisper-tiny',
      encoder: 'tiny-encoder.int8.onnx',
      decoder: 'tiny-decoder.int8.onnx',
      tokens: 'tiny-tokens.txt',
      licence: 'MIT (OpenAI Whisper)',
      quality: 1,
    ),
    SttModel(
      id: 'whisper-base',
      nameKey: 'stt_model_base',
      url: '$_base/sherpa-onnx-whisper-base.tar.bz2',
      downloadBytes: 208000000,
      installedBytes: 330000000,
      folder: 'sherpa-onnx-whisper-base',
      encoder: 'base-encoder.int8.onnx',
      decoder: 'base-decoder.int8.onnx',
      tokens: 'base-tokens.txt',
      licence: 'MIT (OpenAI Whisper)',
      quality: 2,
    ),
    SttModel(
      id: 'whisper-small',
      nameKey: 'stt_model_small',
      url: '$_base/sherpa-onnx-whisper-small.tar.bz2',
      downloadBytes: 640000000,
      installedBytes: 1000000000,
      folder: 'sherpa-onnx-whisper-small',
      encoder: 'small-encoder.int8.onnx',
      decoder: 'small-decoder.int8.onnx',
      tokens: 'small-tokens.txt',
      licence: 'MIT (OpenAI Whisper)',
      quality: 3,
    ),
  ];

  static SttModel? byId(String id) {
    for (final model in models) {
      if (model.id == id) {
        return model;
      }
    }
    return null;
  }

  /// "116 MB" — sizes people can weigh against their data plan.
  static String formatBytes(int bytes) {
    if (bytes >= 1000000000) {
      return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
    }
    return '${(bytes / 1000000).round()} MB';
  }
}
