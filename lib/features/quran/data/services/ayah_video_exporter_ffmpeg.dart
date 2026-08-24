import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/ayah_video_spec.dart';
import 'quran_local_service.dart';
import 'video_encode_plan.dart';
import 'video_export_result.dart';

/// Builds an MP4 of a passage: the recitation, and the verse being recited.
///
/// The video is a cut per ayah, not a fixed slide length. Each verse holds the
/// screen for exactly as long as its own recording runs, which is why the
/// audio is fetched and measured before a single frame is written — a card
/// that changes half a word early is the one thing that would make the whole
/// export feel wrong.
class AyahVideoExporter {
  AyahVideoExporter._();

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Folder inside the app's cache. Cleared at the start of every export, so a
  /// cancelled run never leaves half a video behind to be shared by mistake.
  static const String _workFolder = 'ayah_video';

  static bool _running = false;

  /// Render and encode. Returns the path of the finished file.
  ///
  /// [renderFrame] paints one PNG for a verse; the studio supplies it because
  /// painting needs a widget tree. [verseTexts] is only used to name what is
  /// missing when a verse has no audio.
  static Future<VideoExportResult> export({
    required AyahVideoSpec spec,
    required Map<int, String> verseTexts,
    required FrameRenderer renderFrame,
    required String fileStem,
    void Function(VideoExportProgress progress)? onProgress,
  }) async {
    if (!isSupported) {
      return const VideoExportResult.failure('video_export_unsupported');
    }
    if (spec.isTooLong) {
      return const VideoExportResult.failure('video_export_too_long');
    }

    _running = true;
    void report(VideoExportStage stage, [double fraction = -1]) {
      onProgress?.call(VideoExportProgress(stage, fraction));
    }

    Directory? work;
    try {
      report(VideoExportStage.preparing);
      work = await _freshWorkDirectory();

      final verses = spec.verseNumbers;

      // 1. The recitation, one file per ayah.
      report(VideoExportStage.fetchingAudio, 0);
      final audioPaths = <int, String>{};
      final dio = _downloadClient();
      for (var i = 0; i < verses.length; i++) {
        if (!_running) {
          return const VideoExportResult.failure('video_export_cancelled');
        }
        final verse = verses[i];
        final path = '${work.path}/a${i.toString().padLeft(3, '0')}.mp3';
        final url = QuranLocalService.audioUrlForVerse(
          spec.surahNumber,
          verse,
          reciterCode: spec.reciterCode,
        );
        try {
          await dio.download(url, path);
          audioPaths[verse] = path;
        } catch (e) {
          AppLogger.warning('Verse audio $verse could not be fetched: $e');
        }
        report(VideoExportStage.fetchingAudio, (i + 1) / verses.length);
      }

      if (audioPaths.isEmpty) {
        return const VideoExportResult.failure('video_export_no_audio');
      }

      // 2. How long each one runs. This is what drives the cuts.
      report(VideoExportStage.measuring, 0);
      final durations = <int, Duration?>{};
      for (var i = 0; i < verses.length; i++) {
        final verse = verses[i];
        final path = audioPaths[verse];
        durations[verse] = path == null ? null : await _durationOf(path);
        report(VideoExportStage.measuring, (i + 1) / verses.length);
      }
      final timeline = VideoTimeline.fromDurations(durations);

      // 3. One frame per verse; the composition is still while it is recited.
      report(VideoExportStage.rendering, 0);
      final framePaths = <int, String>{};
      for (var i = 0; i < verses.length; i++) {
        if (!_running) {
          return const VideoExportResult.failure('video_export_cancelled');
        }
        final verse = verses[i];
        final bytes = await renderFrame(verse);
        final path = '${work.path}/f${i.toString().padLeft(3, '0')}.png';
        await File(path).writeAsBytes(bytes, flush: true);
        framePaths[verse] = path;
        report(VideoExportStage.rendering, (i + 1) / verses.length);
      }

      // 4. Hand FFmpeg two playlists and let it do the muxing.
      final videoList = File('${work.path}/frames.txt');
      await videoList.writeAsString(
        VideoEncodePlan.frameList(timeline, framePaths),
        flush: true,
      );

      final audioList = File('${work.path}/audio.txt');
      await audioList.writeAsString(
        VideoEncodePlan.audioList(timeline, audioPaths),
        flush: true,
      );

      final output = '${work.path}/$fileStem.mp4';
      report(VideoExportStage.encoding);

      final command = VideoEncodePlan.command(
        frameListPath: videoList.path,
        audioListPath: audioList.path,
        outputPath: output,
        aspect: spec.aspect,
        total: timeline.total,
      );

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (!_running) {
        return const VideoExportResult.failure('video_export_cancelled');
      }
      if (!ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogsAsString();
        AppLogger.error(
          'Video encode failed (${code?.getValue()})',
          logs ?? '',
          StackTrace.current,
        );
        return VideoExportResult.failure(
          'video_export_failed',
          detail: _lastLines(logs),
        );
      }

      report(VideoExportStage.finished, 1);
      return VideoExportResult.success(filePath: output, timeline: timeline);
    } catch (e, stack) {
      AppLogger.error('Video export failed', e, stack);
      return VideoExportResult.failure(
        'video_export_failed',
        detail: e.toString(),
      );
    } finally {
      _running = false;
    }
  }

  /// Stop an export in flight. The frames already written are cleaned up on
  /// the next run rather than raced with the encoder here.
  static Future<void> cancel() async {
    _running = false;
    try {
      await FFmpegKit.cancel();
    } catch (e) {
      AppLogger.warning('Could not cancel the encoder: $e');
    }
  }

  static Future<Duration?> _durationOf(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final raw = session.getMediaInformation()?.getDuration();
      final seconds = double.tryParse(raw ?? '');
      if (seconds == null || seconds <= 0) {
        return null;
      }
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (e) {
      AppLogger.warning('Could not measure $path: $e');
      return null;
    }
  }

  static Dio _downloadClient() {
    final dio = SecureHttpClient.create();
    // The allowlist and the HTTPS check still apply; only the JSON-shaped
    // defaults are wrong for a media file.
    dio.options.responseType = ResponseType.bytes;
    dio.options.headers.remove('Accept');
    dio.options.receiveTimeout = const Duration(seconds: 60);
    return dio;
  }

  static Future<Directory> _freshWorkDirectory() async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/$_workFolder');
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    return directory;
  }

  /// FFmpeg's logs run to hundreds of lines; the reason is always at the end.
  static String? _lastLines(String? logs, {int lines = 4}) {
    if (logs == null || logs.trim().isEmpty) {
      return null;
    }
    final all = logs.trim().split('\n');
    return all.sublist(all.length > lines ? all.length - lines : 0).join('\n');
  }
}
