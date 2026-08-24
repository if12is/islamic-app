import '../../domain/ayah_video_spec.dart';

/// What FFmpeg is asked to do, worked out as plain strings.
///
/// Kept apart from the encoder itself so it can be tested without a native
/// build — the parts that go wrong here (a concat playlist that ends a verse
/// early, a pixel format no phone will play) are exactly the parts that are
/// pure text.
class VideoEncodePlan {
  VideoEncodePlan._();

  /// How long the opening and closing fades run.
  static const double fadeSeconds = 0.5;

  /// The concat demuxer's playlist for the still frames.
  ///
  /// Its quirk: the duration of the last entry is ignored, so the final image
  /// has to be listed twice or the video ends one verse early.
  static String frameList(VideoTimeline timeline, Map<int, String> frames) {
    final buffer = StringBuffer();
    String? last;
    for (final segment in timeline.segments) {
      final path = frames[segment.verseNumber];
      if (path == null) {
        continue;
      }
      final seconds = segment.duration.inMilliseconds / 1000;
      buffer
        ..writeln("file '$path'")
        ..writeln('duration ${seconds.toStringAsFixed(3)}');
      last = path;
    }
    if (last != null) {
      buffer.writeln("file '$last'");
    }
    return buffer.toString();
  }

  /// The recitation, in the same order as the frames.
  static String audioList(VideoTimeline timeline, Map<int, String> audio) {
    final buffer = StringBuffer();
    for (final segment in timeline.segments) {
      final path = audio[segment.verseNumber];
      if (path != null) {
        buffer.writeln("file '$path'");
      }
    }
    return buffer.toString();
  }

  /// The encode itself.
  ///
  /// `yuv420p` and even dimensions are not optional: without them the file
  /// plays here and shows a black rectangle in WhatsApp. `+faststart` moves
  /// the index to the front so it starts playing before it has downloaded.
  static String command({
    required String frameListPath,
    required String audioListPath,
    required String outputPath,
    required VideoAspect aspect,
    required Duration total,
  }) {
    final seconds = total.inMilliseconds / 1000;
    final fadeOutAt = (seconds - fadeSeconds).clamp(0, double.infinity);
    final out = fadeOutAt.toStringAsFixed(2);

    final filters = [
      'fps=30',
      'scale=${aspect.width}:${aspect.height}:force_original_aspect_ratio=decrease',
      'pad=${aspect.width}:${aspect.height}:(ow-iw)/2:(oh-ih)/2',
      'fade=t=in:st=0:d=$fadeSeconds',
      'fade=t=out:st=$out:d=$fadeSeconds',
      'format=yuv420p',
    ].join(',');

    return [
      '-y',
      '-f concat -safe 0 -i "$frameListPath"',
      '-f concat -safe 0 -i "$audioListPath"',
      '-vf "$filters"',
      '-c:v libx264 -preset veryfast -crf 23',
      '-c:a aac -b:a 128k',
      '-af "afade=t=out:st=$out:d=$fadeSeconds"',
      '-movflags +faststart',
      '-shortest',
      '"$outputPath"',
    ].join(' ');
  }
}
