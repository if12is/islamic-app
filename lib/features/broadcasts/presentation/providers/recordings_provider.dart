import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_audio.dart';
import '../../../../core/services/quran_media.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../quran/presentation/providers/quran_audio_provider.dart';
import '../../data/recordings_catalogue.dart';
import '../../domain/recording.dart';

/// What the recordings player shows.
class RecordingsState {
  const RecordingsState({
    this.collection,
    this.tracks = const [],
    this.index,
    this.playing = false,
    this.loading = false,
    this.errorKey,
  });

  /// Null when nothing is loaded.
  final RecordingCollection? collection;
  final List<RecordingTrack> tracks;
  final int? index;
  final bool playing;
  final bool loading;
  final String? errorKey;

  bool get isOn => collection != null && index != null;

  RecordingTrack? get current {
    final at = index;
    if (at == null || at < 0 || at >= tracks.length) {
      return null;
    }
    return tracks[at];
  }

  bool get hasNext => index != null && index! < tracks.length - 1;
  bool get hasPrevious => index != null && index! > 0;

  RecordingsState copyWith({
    int? index,
    bool? playing,
    bool? loading,
    String? errorKey,
    bool clearError = false,
  }) {
    return RecordingsState(
      collection: collection,
      tracks: tracks,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Recorded recitations on the one shared player.
///
/// Unlike a station these have a length, and a long one: a night of Taraweeh
/// is an hour and a half, a concert recording of Mustafa Ismail most of one.
/// Nobody hears either in one sitting. So the place in each file is kept on
/// the device and a recording picks up where it was left — the difference
/// between a feature someone uses every night of Ramadan and one they try
/// once and give up on after being sent back to the first rak`ah.
class RecordingsController extends Notifier<RecordingsState> {
  AudioPlayer get _player => ref.read(quranAudioPlayerProvider);

  static const String _positionPrefix = 'recording_position_v1:';
  static const String _lastPrefix = 'recording_last_v1:';

  /// How far into a file counts as having started it. Less than this and
  /// the file begins again from the top, which is what a mis-tap wants.
  static const Duration resumeFloor = Duration(seconds: 15);

  /// How close to the end counts as having finished it. A file stopped in
  /// its last half-minute is done, and resuming there would play silence.
  static const Duration finishedMargin = Duration(seconds: 30);

  /// How often the place is written down while playing.
  static const Duration saveEvery = Duration(seconds: 10);

  /// Bumped on each load, so a slow load cannot overwrite a newer one.
  int _run = 0;
  Duration _lastSaved = Duration.zero;

  /// The last position reported, which file it was in, and that file's
  /// length as the player measured it.
  Duration _heard = Duration.zero;
  int? _heardIndex;
  Duration? _heardLength;

  /// Set while the player is being moved to another file or handed another
  /// queue. Until it gets there it goes on reporting the file it is leaving,
  /// and a position read then would be written down against the new one.
  bool _switching = false;

  @override
  RecordingsState build() {
    final playingSub = _player.playingStream.listen((playing) {
      if (AppAudio.owner != AudioOwner.recordings || !state.isOn) {
        return;
      }
      state = state.copyWith(playing: playing);
      if (!playing && !_switching) {
        unawaited(_keepHeard());
      }
    });

    final stateSub = _player.playerStateStream.listen((playerState) {
      if (AppAudio.owner != AudioOwner.recordings || !state.isOn) {
        return;
      }
      final processing = playerState.processingState;
      state = state.copyWith(
        loading:
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering,
        // Read from here as well as from `playingStream`: a file heard to
        // its end stays marked as playing, and a seek back into it plays
        // again without that flag ever changing.
        playing:
            playerState.playing &&
            processing != ProcessingState.completed &&
            processing != ProcessingState.idle,
      );
      if (processing == ProcessingState.completed) {
        // Heard to the end: forget the place, so opening it again starts it
        // again rather than resuming at the final second.
        final finished = state.current;
        if (finished != null) {
          unawaited(forgetPosition(finished.id));
        }
        state = state.copyWith(playing: false);
      }
    });

    final indexSub = _player.currentIndexStream.listen((index) {
      if (AppAudio.owner != AudioOwner.recordings ||
          !state.isOn ||
          _switching ||
          index == null ||
          index == state.index) {
        return;
      }
      // The player moved on without being asked through this controller:
      // either the file ran to its end, or a headset or the lock screen
      // skipped it. Jumps asked for here set the index before they seek, so
      // they match and return above.
      //
      // Which of the two it was is read from how much of the file had been
      // heard, not from the move itself. A night run to its end is finished
      // and its place forgotten; a night skipped at minute forty keeps
      // minute forty. The direction of the move cannot tell them apart.
      unawaited(_keepHeard());
      state = state.copyWith(index: index);
      _lastSaved = Duration.zero;
      unawaited(_rememberLast());
    });

    // A file that fails part way down a queue does not throw from `play`: the
    // player reports it here and stops. Unheard, the screen would go on
    // showing a pause button over silence.
    final errorSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (AppAudio.owner != AudioOwner.recordings || !state.isOn) {
          return;
        }
        AppLogger.error('Recording stream failed', error, stack);
        state = state.copyWith(
          playing: false,
          loading: false,
          errorKey: describe(error),
        );
      },
    );

    final positionSub = _player.positionStream.listen((position) {
      if (AppAudio.owner != AudioOwner.recordings ||
          !state.isOn ||
          _switching ||
          state.errorKey != null ||
          _player.processingState == ProcessingState.idle) {
        // Moving, failed or emptied: whatever the player reports now is not
        // a place in the file on screen.
        return;
      }
      // Kept for the moment the player moves on, when `position` already
      // belongs to the next file and this one's is gone.
      _heard = position;
      _heardIndex = state.index;
      _heardLength = _player.duration;
      if ((position - _lastSaved).abs() >= saveEvery) {
        _lastSaved = position;
        unawaited(_keepHeard());
      }
    });

    // Something else took the player. Write down where this was first, so a
    // call to prayer or a surah in between does not lose the place.
    final ownerSub = AppAudio.ownerChanges.listen((owner) {
      if (owner != AudioOwner.recordings && state.isOn) {
        _run++;
        _switching = false;
        unawaited(_keepHeard());
        state = const RecordingsState();
      }
    });

    ref.onDispose(() {
      playingSub.cancel();
      stateSub.cancel();
      indexSub.cancel();
      errorSub.cancel();
      positionSub.cancel();
      ownerSub.cancel();
    });

    return const RecordingsState();
  }

  /// Play [tracks] of [collection] from [index], picking up where that file
  /// was left if it was left part way through.
  ///
  /// The whole collection is handed to the player as one queue, so next and
  /// previous — here, on the lock screen, on a headset — walk it without the
  /// app having to be open.
  Future<void> play(
    RecordingCollection collection,
    List<RecordingTrack> tracks,
    int index,
  ) async {
    if (tracks.isEmpty) {
      return;
    }
    final start = index.clamp(0, tracks.length - 1);

    final loaded =
        state.collection?.id == collection.id &&
        state.tracks.length == tracks.length &&
        _queueReady;

    // The same file again is a pause or a resume, not a restart.
    if (loaded && state.index == start) {
      await toggle();
      return;
    }

    // Another file of the collection already in the player: move within the
    // queue rather than build it again. Rebuilding hands the player a fresh
    // playlist of up to 245 sources and throws away what it has buffered,
    // for a tap that only meant "play that one instead".
    if (loaded) {
      await _jumpTo(start);
      await _player.play();
      return;
    }

    await _load(collection, tracks, start);
  }

  /// Whether the player holds this controller's queue in a state that can
  /// be paused, resumed or moved within. Not while a queue is still being
  /// handed over, and not after a failure, when it holds nothing playable.
  bool get _queueReady =>
      AppAudio.owner == AudioOwner.recordings &&
      state.isOn &&
      !_switching &&
      state.errorKey == null &&
      _player.processingState != ProcessingState.idle;

  /// Hand the player the whole of [tracks] and start at [start].
  Future<void> _load(
    RecordingCollection collection,
    List<RecordingTrack> tracks,
    int start,
  ) async {
    // Leaving another file — of another collection, or this one after a
    // failure — keeps its place before the queue it is in goes.
    if (state.isOn && AppAudio.owner == AudioOwner.recordings) {
      await _keepHeard();
    }

    final run = ++_run;
    _switching = true;
    _heardIndex = null;
    state = RecordingsState(
      collection: collection,
      tracks: tracks,
      index: start,
      loading: true,
    );
    AppAudio.claim(AudioOwner.recordings);

    try {
      await QuranMedia.prepareSession();
      final art = await QuranMedia.coverUri();
      final resume = await savedPosition(tracks[start]);
      if (run != _run) {
        return;
      }

      await _player.setAudioSources(
        [
          for (final track in tracks)
            AudioSource.uri(
              Uri.parse(track.url),
              tag: MediaItem(
                id: track.id,
                title: displayTitle(track),
                artist: collection.reciterAr,
                album:
                    collection.subtitleAr.isEmpty
                        ? collection.titleAr
                        : '${collection.titleAr} · ${collection.subtitleAr}',
                duration: track.duration,
                artUri: art,
              ),
            ),
        ],
        initialIndex: start,
        initialPosition: resume,
      );
      if (run != _run) {
        return;
      }
      await _player.setSpeed(1);
      await _player.setLoopMode(LoopMode.off);
      _lastSaved = resume ?? Duration.zero;
      _switching = false;
      unawaited(_rememberLast());
      await _player.play();
    } catch (e, stack) {
      AppLogger.error('Recording playback failed', e, stack);
      if (run != _run) {
        return;
      }
      AppAudio.release(AudioOwner.recordings);
      state = RecordingsState(errorKey: describe(e));
    } finally {
      if (run == _run) {
        _switching = false;
      }
    }
  }

  Future<void> toggle() async {
    final collection = state.collection;
    final at = state.index;
    if (collection == null || at == null || _switching) {
      return;
    }
    // After a failed stream the player holds nothing to resume, and play
    // alone would do nothing. Pressing play again there means «try again».
    if (!_queueReady) {
      await _load(collection, state.tracks, at);
      return;
    }
    // The last file heard to its end: the player sits on its final second
    // still marked as playing, so a plain toggle would pause silence.
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: at);
      await _player.play();
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (state.hasNext) {
      await _moveTo(state.index! + 1);
    }
  }

