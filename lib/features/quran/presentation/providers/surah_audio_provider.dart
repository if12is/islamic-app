import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/quran_media.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/services/audio_download_service.dart';
import '../../data/services/quran_local_service.dart';
import 'quran_audio_provider.dart';

/// What is playing, when a whole surah is playing.
///
/// This used to live inside the Quran screen's own State, which meant the
/// session existed only while that screen did: switching tabs threw away the
/// bar, the reciter, and the sleep timer, even though the audio itself kept
/// going in the background. Holding it in a provider is what lets a full
/// player and a mini bar be two views of one thing rather than two players.
class SurahPlaybackState {
  const SurahPlaybackState({
    this.surahNumber,
    this.reciterId = 'ar.alafasy',
    this.loading = false,
    this.playing = false,
    this.repeatSurah = false,
    this.speed = 1.0,
    this.sleepTimerEndsAt,
    this.stopAtEnd = false,
    this.errorKey,
    this.errorDetail,
    this.queue = const [],
    this.queueIndex = 0,
    this.playlistId,
  });

  /// Null when nothing is loaded — the bar and the full player both hide.
  final int? surahNumber;

  /// The surahs lined up after this one, when a listening list is running.
  /// Empty means a single surah, where next and previous walk the Mushaf.
  final List<int> queue;
  final int queueIndex;

  /// Which saved list is running, so finishing it can be recorded.
  final String? playlistId;

  bool get hasQueue => queue.length > 1;

  final String reciterId;
  final bool loading;
  final bool playing;
  final bool repeatSurah;
  final double speed;

  final DateTime? sleepTimerEndsAt;

  /// Stop when this surah finishes rather than after a set time.
  final bool stopAtEnd;

  /// Set once when playback fails, so the screen can say so and then clear it.
  final String? errorKey;
  final String? errorDetail;

  bool get hasSurah => surahNumber != null;

  bool get hasSleepTimer => sleepTimerEndsAt != null || stopAtEnd;

  Duration? get sleepTimerRemaining {
    final ends = sleepTimerEndsAt;
    if (ends == null) {
      return null;
    }
    final left = ends.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  SurahPlaybackState copyWith({
    int? surahNumber,
    bool clearSurah = false,
    String? reciterId,
    bool? loading,
    bool? playing,
    bool? repeatSurah,
    double? speed,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    bool? stopAtEnd,
    String? errorKey,
    String? errorDetail,
    bool clearError = false,
    List<int>? queue,
    int? queueIndex,
    String? playlistId,
    bool clearQueue = false,
  }) {
    return SurahPlaybackState(
      surahNumber: clearSurah ? null : (surahNumber ?? this.surahNumber),
      reciterId: reciterId ?? this.reciterId,
      loading: loading ?? this.loading,
      playing: playing ?? this.playing,
      repeatSurah: repeatSurah ?? this.repeatSurah,
      speed: speed ?? this.speed,
      sleepTimerEndsAt:
          clearSleepTimer ? null : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
      stopAtEnd: clearSleepTimer ? false : (stopAtEnd ?? this.stopAtEnd),
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      queue: clearQueue ? const [] : (queue ?? this.queue),
      queueIndex: clearQueue ? 0 : (queueIndex ?? this.queueIndex),
      playlistId: clearQueue ? null : (playlistId ?? this.playlistId),
    );
  }
}

/// Whole-surah playback: one recording at a time, on the shared player.
class SurahAudioController extends Notifier<SurahPlaybackState> {
  AudioPlayer get _player => ref.read(quranAudioPlayerProvider);
  final AudioDownloadService _downloads = AudioDownloadService();

  Timer? _sleepTimer;

  /// Guards two reciter switches racing: tapping through voices faster than
  /// they load used to let the loser overwrite the winner.
  int _switchToken = 0;

  /// Never seek exactly onto the end; a player treats that as "finished".
  static const Duration seekTailGuard = Duration(seconds: 2);

  @override
  SurahPlaybackState build() {
    final playingSub = _player.playingStream.listen((playing) {
      if (state.hasSurah) {
        state = state.copyWith(playing: playing);
      }
    });

    final stateSub = _player.playerStateStream.listen((playerState) {
      if (!state.hasSurah) {
        return;
      }
      final loading =
          playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering;
      state = state.copyWith(loading: loading);

      if (playerState.processingState == ProcessingState.completed) {
        _onFinished();
      }
    });

    ref.onDispose(() {
      _sleepTimer?.cancel();
      playingSub.cancel();
      stateSub.cancel();
    });

    return const SurahPlaybackState();
  }

