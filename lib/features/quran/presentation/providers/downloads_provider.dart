import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio_download_service.dart';

final audioDownloadServiceProvider = Provider<AudioDownloadService>(
  (ref) => AudioDownloadService(),
);

/// What is downloaded, what is downloading, and how much space it takes.
class DownloadsState {
  const DownloadsState({
    this.downloads = const [],
    this.progress = const {},
    this.totalBytes = 0,
  });

  final List<DownloadedSurah> downloads;

  /// `reciter/surah` -> 0..1 while a download is running.
  final Map<String, double> progress;

  final int totalBytes;

  bool has(String reciterCode, int surahNumber) => downloads.any(
    (item) =>
        item.reciterCode == reciterCode && item.surahNumber == surahNumber,
  );

  double? progressOf(String reciterCode, int surahNumber) =>
      progress['$reciterCode/$surahNumber'];

  DownloadsState copyWith({
    List<DownloadedSurah>? downloads,
    Map<String, double>? progress,
    int? totalBytes,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class DownloadsNotifier extends AsyncNotifier<DownloadsState> {
  final Map<String, CancelToken> _tokens = {};

  AudioDownloadService get _service => ref.read(audioDownloadServiceProvider);

  @override
  Future<DownloadsState> build() => _load();

  Future<DownloadsState> _load() async {
    final downloads = await _service.listDownloads();
    return DownloadsState(
      downloads: downloads,
      totalBytes: downloads.fold<int>(0, (total, item) => total + item.bytes),
      progress: state.value?.progress ?? const {},
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _load());
  }

  Future<void> download(String reciterCode, int surahNumber) async {
    final key = '$reciterCode/$surahNumber';
    if (_tokens.containsKey(key)) {
      return;
    }

    final token = CancelToken();
    _tokens[key] = token;
    _setProgress(key, 0);

    final ok = await _service.download(
      reciterCode: reciterCode,
      surahNumber: surahNumber,
      cancelToken: token,
      onProgress: (value) => _setProgress(key, value),
    );

    _tokens.remove(key);
    _clearProgress(key);
    if (ok) {
      await refresh();
    }
  }

  void cancel(String reciterCode, int surahNumber) {
    final key = '$reciterCode/$surahNumber';
    _tokens.remove(key)?.cancel('cancelled by user');
    _clearProgress(key);
  }

  Future<void> delete(String reciterCode, int surahNumber) async {
    await _service.delete(reciterCode, surahNumber);
    await refresh();
  }

  Future<void> deleteAll() async {
    for (final token in _tokens.values) {
      token.cancel('cleared');
    }
    _tokens.clear();
    await _service.deleteAll();
    await refresh();
  }

  void _setProgress(String key, double value) {
    final current = state.value ?? const DownloadsState();
    state = AsyncData(
      current.copyWith(progress: {...current.progress, key: value}),
    );
  }

  void _clearProgress(String key) {
    final current = state.value ?? const DownloadsState();
    final progress = Map<String, double>.from(current.progress)..remove(key);
    state = AsyncData(current.copyWith(progress: progress));
  }
}

final downloadsProvider =
    AsyncNotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
    );