  Future<void> previous() async {
    if (state.hasPrevious) {
      await _moveTo(state.index! - 1);
    }
  }

  /// Next or previous: within the queue when it is there, or by loading it
  /// again when a failure has left the player empty.
  Future<void> _moveTo(int index) async {
    final collection = state.collection;
    if (collection == null || _switching) {
      return;
    }
    if (_queueReady) {
      await _jumpTo(index);
    } else {
      await _load(collection, state.tracks, index);
    }
  }

  /// Move to another file the listener chose, keeping the place in both.
  ///
  /// The order matters. The place in the file being left is written first;
  /// then the index is set, **before** the seek, so that when the player
  /// reports the new index it matches and is not mistaken for the player
  /// having run off the end of the previous file — which would erase the
  /// place in a night the listener only skipped. Until the seek lands the
  /// player still reports the file being left, so nothing it says is kept.
  Future<void> _jumpTo(int index) async {
    if (index < 0 || index >= state.tracks.length) {
      return;
    }
    await _keepHeard();
    final run = _run;
    _switching = true;
    _heardIndex = null;
    try {
      final target = state.tracks[index];
      state = state.copyWith(index: index, clearError: true);
      final resume = await savedPosition(target);
      if (run != _run) {
        return;
      }
      _lastSaved = resume ?? Duration.zero;
      await _player.seek(resume ?? Duration.zero, index: index);
    } finally {
      if (run == _run) {
        _switching = false;
      }
    }
    unawaited(_rememberLast());
  }