  void _onFinished() {
    if (state.repeatSurah) {
      unawaited(_player.seek(Duration.zero));
      unawaited(_player.play());
      return;
    }
    // A sleep timer set to "end of this surah" beats the queue: it was set by
    // someone who is falling asleep, not someone who wants the next surah.
    if (state.stopAtEnd) {
      unawaited(stop());
      return;
    }
    if (state.queueIndex < state.queue.length - 1) {
      unawaited(_advanceQueue());
      return;
    }
    if (state.hasQueue) {
      // The list has run to the end. Whoever cares that it finished — the
      // listening wird — is told once, here.
      final finished = state.playlistId;
      if (finished != null) {
        _onPlaylistFinished?.call(finished);
      }
    }
    state = state.copyWith(playing: false);
  }

  /// Called with the playlist id when a saved list plays through to its end.
  void Function(String playlistId)? _onPlaylistFinished;

  // ignore: use_setters_to_change_properties
  void onPlaylistFinished(void Function(String playlistId)? callback) {
    _onPlaylistFinished = callback;
  }

  Future<void> _advanceQueue() async {
    final next = state.queueIndex + 1;
    if (next >= state.queue.length) {
      return;
    }
    state = state.copyWith(queueIndex: next);
    await _load(state.queue[next], state.reciterId);
  }

  /// Play a saved listening list from [startIndex].
  Future<void> playQueue(
    List<int> surahs, {
    int startIndex = 0,
    String? playlistId,
    String? reciterId,
  }) async {
    final ordered = [
      for (final number in surahs)
        if (number >= 1 && number <= QuranLocalService.surahCount) number,
    ];
    if (ordered.isEmpty) {
      return;
    }

    final index = startIndex.clamp(0, ordered.length - 1);
    state = state.copyWith(
      queue: ordered,
      queueIndex: index,
      playlistId: playlistId,
      reciterId: reciterId ?? state.reciterId,
      clearError: true,
    );
    await _load(ordered[index], reciterId ?? state.reciterId);
  }

  /// Start [surahNumber] on its own, or pause/resume it when already loaded.
  ///
  /// Starting one surah ends whatever list was running: a tap on a surah in
  /// the index means "play this", not "insert this into my playlist".
  Future<bool> play(int surahNumber, {String? reciterId}) async {
    final voice = reciterId ?? state.reciterId;

    if (state.surahNumber == surahNumber && reciterId == null) {
      await toggle();
      return true;
    }

    state = state.copyWith(clearQueue: true);
    return _load(surahNumber, voice);
  }

  Future<bool> _load(int surahNumber, String voice) async {
    state = state.copyWith(
      surahNumber: surahNumber,
      reciterId: voice,
      loading: true,
      clearError: true,
    );

    try {
      final name = QuranLocalService.surahInfo(surahNumber).nameAr;
      // A downloaded surah plays from storage; otherwise stream it.
      final source = await _downloads.sourceFor(voice, surahNumber);
      await QuranMedia.prepareSession();
      final tag = await QuranMedia.item(
        id: 'surah_${surahNumber}_$voice',
        title: 'سورة $name',
        artist: displayNameFor(voice),
      );

      await _player.setAudioSource(
        source.startsWith('http')
            ? AudioSource.uri(Uri.parse(source), tag: tag)
            : AudioSource.file(source, tag: tag),
      );
      await _player.setSpeed(state.speed);
      await _player.setLoopMode(LoopMode.off);
      await _player.play();
      state = state.copyWith(loading: false);
      return true;
    } catch (e, stack) {
      AppLogger.error('Surah playback failed', e, stack);
      final (key, detail) = describeFailure(e);
      state = state.copyWith(
        clearSurah: true,
        loading: false,
        playing: false,
        errorKey: key,
        errorDetail: detail,
      );
      return false;
    }
  }

  /// Switch voice and land in roughly the same place in the recitation.
  ///
  /// Two reciters never record a surah at the same length, so the old position
  /// is a hint rather than an instruction: seeking straight to it lands past
  /// the end of a shorter recitation, which the player reports as "completed"
  /// — the surah went silent the moment the voice was changed.
  Future<void> setReciter(String reciterId) async {
    if (reciterId == state.reciterId) {
      return;
    }

    final surah = state.surahNumber;
    if (surah == null) {
      state = state.copyWith(reciterId: reciterId);
      return;
    }

    final token = ++_switchToken;
    final wasPlaying = _player.playing;
    final position = _player.position;
    final previousDuration = _player.duration;

    // _load, not play: changing voice must not drop the listening list that
    // is running.
    final loaded = await _load(surah, reciterId);
    if (!loaded || token != _switchToken) {
      return;
    }

    final duration = _player.duration;
    if (position > Duration.zero && duration != null) {
      // Keep the same fraction of the recitation rather than the same second:
      // it lands on roughly the same verse whatever the pace of the reciter.
      final target =
          (previousDuration != null && previousDuration > Duration.zero)
              ? duration *
                  (position.inMilliseconds / previousDuration.inMilliseconds)
              : position;
      final safe = target < duration ? target : duration - seekTailGuard;
      await _player.seek(safe > Duration.zero ? safe : Duration.zero);
    }

    if (!wasPlaying) {
      await _player.pause();
    }
  }

