import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../../core/services/app_audio.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/services/quran_local_service.dart';

/// Reciters available for verse-by-verse playback (islamic.network CDN).
class QuranReciter {
  const QuranReciter({
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });

  final String code;
  final String nameAr;
  final String nameEn;

  static const List<QuranReciter> all = [
    QuranReciter(
      code: 'ar.alafasy',
      nameAr: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
    ),
    QuranReciter(
      code: 'ar.mahermuaiqly',
      nameAr: 'ماهر المعيقلي',
      nameEn: 'Maher Al Muaiqly',
    ),
    QuranReciter(
      code: 'ar.husary',
      nameAr: 'محمود الحصري',
      nameEn: 'Mahmoud Al-Husary',
    ),
    QuranReciter(
      code: 'ar.minshawi',
      nameAr: 'محمد المنشاوي',
      nameEn: 'Al-Minshawi',
    ),
    QuranReciter(
      code: 'ar.abdurrahmaansudais',
      nameAr: 'عبدالرحمن السديس',
      nameEn: 'Abdurrahman As-Sudais',
    ),
    QuranReciter(
      code: 'ar.shaatree',
      nameAr: 'أبو بكر الشاطري',
      nameEn: 'Abu Bakr Ash-Shaatree',
    ),
    QuranReciter(
      code: 'ar.ahmedajamy',
      nameAr: 'أحمد العجمي',
      nameEn: 'Ahmed Al-Ajamy',
    ),
  ];

  static QuranReciter byCode(String code) {
    for (final reciter in all) {
      if (reciter.code == code) {
        return reciter;
      }
    }
    return QuranReciter(code: code, nameAr: code, nameEn: code);
  }

  /// Verse-by-verse files live on the islamic.network CDN, which only knows
  /// the bundled edition codes. A catalogue id such as `mp3quran:92:92` is a
  /// whole-surah recording and would 404 (and crash the reciter dropdown).
  static bool hasVerseAudio(String code) =>
      all.any((reciter) => reciter.code == code);

  static String verseAudioCode(String code) =>
      hasVerseAudio(code) ? code : all.first.code;

  /// Whether this voice has whole-surah recordings, as opposed to verse audio.
  static bool hasSurahAudio(String code) =>
      QuranLocalService.hasSurahAudio(code);
}

/// What the reader needs to know about playback right now.
class QuranAudioState {
  const QuranAudioState({
    this.queue = const [],
    this.currentIndex,
    this.playing = false,
    this.loading = false,
    this.speed = 1.0,
    this.repeatVerse = false,
    this.reciterCode = 'ar.alafasy',
    this.rangeLabel,
    this.repeatTarget = 0,
    this.repeatsDone = 0,
    this.sleepTimerEndsAt,
    this.stopAtEndOfQueue = false,
  });

  /// Verse keys (`2:255`) in playback order.
  final List<String> queue;
  final int? currentIndex;
  final bool playing;
  final bool loading;
  final double speed;
  final bool repeatVerse;
  final String reciterCode;

  /// `٢:٢٥٥ — ٢:٢٥٧` while a memorisation range is loaded.
  final String? rangeLabel;

  /// How many times the range should repeat (0 = no range repetition).
  final int repeatTarget;
  final int repeatsDone;

  /// When playback will pause itself, if a sleep timer is running.
  final DateTime? sleepTimerEndsAt;

  /// Stop when the loaded passage finishes (the "end of surah" timer).
  final bool stopAtEndOfQueue;

  String? get currentKey =>
      (currentIndex != null && currentIndex! < queue.length)
          ? queue[currentIndex!]
          : null;

  bool get hasQueue => queue.isNotEmpty;

  bool get isRepeatingRange => repeatTarget > 0;

  bool get hasSleepTimer => sleepTimerEndsAt != null || stopAtEndOfQueue;