  /// Jump within the current file.
  Future<void> seek(Duration position) async {
    if (!state.isOn) {
      return;
    }
    final total = _player.duration;
    final target =
        position < Duration.zero
            ? Duration.zero
            : (total != null && position > total ? total : position);
    await _player.seek(target);
  }

  /// Back or forward by [delta], for the ±30 second buttons.
  ///
  /// A slider on a ninety-minute file moves a minute for a millimetre of
  /// thumb; «go back a little» is what someone who missed a verse wants.
  Future<void> skip(Duration delta) => seek(_player.position + delta);

  Future<void> stop() async {
    _run++;
    _switching = false;
    if (AppAudio.owner != AudioOwner.recordings) {
      // Already given up to someone else: their audio is not this to stop.
      state = const RecordingsState();
      return;
    }
    await _keepHeard();
    await _player.stop();
    AppAudio.release(AudioOwner.recordings);
    state = const RecordingsState();
  }

  void clearError() {
    if (state.errorKey != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// `الليلة 4 · الركعات 5–8` — the group and the part, for a notification
  /// where the group heading on the page is not there to read.
  static String displayTitle(RecordingTrack track) =>
      track.group == null ? track.titleAr : '${track.group} · ${track.titleAr}';

  // --------------------------------------------------------------- places

  /// Where a file was left, or null to start it from the top.
  static Future<Duration?> savedPosition(RecordingTrack track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('$_positionPrefix${track.id}');
      return resumeFrom(
        ms == null ? null : Duration(milliseconds: ms),
        track.duration,
      );
    } catch (e) {
      AppLogger.warning('Could not read a recording position: $e');
      return null;
    }
  }

  /// Whether a stored place is worth resuming from. Pure, for tests.
  static Duration? resumeFrom(Duration? saved, Duration? length) {
    if (saved == null || saved < resumeFloor) {
      return null;
    }
    if (length != null && saved > length - finishedMargin) {
      return null;
    }
    return saved;
  }

  /// The file of [collection] last listened to, for «continue where you
  /// stopped».
  static Future<String?> lastTrackId(String collectionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_lastPrefix$collectionId');
    } catch (e) {
      AppLogger.warning('Could not read the last recording: $e');
      return null;
    }
  }