  Future<void> toggle() async {
    if (!state.hasSurah) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    await _player.stop();
    state = state.copyWith(
      clearSurah: true,
      playing: false,
      loading: false,
      clearSleepTimer: true,
      clearQueue: true,
    );
  }

  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    final safe =
        duration != null && position >= duration
            ? duration - seekTailGuard
            : position;
    await _player.seek(safe > Duration.zero ? safe : Duration.zero);
  }

  /// Jump [offset] from where we are, clamped to the recording.
  Future<void> skip(Duration offset) async {
    final duration = _player.duration ?? Duration.zero;
    final target = _player.position + offset;
    if (target <= Duration.zero) {
      await _player.seek(Duration.zero);
      return;
    }
    if (duration > Duration.zero && target >= duration) {
      await _player.seek(duration - seekTailGuard);
      return;
    }
    await _player.seek(target);
  }

  /// Next in the list if one is running, otherwise next in the Mushaf.
  Future<void> nextSurah() async {
    if (state.hasQueue) {
      if (state.queueIndex < state.queue.length - 1) {
        await _advanceQueue();
      }
      return;
    }

    final current = state.surahNumber;
    if (current == null || current >= QuranLocalService.surahCount) {
      return;
    }
    await _load(current + 1, state.reciterId);
  }

  Future<void> previousSurah() async {
    final current = state.surahNumber;
    if (current == null) {
      return;
    }
    // The first press restarts the surah, as every media player does; only a
    // second one within the opening seconds goes back one.
    if (_player.position > const Duration(seconds: 4)) {
      await _player.seek(Duration.zero);
      return;
    }

    if (state.hasQueue) {
      if (state.queueIndex == 0) {
        await _player.seek(Duration.zero);
        return;
      }
      final index = state.queueIndex - 1;
      state = state.copyWith(queueIndex: index);
      await _load(state.queue[index], state.reciterId);
      return;
    }

    if (current <= 1) {
      await _player.seek(Duration.zero);
      return;
    }
    await _load(current - 1, state.reciterId);
  }

  Future<void> setSpeed(double speed) async {
    final safe = speed.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(speed: safe);
    await _player.setSpeed(safe);
  }

  void setRepeatSurah(bool repeat) {
    state = state.copyWith(repeatSurah: repeat);
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();

    if (duration == null) {
      _sleepTimer = null;
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    state = state.copyWith(
      sleepTimerEndsAt: DateTime.now().add(duration),
      stopAtEnd: false,
    );
    _sleepTimer = Timer(duration, () async {
      await _player.pause();
      state = state.copyWith(playing: false, clearSleepTimer: true);
    });
  }

  void stopAtEndOfSurah() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(clearSleepTimer: true);
    state = state.copyWith(stopAtEnd: true);
  }

  void clearError() {
    if (state.errorKey != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// The reciter's name, whichever list it came from.
  static String displayNameFor(String reciterId) =>
      QuranReciter.byCode(reciterId).nameAr;

  /// Turn the exception into something the listener can act on.
  ///
  /// Silence with the play button still lit reads as a broken app, and "check
  /// your connection" is useless advice to someone whose connection is fine.
  static (String key, String? detail) describeFailure(Object error) {
    // just_audio wraps the platform's own failure, and its code is the HTTP
    // status when the source was refused. Reading it beats guessing from a
    // stringified class name.
    if (error is PlayerException) {
      final status = error.code;
      if (status == 403 || status == 404) {
        return ('audio_not_available', null);
      }
      return ('audio_play_failed', '$status');
    }

    final text = error.toString().toLowerCase();

    if (text.contains('socket') ||
        text.contains('host') ||
        text.contains('network') ||
        text.contains('connection')) {
      return ('audio_no_network', null);
    }
    if (text.contains('403') ||
        text.contains('404') ||
        text.contains('not found')) {
      return ('audio_not_available', null);
    }
    // A plugin that is not there is a platform gap, not a user problem.
    if (text.contains('missingplugin')) {
      return ('audio_platform_unsupported', null);
    }
    // Anything else is worth naming: an unexplained failure that names itself
    // can be reported, and one that does not cannot.
    return ('audio_play_failed', '${error.runtimeType}');
  }
}

final surahAudioProvider =
    NotifierProvider<SurahAudioController, SurahPlaybackState>(
      SurahAudioController.new,
    );