  Duration? get sleepTimerRemaining {
    final ends = sleepTimerEndsAt;
    if (ends == null) {
      return null;
    }
    final remaining = ends.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  QuranAudioState copyWith({
    List<String>? queue,
    int? currentIndex,
    bool clearIndex = false,
    bool? playing,
    bool? loading,
    double? speed,
    bool? repeatVerse,
    String? reciterCode,
    String? rangeLabel,
    bool clearRange = false,
    int? repeatTarget,
    int? repeatsDone,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    bool? stopAtEndOfQueue,
  }) {
    return QuranAudioState(
      queue: queue ?? this.queue,
      currentIndex: clearIndex ? null : (currentIndex ?? this.currentIndex),
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      speed: speed ?? this.speed,
      repeatVerse: repeatVerse ?? this.repeatVerse,
      reciterCode: reciterCode ?? this.reciterCode,
      rangeLabel: clearRange ? null : (rangeLabel ?? this.rangeLabel),
      repeatTarget: clearRange ? 0 : (repeatTarget ?? this.repeatTarget),
      repeatsDone: clearRange ? 0 : (repeatsDone ?? this.repeatsDone),
      sleepTimerEndsAt:
          clearSleepTimer ? null : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
      stopAtEndOfQueue:
          clearSleepTimer ? false : (stopAtEndOfQueue ?? this.stopAtEndOfQueue),
    );
  }
}

/// One shared player for the whole app, so background playback and the
/// lock-screen controls always refer to the same session.
///
/// It is not disposed with the provider: the adhan preview and the media
/// notification hold the same instance, and tearing it down when a Quran screen
/// closes would take those with it.
final quranAudioPlayerProvider = Provider<AudioPlayer>(
  (ref) => AppAudio.player,
);

/// Verse-by-verse recitation that the reader can follow along with.
///
/// Beyond plain playback it carries the two things a memoriser needs: a
/// repeating range with a target number of passes, and a sleep timer.
class QuranAudioController extends Notifier<QuranAudioState> {
  AudioPlayer get _player => ref.read(quranAudioPlayerProvider);

  Timer? _sleepTimer;
  int? _previousIndex;

  /// The verses currently loaded, kept so switching reciter can rebuild the
  /// same passage instead of dropping playback.
  List<QuranVerse> _queueVerses = const [];
  LoopMode _loopMode = LoopMode.off;

  @override
  QuranAudioState build() {
    final playingSub = _player.playingStream.listen((playing) {
      state = state.copyWith(playing: playing);
    });

    final indexSub = _player.currentIndexStream.listen(_onIndexChanged);

    final stateSub = _player.playerStateStream.listen((playerState) {
      final loading =
          playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering;
      state = state.copyWith(loading: loading);

      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(playing: false);
        if (state.stopAtEndOfQueue) {
          unawaited(stop());
        }
      }
    });

    ref.onDispose(() {
      _sleepTimer?.cancel();
      playingSub.cancel();
      indexSub.cancel();
      stateSub.cancel();
    });

    return const QuranAudioState();
  }

  /// Counts a completed pass whenever a repeating range wraps around.
  void _onIndexChanged(int? index) {
    final previous = _previousIndex;
    _previousIndex = index;
    state = state.copyWith(currentIndex: index);

    if (!state.isRepeatingRange || index == null || previous == null) {
      return;
    }

    final wrapped = index == 0 && previous == state.queue.length - 1;
    if (!wrapped) {
      return;
    }

    final done = state.repeatsDone + 1;
    state = state.copyWith(repeatsDone: done);

    if (done >= state.repeatTarget) {
      unawaited(_player.pause());
      unawaited(_player.setLoopMode(LoopMode.off));
      state = state.copyWith(playing: false);
    }
  }

  /// Load [verses] and start at [startIndex].
  ///
  /// The queue is the passage the reader currently has open (a surah, juz,
  /// hizb, or page), so "play from here" continues to the end of it.
  Future<void> playVerses(
    List<QuranVerse> verses, {
    int startIndex = 0,
    required String reciterCode,
  }) async {
    if (verses.isEmpty) {
      return;
    }

    state = state.copyWith(clearRange: true);
    await _load(
      verses,
      initialIndex: startIndex.clamp(0, verses.length - 1),
      reciterCode: reciterCode,
      loopMode: state.repeatVerse ? LoopMode.one : LoopMode.off,
    );
  }

  /// Repeat a passage a set number of times — the memorisation loop.
  ///
  /// [fromIndex] and [toIndex] are positions inside [verses]; [repeatCount]
  /// is how many full passes to play before stopping (0 keeps looping).
  Future<void> playRange(
    List<QuranVerse> verses, {
    required int fromIndex,
    required int toIndex,
    required int repeatCount,
    required String reciterCode,
  }) async {
    if (verses.isEmpty) {
      return;
    }

    final start = fromIndex.clamp(0, verses.length - 1);
    final end = toIndex.clamp(start, verses.length - 1);
    final slice = verses.sublist(start, end + 1);

    state = state.copyWith(
      repeatTarget: repeatCount,
      repeatsDone: 0,
      rangeLabel: '${slice.first.key} — ${slice.last.key}',
    );

    await _load(
      slice,
      initialIndex: 0,
      reciterCode: reciterCode,
      loopMode: LoopMode.all,
    );
  }