  static Future<void> forgetPosition(String trackId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_positionPrefix$trackId');
    } catch (e) {
      AppLogger.warning('Could not clear a recording position: $e');
    }
  }

  /// Write down the place in the file on screen, from the last position the
  /// player reported while in it.
  ///
  /// Never `_player.position`: by the time a save is asked for the player
  /// may have moved to the next file, been handed to a surah, or failed and
  /// reset to zero — and a zero written down erases the place. Everything
  /// up to the first await runs at once, so a caller may clear [state]
  /// straight after calling this.
  Future<void> _keepHeard() async {
    final track = state.current;
    if (track == null || _heardIndex != state.index) {
      return;
    }
    await _writePosition(track, _heard, length: _heardLength);
  }

  /// Keep [position] for [track], or forget it where it is not worth resuming
  /// — within the opening seconds, or within the last half-minute of
  /// [length], the player's own measure where it has one.
  static Future<void> _writePosition(
    RecordingTrack track,
    Duration position, {
    Duration? length,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (resumeFrom(position, length ?? track.duration) == null) {
        await prefs.remove('$_positionPrefix${track.id}');
        return;
      }
      await prefs.setInt(
        '$_positionPrefix${track.id}',
        position.inMilliseconds,
      );
    } catch (e) {
      AppLogger.warning('Could not store a recording position: $e');
    }
  }

  Future<void> _rememberLast() async {
    final collection = state.collection;
    final track = state.current;
    if (collection == null || track == null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_lastPrefix${collection.id}', track.id);
    } catch (e) {
      AppLogger.warning('Could not store the last recording: $e');
    }
  }

  static String describe(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('host') ||
        text.contains('network') ||
        text.contains('connection')) {
      return 'audio_no_network';
    }
    if (text.contains('missingplugin')) {
      return 'audio_platform_unsupported';
    }
    return 'recording_failed';
  }
}

final recordingsProvider =
    NotifierProvider<RecordingsController, RecordingsState>(
      RecordingsController.new,
    );

/// The files of one collection, fetched once and cached on the device.
final recordingTracksProvider =
    FutureProvider.family<List<RecordingTrack>, String>((ref, id) async {
      final collection = RecordingsCatalogue.byId(id);
      if (collection == null) {
        return const [];
      }
      return RecordingsCatalogue.tracks(collection);
    });
