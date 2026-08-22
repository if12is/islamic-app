import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/app_logger.dart';
import 'quran_local_service.dart';

/// A surah stored on the device.
class DownloadedSurah {
  const DownloadedSurah({
    required this.reciterCode,
    required this.surahNumber,
    required this.bytes,
  });

  final String reciterCode;
  final int surahNumber;
  final int bytes;

  String get key => '$reciterCode/$surahNumber';
}

/// Downloads whole surahs for offline listening.
///
/// Files live in the app's own directory, so uninstalling the app takes them
/// with it and nothing leaks into the user's media library.
class AudioDownloadService {
  AudioDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _folder = 'quran_audio';

  /// Whether this platform can keep files at all.
  ///
  /// It cannot in a browser: path_provider has no web implementation, so the
  /// very first call throws MissingPluginException. That call sat inside
  /// [sourceFor], which meant playback died before it ever reached the network
  /// — the error looked like a broken connection when nothing had been tried.
  static bool get isSupported => !kIsWeb;

  Future<Directory> _reciterDirectory(String reciterCode) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/$_folder/$reciterCode');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> filePathFor(String reciterCode, int surahNumber) async {
    final directory = await _reciterDirectory(reciterCode);
    return '${directory.path}/$surahNumber.mp3';
  }

  /// The local file when the surah is downloaded, otherwise null.
  Future<String?> localPathIfAvailable(
    String reciterCode,
    int surahNumber,
  ) async {
    if (!isSupported) {
      return null;
    }
    try {
      final path = await filePathFor(reciterCode, surahNumber);
      return File(path).existsSync() ? path : null;
    } catch (e) {
      // Storage that will not answer is a reason to stream, not to fail.
      AppLogger.warning('Local audio lookup failed: $e');
      return null;
    }
  }

  /// What to play: the local file if it exists, otherwise the CDN URL.
  Future<String> sourceFor(String reciterCode, int surahNumber) async {
    final local = await localPathIfAvailable(reciterCode, surahNumber);
    return local ??
        QuranLocalService.audioUrlForSurah(
          surahNumber,
          reciterCode: reciterCode,
        );
  }

  /// Download a surah, reporting bytes as they arrive.
  ///
  /// [onProgress] receives the bytes received and the total, where the total
  /// is -1 whenever the server declines to state one. That happens on every
  /// chunked response, which is most of them — so a caller that only reports a
  /// received/total ratio shows nothing at all for the whole download and then
  /// jumps to finished.
  Future<bool> download({
    required String reciterCode,
    required int surahNumber,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!isSupported) {
      AppLogger.info('Offline downloads are not available in a browser');
      return false;
    }

    final url = QuranLocalService.audioUrlForSurah(
      surahNumber,
      reciterCode: reciterCode,
    );
    final target = await filePathFor(reciterCode, surahNumber);
    final temporary = '$target.part';

    try {
      await _dio.download(
        url,
        temporary,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );

      // Only publish a complete file, so a cancelled download never looks done.
      await File(temporary).rename(target);
      return true;
    } catch (e) {
      final partial = File(temporary);
      if (partial.existsSync()) {
        await partial.delete();
      }
      if (e is DioException && CancelToken.isCancel(e)) {
        AppLogger.info('Download cancelled: $reciterCode/$surahNumber');
      } else {
        AppLogger.warning('Download failed for $reciterCode/$surahNumber: $e');
      }
      return false;
    }
  }

  Future<void> delete(String reciterCode, int surahNumber) async {
    if (!isSupported) {
      return;
    }
    final path = await filePathFor(reciterCode, surahNumber);
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Everything downloaded, across reciters.
  Future<List<DownloadedSurah>> listDownloads() async {
    if (!isSupported) {
      return const [];
    }
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/$_folder');
      if (!directory.existsSync()) {
        return const [];
      }

      final downloads = <DownloadedSurah>[];
      for (final reciterDirectory
          in directory.listSync().whereType<Directory>()) {
        final reciterCode = reciterDirectory.path.split('/').last;
        for (final file in reciterDirectory.listSync().whereType<File>()) {
          final name = file.path.split('/').last;
          if (!name.endsWith('.mp3')) {
            continue;
          }
          final surahNumber = int.tryParse(name.replaceAll('.mp3', ''));
          if (surahNumber == null) {
            continue;
          }
          downloads.add(
            DownloadedSurah(
              reciterCode: reciterCode,
              surahNumber: surahNumber,
              bytes: file.lengthSync(),
            ),
          );
        }
      }

      downloads.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
      return downloads;
    } catch (e) {
      AppLogger.warning('Could not list downloads: $e');
      return const [];
    }
  }

  Future<int> totalBytes() async {
    final downloads = await listDownloads();
    return downloads.fold<int>(0, (total, item) => total + item.bytes);
  }

  Future<void> deleteAll() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/$_folder');
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  /// `12.4 MB`, for the storage line in the UI.
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