  Future<void> _load(
    List<QuranVerse> verses, {
    required int initialIndex,
    required String reciterCode,
    required LoopMode loopMode,
  }) async {
    try {
      _previousIndex = initialIndex;
      _queueVerses = verses;
      _loopMode = loopMode;
      state = state.copyWith(
        loading: true,
        queue: verses.map((verse) => verse.key).toList(),
        reciterCode: reciterCode,
      );

      final verseCode = QuranReciter.verseAudioCode(reciterCode);
      final sources = [
        for (final verse in verses)
          AudioSource.uri(
            Uri.parse(
              QuranLocalService.audioUrlForVerse(
                verse.surahNumber,
                verse.numberInSurah,
                reciterCode: verseCode,
              ),
            ),
            tag: MediaItem(
              id: '${verseCode}_${verse.key}',
              album: verse.surahNameAr,
              title: 'الآية ${verse.numberInSurah}',
              artist: QuranReciter.byCode(verseCode).nameAr,
            ),
          ),
      ];

      await _player.setAudioSources(sources, initialIndex: initialIndex);
      await _player.setSpeed(state.speed);
      await _player.setLoopMode(loopMode);
      await _player.play();
    } catch (e, stack) {
      AppLogger.error('Verse playback failed', e, stack);
      state = state.copyWith(loading: false, playing: false);
    }
  }

  Future<void> toggle() async {
    if (!state.hasQueue) {
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
    _previousIndex = null;
    _queueVerses = const [];
    await _player.stop();
    await _player.setLoopMode(LoopMode.off);
    state = state.copyWith(
      playing: false,
      queue: const [],
      clearIndex: true,
      clearRange: true,
      clearSleepTimer: true,
    );
  }

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  Future<void> setSpeed(double speed) async {
    final safe = speed.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(speed: safe);
    await _player.setSpeed(safe);
  }

  /// Repeat the current verse — the simplest memorisation loop.
  Future<void> setRepeatVerse(bool repeat) async {
    state = state.copyWith(repeatVerse: repeat);
    if (!state.isRepeatingRange) {
      await _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
    }
  }

  /// Pause playback after [duration]; pass null to cancel the timer.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();

    if (duration == null) {
      _sleepTimer = null;
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    state = state.copyWith(
      sleepTimerEndsAt: DateTime.now().add(duration),
      stopAtEndOfQueue: false,
    );
    _sleepTimer = Timer(duration, () async {
      await _player.pause();
      state = state.copyWith(playing: false, clearSleepTimer: true);
    });
  }

  /// Stop when the current passage ends instead of after a fixed time.
  void stopAtEndOfPassage() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    // Clear any countdown first, then arm the end-of-passage stop.
    state = state.copyWith(clearSleepTimer: true);
    state = state.copyWith(stopAtEndOfQueue: true);
  }

  /// Switch voice without losing your place.
  ///
  /// The queue is rebuilt with the new reciter's files and resumes at the same
  /// verse, playing again if it was playing — changing reciter mid-listen
  /// should sound like the voice changed, not like playback stopped.
  Future<void> setReciter(String code) async {
    if (code == state.reciterCode) {
      return;
    }

    state = state.copyWith(reciterCode: code);

    if (_queueVerses.isEmpty) {
      return;
    }

    final resumeIndex = (state.currentIndex ?? 0).clamp(
      0,
      _queueVerses.length - 1,
    );
    final wasPlaying = _player.playing;
    final position = _player.position;

    await _load(
      _queueVerses,
      initialIndex: resumeIndex,
      reciterCode: code,
      loopMode: _loopMode,
    );

    // Land on roughly the same spot inside the verse.
    if (position > Duration.zero) {
      await _player.seek(position, index: resumeIndex);
    }
    if (!wasPlaying) {
      await _player.pause();
    }
  }
}

final quranAudioProvider =
    NotifierProvider<QuranAudioController, QuranAudioState>(
      QuranAudioController.new,
    );
