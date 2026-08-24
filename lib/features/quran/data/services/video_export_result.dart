import 'dart:typed_data';

import '../../domain/ayah_video_spec.dart';

/// Which part of a long export is running, so the studio can say so.
///
/// "Loading…" for two minutes is indistinguishable from a hang. Naming the
/// step is the difference between waiting and giving up.
enum VideoExportStage {
  preparing,
  fetchingAudio,
  measuring,
  rendering,
  encoding,
  finished,
}

/// A step and how far through it we are, 0–1. A negative fraction means the
/// step cannot report progress and the bar should be indeterminate.
class VideoExportProgress {
  const VideoExportProgress(this.stage, [this.fraction = -1]);

  final VideoExportStage stage;
  final double fraction;

  bool get isIndeterminate => fraction < 0;

  /// The localization key describing this step.
  String get labelKey => switch (stage) {
    VideoExportStage.preparing => 'video_stage_preparing',
    VideoExportStage.fetchingAudio => 'video_stage_audio',
    VideoExportStage.measuring => 'video_stage_measuring',
    VideoExportStage.rendering => 'video_stage_rendering',
    VideoExportStage.encoding => 'video_stage_encoding',
    VideoExportStage.finished => 'video_stage_finished',
  };
}

/// The outcome of an export: a file, or a reason there is not one.
class VideoExportResult {
  const VideoExportResult.success({
    required this.filePath,
    required this.timeline,
  }) : failureKey = null,
       detail = null;

  const VideoExportResult.failure(this.failureKey, {this.detail})
    : filePath = null,
      timeline = VideoTimeline.empty;

  /// Where the finished video landed. Null when it failed.
  final String? filePath;

  final VideoTimeline timeline;

  /// A localization key naming what went wrong.
  final String? failureKey;

  /// The encoder's own words, shown under the message. Useful in a bug report
  /// and worthless if it is hidden.
  final String? detail;

  bool get ok => filePath != null;

  Duration get duration => timeline.total;
}

/// Renders one frame of the composition. Supplied by the studio, because
/// painting a widget needs a widget tree and the encoder has none.
typedef FrameRenderer = Future<Uint8List> Function(int verseNumber);
