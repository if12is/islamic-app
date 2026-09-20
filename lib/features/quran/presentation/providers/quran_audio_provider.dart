import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../../core/services/app_audio.dart';
import '../../../../core/services/quran_media.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/services/ayah_timing_service.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/reciter_catalogue.dart';
import '../../data/services/verse_reciters.dart';
import '../../data/services/verse_voices.dart';
import '../../domain/entities/riwaya.dart';
import 'reader_settings_provider.dart';

/// Whether a saved reciter id can be cut at the ayah, or only played as a surah.
///
/// The voices themselves live in [ReciterCatalogue] and [VerseReciters]. This
/// type is only the questions playback asks before building a URL, so a
/// whole-surah id is never requested as a verse.
class QuranReciter {
  QuranReciter._();

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

  /// Bumped on every queue build, so a slower one cannot overwrite a newer.
  int _loadRun = 0;

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

    // Radio or a whole surah taking the player leaves this controller showing
    // a queue for audio that stopped.
    final ownerSub = AppAudio.ownerChanges.listen((owner) {
      if (owner != AudioOwner.verses && state.hasQueue) {
        // And drop a queue still being built, or it will take the player
        // back from whatever just claimed it.
        _loadRun++;
        _sleepTimer?.cancel();
        _queueVerses = const [];
        state = QuranAudioState(
          speed: state.speed,
          reciterCode: state.reciterCode,
          repeatVerse: state.repeatVerse,
        );
      }
    });

