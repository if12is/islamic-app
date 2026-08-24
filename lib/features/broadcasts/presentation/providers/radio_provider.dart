import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../../core/services/app_audio.dart';
import '../../../../core/services/quran_media.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../quran/presentation/providers/quran_audio_provider.dart';
import '../../data/broadcast_catalogue.dart';
import '../../domain/broadcast.dart';

/// What the radio bar shows.
class RadioState {
  const RadioState({
    this.station,
    this.playing = false,
    this.connecting = false,
    this.errorKey,
  });

  /// Null when nothing is tuned in.
  final Broadcast? station;

  final bool playing;

  /// A live stream has no length to buffer against, so the wait before the
  /// first sound is longer than a file's and needs saying out loud.
  final bool connecting;

  final String? errorKey;

  bool get isOn => station != null;

  RadioState copyWith({
    Broadcast? station,
    bool clearStation = false,
    bool? playing,
    bool? connecting,
    String? errorKey,
    bool clearError = false,
  }) {
    return RadioState(
      station: clearStation ? null : (station ?? this.station),
      playing: playing ?? this.playing,
      connecting: connecting ?? this.connecting,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Live radio on the one shared player.
///
/// Tuning in takes the player from whatever was using it, which is what a
/// listener expects — nobody wants a surah and a station at once. The screens
/// that lose it are told, so they stop showing controls for silence.
class RadioController extends Notifier<RadioState> {
  AudioPlayer get _player => ref.read(quranAudioPlayerProvider);

  @override
  RadioState build() {
    final playingSub = _player.playingStream.listen((playing) {
      if (AppAudio.owner == AudioOwner.radio) {
        state = state.copyWith(playing: playing);
      }
    });

    final stateSub = _player.playerStateStream.listen((playerState) {
      if (AppAudio.owner != AudioOwner.radio) {
        return;
      }
      state = state.copyWith(
        connecting:
            playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering,
      );
    });

    // Somebody else took the player: drop the station rather than leave a bar
    // on screen with a pause button for audio that stopped.
    final ownerSub = AppAudio.ownerChanges.listen((owner) {
      if (owner != AudioOwner.radio && state.isOn) {
        state = const RadioState();
      }
    });

    ref.onDispose(() {
      playingSub.cancel();
      stateSub.cancel();
      ownerSub.cancel();
    });

    return const RadioState();
  }

  /// Tune in, or pause and resume when it is already the current station.
  Future<void> play(Broadcast station) async {
    if (state.station?.id == station.id && AppAudio.owner == AudioOwner.radio) {
      await toggle();
      return;
    }

    state = RadioState(station: station, connecting: true);
    AppAudio.claim(AudioOwner.radio);

    // Each address in turn: the catalogue's own host fails on about one
    // station in five, and falling through to it is the difference between a
    // station that works and one that never does.
    Object? lastError;
    for (final source in station.sources) {
      try {
        await QuranMedia.prepareSession();
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(source),
            tag: MediaItem(
              id: 'radio_${station.id}',
              title: station.name,
              album: 'البث المباشر',
              artist: 'إذاعة',
              artUri: await QuranMedia.coverUri(),
              isLive: true,
            ),
          ),
        );
        await _player.setSpeed(1);
        await _player.play();
        state = state.copyWith(connecting: false, clearError: true);
        return;
      } catch (e, stack) {
        lastError = e;
        AppLogger.warning('Radio source failed ($source): $e');
        if (source == station.sources.last) {
          AppLogger.error('Radio playback failed', e, stack);
        }
      }
    }

    state = RadioState(errorKey: _describe(lastError));
    AppAudio.release(AudioOwner.radio);
  }

  Future<void> toggle() async {
    if (!state.isOn) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      // A live stream resumed from a pause is minutes behind, so it starts
      // again from the front rather than replaying stale audio.
      final station = state.station;
      if (station != null && _player.processingState == ProcessingState.idle) {
        await play(station);
        return;
      }
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    AppAudio.release(AudioOwner.radio);
    state = const RadioState();
  }

  void clearError() {
    if (state.errorKey != null) {
      state = state.copyWith(clearError: true);
    }
  }

  static String _describe(Object? error) {
    if (error == null) {
      return 'broadcast_failed';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('cleartext')) {
      return 'broadcast_blocked';
    }
    if (text.contains('socket') ||
        text.contains('host') ||
        text.contains('network') ||
        text.contains('connection')) {
      return 'audio_no_network';
    }
    if (text.contains('missingplugin')) {
      return 'audio_platform_unsupported';
    }
    return 'broadcast_failed';
  }
}

final radioProvider = NotifierProvider<RadioController, RadioState>(
  RadioController.new,
);

/// The catalogue, fetched once per session and cached on disk beyond that.
final broadcastsProvider = FutureProvider<List<Broadcast>>(
  (ref) => BroadcastCatalogue.load(),
);
