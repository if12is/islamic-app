import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/app_audio.dart';
import 'package:islamic_app/features/broadcasts/domain/broadcast.dart';
import 'package:islamic_app/features/broadcasts/domain/recording.dart';
import 'package:islamic_app/features/broadcasts/presentation/providers/radio_provider.dart';
import 'package:islamic_app/features/broadcasts/presentation/providers/recordings_provider.dart';
import 'package:islamic_app/features/quran/presentation/providers/quran_audio_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared player, reduced to what the recordings controller reads and
/// driven by hand: what it reports, and when.
class _FakePlayer extends Fake implements AudioPlayer {
  final _playing = StreamController<bool>.broadcast();
  final _states = StreamController<PlayerState>.broadcast();
  final _indexes = StreamController<int?>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  bool _isPlaying = false;
  ProcessingState _processing = ProcessingState.idle;
  Duration _position = Duration.zero;
  int? index;

  int loads = 0;
  int stops = 0;
  Duration? loadedAt;
  final seeks = <(Duration, int?)>[];

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<PlayerState> get playerStateStream => _states.stream;
  @override
  Stream<int?> get currentIndexStream => _indexes.stream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _events.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  bool get playing => _isPlaying;
  @override
  ProcessingState get processingState => _processing;
  @override
  Duration get position => _position;
  @override
  Duration? get duration => const Duration(minutes: 90);

  void _emitState() => _states.add(PlayerState(_isPlaying, _processing));

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    loads++;
    loadedAt = initialPosition;
    index = initialIndex ?? 0;
    _indexes.add(index);
    _position = initialPosition ?? Duration.zero;
    _processing = ProcessingState.ready;
    _emitState();
    return duration;
  }

  /// Every single source loaded, in order — the radio loads one at a time.
  final loadedUris = <String>[];

  /// When set, the next single-source load waits on it: a station that is
  /// slow to answer.
  Completer<void>? hold;

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loadedUris.add((audioSource as UriAudioSource).uri.toString());
    final waiting = hold;
    if (waiting != null) {
      hold = null;
      await waiting.future;
    }
    _processing = ProcessingState.ready;
    _emitState();
    return null;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> play() async {
    if (_isPlaying) {
      return;
    }
    _isPlaying = true;
    _playing.add(true);
    _emitState();
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying) {
      return;
    }
    _isPlaying = false;
    _playing.add(false);
    _emitState();
  }

  @override
  Future<void> stop() async {
    stops++;
    _isPlaying = false;
    _processing = ProcessingState.idle;
    _playing.add(false);
    _emitState();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    // A real player goes on reporting where it still is until it lands.
    _positions.add(_position);
    seeks.add((position ?? Duration.zero, index));
    if (index != null) {
      this.index = index;
      _indexes.add(index);
    }
    _position = position ?? Duration.zero;
    if (_processing == ProcessingState.completed) {
      _processing = ProcessingState.ready;
      _emitState();
    }
  }

  /// The player reports a position in the file it is on.
  void hear(Duration position) {
    _position = position;
    _positions.add(position);
  }

  /// The player moves on by itself: end of file, headset, lock screen.
  void moveOn(int to) {
    index = to;
    _position = Duration.zero;
    _indexes.add(to);
  }

  void fail() {
    _processing = ProcessingState.idle;
    _position = Duration.zero;
    _events.addError(Exception('Source error'));
    _emitState();
  }

  void finish() {
    _processing = ProcessingState.completed;
    _emitState();
  }
}

const _night = RecordingCollection(
  id: 'test:nights',
  titleAr: 'تراويح',
  reciterAr: 'قارئ',
  category: RecordingCategory.taraweeh,
  source: RecordingSource.archive,
  identifier: 'nights',
  layout: TrackLayout.night,
);

const _other = RecordingCollection(
  id: 'test:other',
  titleAr: 'تلاوات',
  reciterAr: 'قارئ',
  category: RecordingCategory.rare,
  source: RecordingSource.archive,
  identifier: 'other',
  layout: TrackLayout.titled,
);

List<RecordingTrack> _tracks(String collectionId) => [
  for (var i = 0; i < 3; i++)
    RecordingTrack(
      id: '$collectionId:$i',
      titleAr: 'الليلة ${i + 1}',
      url: 'https://archive.org/download/x/$i.mp3',
      duration: const Duration(minutes: 90),
    ),
];