    ref.onDispose(() {
      _sleepTimer?.cancel();
      playingSub.cancel();
      indexSub.cancel();
      stateSub.cancel();
      ownerSub.cancel();
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
    if (verses.isEmpty) {
      AppLogger.warning('Nothing to recite');
      state = state.copyWith(loading: false, playing: false);
      return;
    }

    // Which build this is.
    //
    // Everything below waits — the session, the artwork, the catalogue, the
    // voice, and a network round trip per verse for a clipped recording. Tap
    // one ayah and then another while the first is still resolving and both
    // runs would write the queue, the index and the player's sources, with
    // the slower one winning. The reader would be left listening to the ayah
    // they did not tap.
    final run = ++_loadRun;
    bool stale() => run != _loadRun;

    try {
      _previousIndex = initialIndex;
      _queueVerses = verses;
      _loopMode = loopMode;
      state = state.copyWith(
        loading: true,
        queue: verses.map((verse) => verse.key).toList(),
        reciterCode: reciterCode,
      );

      AppAudio.claim(AudioOwner.verses);
      await QuranMedia.prepareSession();
      final art = await QuranMedia.coverUri();
      // Resolve the voice against the reading, not just against the list.
      //
      // The plain fallback answers "no per-ayah audio" with al-Afasy, who
      // recites Hafs. For a reader on the Warsh mushaf that is the original
      // complaint in its last hiding place: a saved whole-surah id, nothing to
      // play it with, and Hafs over a Warsh page without a word said.
      final edition = ref.read(readerSettingsProvider).edition;
      final voice = await VerseVoices.resolve(
        savedId: reciterCode,
        edition: edition,
        voices: await ReciterCatalogue.load(),
        surahNumber: verses.first.surahNumber,
      );
      if (stale()) {
        return;
      }
      if (voice == null) {
        // Nothing in this reading can be cut at the ayah. Silence is the
        // honest answer; reciting another reading is not.
        AppLogger.warning('No verse audio for ${edition.id}');
        _abandon();
        return;
      }
      // Build the queue and the verse list together.
      //
      // A clipped recording can be missing a mark for a verse, and dropping
      // that source alone would leave the player's index one ahead of the
      // reader's — every highlight, every repeat and every "current ayah"
      // off by one for the rest of the surah. The two lists are built from
      // the same loop so they cannot drift.
      final wanted = initialIndex.clamp(0, verses.length - 1);
      final playable = <QuranVerse>[];
      final sources = <AudioSource>[];
      // Where the verse that was asked for ends up once the unplayable ones
      // are gone. Counted as the list is built rather than searched for
      // afterwards, because two verses of one surah can be equal by value and
      // a search would answer with the first of them.
      var start = 0;
      for (var index = 0; index < verses.length; index++) {
        final source = await _sourceFor(verses[index], voice, art);
        if (stale()) {
          return;
        }
        if (source == null) {
          continue;
        }
        if (index <= wanted) {
          start = playable.length;
        }
        playable.add(verses[index]);
        sources.add(source);
      }
      if (sources.isEmpty) {
        AppLogger.warning('No playable verses for ${voice.id}');
        _abandon();
        return;
      }

      _queueVerses = playable;
      _previousIndex = start;
      state = state.copyWith(
        reciterCode: voice.id,
        queue: playable.map((verse) => verse.key).toList(),
      );
      await _player.setAudioSources(sources, initialIndex: start);
      await _player.setSpeed(state.speed);
      await _player.setLoopMode(loopMode);
      await _player.play();
    } catch (e, stack) {
      AppLogger.error('Verse playback failed', e, stack);
      // Only if this is still the build in charge. An abandoned run failing
      // must not report failure over the one that replaced it, which may be
      // playing perfectly well by now.
      if (!stale()) {
        state = state.copyWith(loading: false, playing: false);
      }
    }
  }

  /// Give up on a queue that was announced but cannot be built.
  ///
  /// The queue and the reciter were written into the state before the sources
  /// were resolved, so leaving them there points the reader at a passage the
  /// player never loaded: the highlight and the auto-scroll would follow the
  /// old recording's index into the new list, an ayah at a time, wrongly.
  void _abandon() {
    _queueVerses = const [];
    _previousIndex = null;
    state = state.copyWith(
      loading: false,
      playing: false,
      queue: const [],
      clearIndex: true,
      clearRange: true,
    );
  }

  /// One ayah, however this voice is able to give it.
  ///
  /// A per-ayah voice is a file. A whole-surah voice is the same file everyone
  /// else streams, clipped to the marks the provider publishes — which is what
  /// lets a reading with no per-ayah corpus, such as Qalun, have ayah
  /// playback at all.
  Future<AudioSource?> _sourceFor(
    QuranVerse verse,
    PlayableVerseVoice voice,
    Uri? art,
  ) async {
    final tag = MediaItem(
      id: '${voice.id}_${verse.key}',
      album: QuranMedia.albumName,
      title: 'سورة ${verse.surahNameAr} · الآية ${verse.numberInSurah}',
      artist: voice.nameAr,
      displayTitle: 'سورة ${verse.surahNameAr} · الآية ${verse.numberInSurah}',
      displaySubtitle: voice.nameAr,
      artUri: art,
    );

    // Which number this particular recording answers to.
    //
    // A reading and a recording of it do not have to agree on where the
    // verses end, and two of the three Warsh recitations on the per-ayah host
    // are filed under Hafs numbers. Asking one of those for a Warsh verse
    // number does not fail — it returns the ayah next door, and goes on doing
    // it — so the number to ask for is chosen by the recording's counting.
    final number =
        voice.counting == VerseCounting.hafs
            ? verse.hafsVerseNumber
            : verse.numberInSurah;

    final clip = voice.clip;
    if (clip == null) {
      return AudioSource.uri(
        Uri.parse(
          QuranLocalService.audioUrlForVerse(
            verse.surahNumber,
            number,
            reciterCode: voice.id,
          ),
        ),
        tag: tag,
      );
    }

    final url = clip.urlFor(verse.surahNumber);
    if (url == null) {
      return null;
    }
    final marks = await AyahTimingService.forSurah(
      clip.moshafId!,
      verse.surahNumber,
    );
    final mark = AyahTimingService.find(marks, number);
    if (mark == null) {
      return null;
    }
    return ClippingAudioSource(
      child: AudioSource.uri(Uri.parse(url)),
      start: mark.start,
      end: mark.end,
      tag: tag,
    );
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
    // Abandon any queue still being resolved.
    //
    // Building one takes a round trip per verse for a clipped recording, so
    // there is a real window in which the reader presses stop, or starts a
    // whole-surah recitation, and a build that began before that finishes
    // afterwards — and starts playing what they just stopped.
    _loadRun++;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _previousIndex = null;
    _queueVerses = const [];
    // Or the next queue starts looping because the last one did.
    _loopMode = LoopMode.off;
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
    final asked = _queueVerses;

    await _load(
      asked,
      initialIndex: resumeIndex,
      reciterCode: code,
      loopMode: _loopMode,
    );

    // Land on roughly the same spot inside the verse.
    //
    // Against the queue that came back, not the one that went in: the new
    // voice may not carry every verse the old one did, so `_load` rebuilds
    // both the sources and `_queueVerses`, and the index that was current a
    // moment ago can be past the end of the new list. Seeking to it throws.
    final landed = _previousIndex ?? 0;
    if (position > Duration.zero && landed < _queueVerses.length) {
      await _player.seek(position, index: landed);
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
