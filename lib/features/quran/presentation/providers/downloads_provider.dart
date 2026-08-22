import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio_download_service.dart';

final audioDownloadServiceProvider = Provider<AudioDownloadService>(
  (ref) => AudioDownloadService(),
);

/// How far one download has got.
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  /// Bytes on disk so far.
  final int received;

  /// Bytes expected, or -1 when the server never said.
  final int total;

  /// Null when the size is unknown, which is the common case: the bar should
  /// then be indeterminate rather than frozen at zero.
  double? get ratio =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  String get receivedLabel => _mb(received);

  String? get totalLabel => total > 0 ? _mb(total) : null;

  static String _mb(int bytes) {
    if (bytes >= 1000000) {
      return '${(bytes / 1000000).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1000).round()} KB';
  }
}

/// What is downloaded, what is downloading, and how much space it takes.
class DownloadsState {
  const DownloadsState({
    this.downloads = const [],
    this.progress = const {},
    this.queue = const [],
    this.totalBytes = 0,
  });

  final List<DownloadedSurah> downloads;

  /// `reciter/surah` -> bytes so far, while a download is running.
  final Map<String, DownloadProgress> progress;

  /// Keys waiting their turn, in order.
  final List<String> queue;

  final int totalBytes;

  bool has(String reciterCode, int surahNumber) => downloads.any(
    (item) =>
        item.reciterCode == reciterCode && item.surahNumber == surahNumber,
  );

  DownloadProgress? progressOf(String reciterCode, int surahNumber) =>
      progress['$reciterCode/$surahNumber'];

  bool isQueued(String reciterCode, int surahNumber) =>
      queue.contains('$reciterCode/$surahNumber');

  bool isBusy(String reciterCode, int surahNumber) =>
      progressOf(reciterCode, surahNumber) != null ||
      isQueued(reciterCode, surahNumber);

  DownloadsState copyWith({
    List<DownloadedSurah>? downloads,
    Map<String, DownloadProgress>? progress,
    List<String>? queue,
    int? totalBytes,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      progress: progress ?? this.progress,
      queue: queue ?? this.queue,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class DownloadsNotifier extends AsyncNotifier<DownloadsState> {
  final Map<String, CancelToken> _tokens = {};
  bool _draining = false;

  AudioDownloadService get _service => ref.read(audioDownloadServiceProvider);

  @override
  Future<DownloadsState> build() => _load();

  Future<DownloadsState> _load() async {
    final downloads = await _service.listDownloads();
    return DownloadsState(
      downloads: downloads,
      totalBytes: downloads.fold<int>(0, (total, item) => total + item.bytes),
      progress: state.value?.progress ?? const {},
      queue: state.value?.queue ?? const [],
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _load());
  }

  /// Queue one surah. Safe to call for a whole list.
  Future<void> download(String reciterCode, int surahNumber) =>
      downloadAll(reciterCode, [surahNumber]);

  /// Queue several surahs for the same reciter and work through them.
  ///
  /// They run one at a time on purpose: a dozen parallel streams on a phone
  /// connection finish no sooner and each one crawls, which reads as a hung
  /// download.
  Future<void> downloadAll(String reciterCode, List<int> surahNumbers) async {
    // Nothing can be kept in a browser, and queueing a hundred downloads that
    // each fail instantly looks exactly like a hundred downloads in progress.
    if (!AudioDownloadService.isSupported) {
      return;
    }

    final current = state.value ?? const DownloadsState();
    final fresh = <String>[
      for (final surah in surahNumbers)
        if (!current.isBusy(reciterCode, surah) &&
            !current.has(reciterCode, surah))
          '$reciterCode/$surah',
    ];
    if (fresh.isEmpty) {
      return;
    }

    _setQueue([...current.queue, ...fresh]);
    if (!_draining) {
      await _drain();
    }
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      while (true) {
        final queue = state.value?.queue ?? const <String>[];
        if (queue.isEmpty) {
          break;
        }

        final key = queue.first;
        _setQueue(queue.sublist(1));

        final parts = key.split('/');
        final reciterCode = parts[0];
        final surahNumber = int.tryParse(parts[1]);
        if (surahNumber == null) {
          continue;
        }

        final token = CancelToken();
        _tokens[key] = token;
        _setProgress(key, const DownloadProgress(received: 0, total: -1));

        final ok = await _service.download(
          reciterCode: reciterCode,
          surahNumber: surahNumber,
          cancelToken: token,
          onProgress:
              (received, total) => _setProgress(
                key,
                DownloadProgress(received: received, total: total),
              ),
        );

        _tokens.remove(key);
        _clearProgress(key);
        if (ok) {
          await refresh();
        }
      }
    } finally {
      _draining = false;
    }
  }

  void cancel(String reciterCode, int surahNumber) {
    final key = '$reciterCode/$surahNumber';
    _tokens.remove(key)?.cancel('cancelled by user');
    final queue = List<String>.from(state.value?.queue ?? const <String>[])
      ..remove(key);
    _setQueue(queue);
    _clearProgress(key);
  }

  /// Stop everything, queued or running.
  void cancelAll() {
    for (final token in _tokens.values) {
      token.cancel('cancelled by user');
    }
    _tokens.clear();
    _setQueue(const []);
    final current = state.value ?? const DownloadsState();
    state = AsyncData(current.copyWith(progress: const {}));
  }

  Future<void> delete(String reciterCode, int surahNumber) async {
    await _service.delete(reciterCode, surahNumber);
    await refresh();
  }

  Future<void> deleteAll() async {
    cancelAll();
    await _service.deleteAll();
    await refresh();
  }

  void _setProgress(String key, DownloadProgress value) {
    final current = state.value ?? const DownloadsState();
    state = AsyncData(
      current.copyWith(progress: {...current.progress, key: value}),
    );
  }

  void _clearProgress(String key) {
    final current = state.value ?? const DownloadsState();
    final progress = Map<String, DownloadProgress>.from(current.progress)
      ..remove(key);
    state = AsyncData(current.copyWith(progress: progress));
  }

  void _setQueue(List<String> queue) {
    final current = state.value ?? const DownloadsState();
    state = AsyncData(current.copyWith(queue: queue));
  }
}

final downloadsProvider =
    AsyncNotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
    );