Future<Duration?> _kept(String trackId) async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt('recording_position_v1:$trackId');
  return ms == null ? null : Duration(milliseconds: ms);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlayer player;
  late ProviderContainer container;
  late RecordingsController controller;
  final nights = _tracks(_night.id);

  RecordingsState state() => container.read(recordingsProvider);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppAudio.resetForTesting();
    player = _FakePlayer();
    container = ProviderContainer(
      overrides: [quranAudioPlayerProvider.overrideWithValue(player)],
    );
    controller = container.read(recordingsProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('a skipped night keeps its place and the next resumes', () async {
    SharedPreferences.setMockInitialValues({
      'recording_position_v1:${nights[1].id}':
          const Duration(minutes: 20).inMilliseconds,
    });
    await controller.play(_night, nights, 0);
    player.hear(const Duration(minutes: 40));
    await pumpEventQueue();

    await controller.next();
    await pumpEventQueue();

    expect(state().index, 1);
    expect(player.seeks.last, (const Duration(minutes: 20), 1));
    expect(await _kept(nights[0].id), const Duration(minutes: 40));
    // What the player reported on its way over was the night being left,
    // not a place in the next one.
    expect(await _kept(nights[1].id), const Duration(minutes: 20));
  });

  test(
    'a headset skip keeps the place; a night run to its end does not',
    () async {
      await controller.play(_night, nights, 0);
      player.hear(const Duration(minutes: 40));
      await pumpEventQueue();
      player.moveOn(1);
      await pumpEventQueue();

      expect(state().index, 1);
      expect(await _kept(nights[0].id), const Duration(minutes: 40));

      player.hear(const Duration(minutes: 30));
      await pumpEventQueue();
      player.hear(const Duration(minutes: 89, seconds: 50));
      await pumpEventQueue();
      player.moveOn(2);
      await pumpEventQueue();

      expect(state().index, 2);
      expect(await _kept(nights[1].id), isNull);
    },
  );

  test('a lock-screen skip picks up the night it lands on', () async {
    SharedPreferences.setMockInitialValues({
      'recording_position_v1:${nights[1].id}':
          const Duration(minutes: 20).inMilliseconds,
    });
    await controller.play(_night, nights, 0);
    player.hear(const Duration(minutes: 40));
    await pumpEventQueue();

    player.moveOn(1);
    // The player starts the new night from the top, and reports it, before
    // it is sent back to the kept place.
    player.hear(const Duration(seconds: 11));
    await pumpEventQueue();

    expect(state().index, 1);
    expect(player.seeks.last, (const Duration(minutes: 20), 1));
    expect(await _kept(nights[1].id), const Duration(minutes: 20));
    expect(await _kept(nights[0].id), const Duration(minutes: 40));
  });

  test('opening another collection keeps the place in the one left', () async {
    await controller.play(_night, nights, 0);
    player.hear(const Duration(minutes: 40));
    await pumpEventQueue();
    player.hear(const Duration(minutes: 40, seconds: 8));
    await pumpEventQueue();

    await controller.play(_other, _tracks(_other.id), 0);
    await pumpEventQueue();

    expect(state().collection?.id, _other.id);
    expect(await _kept(nights[0].id), const Duration(minutes: 40, seconds: 8));
  });

  test(
    'after a failure the place is kept and play tries again from it',
    () async {
      await controller.play(_night, nights, 0);
      player.hear(const Duration(minutes: 40));
      await pumpEventQueue();

      player.fail();
      await pumpEventQueue();
      // A failed player reports zero, which must not erase the place.
      player.hear(Duration.zero);
      await pumpEventQueue();

      expect(state().errorKey, isNotNull);
      expect(state().playing, isFalse);
      expect(await _kept(nights[0].id), const Duration(minutes: 40));

      await controller.toggle();
      await pumpEventQueue();

      expect(player.loads, 2);
      expect(player.loadedAt, const Duration(minutes: 40));
      expect(state().errorKey, isNull);
      expect(state().playing, isTrue);
    },
  );

  test('play after the last night ends starts it again', () async {
    await controller.play(_night, nights, 2);
    await pumpEventQueue();
    player.finish();
    await pumpEventQueue();
    expect(state().playing, isFalse);

    await controller.toggle();
    await pumpEventQueue();

    expect(player.seeks.last, (Duration.zero, 2));
    expect(state().playing, isTrue);
  });

  test(
    'another owner taking the player keeps the place and is left alone',
    () async {
      await controller.play(_night, nights, 0);
      player.hear(const Duration(minutes: 40));
      await pumpEventQueue();

      AppAudio.claim(AudioOwner.radio);
      await pumpEventQueue();

      expect(state().isOn, isFalse);
      expect(await _kept(nights[0].id), const Duration(minutes: 40));

      await controller.stop();
      expect(player.stops, 0);
      expect(AppAudio.owner, AudioOwner.radio);
    },
  );

  test('stop keeps the place and hands the player back', () async {
    await controller.play(_night, nights, 0);
    player.hear(const Duration(minutes: 12));
    await pumpEventQueue();
    player.hear(const Duration(minutes: 12, seconds: 5));
    await pumpEventQueue();

    await controller.stop();

    expect(player.stops, 1);
    expect(AppAudio.owner, AudioOwner.none);
    expect(state().isOn, isFalse);
    expect(await _kept(nights[0].id), const Duration(minutes: 12, seconds: 5));
  });

  test(
    'a slow station does not take the player back from a recording',
    () async {
      const station = Broadcast(
        id: 'radio:1',
        name: 'إذاعة',
        url: 'https://first.example/live',
        fallbackUrl: 'https://second.example/live',
        kind: BroadcastKind.radio,
      );
      final slow = Completer<void>();
      player.hold = slow;
      final tuning = container.read(radioProvider.notifier).play(station);
      await pumpEventQueue();

      // While the first address hangs, a recording is started. Its load
      // interrupts the station's, which then fails.
      await controller.play(_night, nights, 0);
      slow.completeError(PlayerInterruptedException('Loading interrupted'));
      await tuning;
      await pumpEventQueue();

      expect(player.loadedUris, ['https://first.example/live']);
      expect(AppAudio.owner, AudioOwner.recordings);
      expect(state().isOn, isTrue);
      expect(container.read(radioProvider).isOn, isFalse);
    },
  );
}
