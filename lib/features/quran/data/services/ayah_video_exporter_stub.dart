import '../../domain/ayah_video_spec.dart';
import 'video_export_result.dart';

/// The browser build. There is no FFmpeg and no filesystem here, so the studio
/// still previews and still exports a still image — only the video is off.
class AyahVideoExporter {
  AyahVideoExporter._();

  static bool get isSupported => false;

  static Future<VideoExportResult> export({
    required AyahVideoSpec spec,
    required Map<int, String> verseTexts,
    required FrameRenderer renderFrame,
    required String fileStem,
    void Function(VideoExportProgress progress)? onProgress,
  }) async {
    return const VideoExportResult.failure('video_export_unsupported');
  }

  static Future<void> cancel() async {}
}
