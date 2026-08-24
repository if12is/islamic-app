/// Turns a passage into an MP4.
///
/// The real encoder needs `dart:io` and a native FFmpeg build, neither of
/// which exists in a browser, so the implementation is chosen at compile time.
/// Importing this file is always safe; calling `AyahVideoExporter.export`
/// where it is unsupported returns a failure rather than throwing.
library;

export 'ayah_video_exporter_stub.dart'
    if (dart.library.io) 'ayah_video_exporter_ffmpeg.dart';
