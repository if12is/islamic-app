import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/adhan_sound.dart';
import '../utils/app_logger.dart';

/// Outcome of tapping preview, so the screen can tell silence from a real miss.
enum AdhanPreviewResult { started, stopped, unavailable, failed }

/// Plays an adhan out loud, right now, so it can be heard before it is chosen.
///
/// The old preview posted a notification and hoped the channel would sound it.
/// That fails in the one moment it matters: a channel's sound is frozen when
/// the channel is created, foreground notifications are often silenced by the
/// system, and on the web there is no channel at all. Picking a call to prayer
/// you have never heard is not a choice — so the preview plays the file itself.
///
/// `just_audio_background` is initialized for Quran playback, so every source
/// here carries a [MediaItem] or the plugin throws and the screen used to
/// pretend the file belonged to the OS.
class AdhanPreviewPlayer {
  AdhanPreviewPlayer._();

  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> playing = ValueNotifier(null);
  static StreamSubscription<PlayerState>? _completionSub;

  static String? get playingId => playing.value;

  /// Bundled recordings, as Flutter assets. They are the same files Android
  /// notification channels use from `res/raw`, kept in both places because a
  /// raw resource is not reachable from Dart.
  static const Map<String, String> assets = {
    'rifat': 'assets/audio/adhan_rifat.mp3',
    'mustafa_ismail': 'assets/audio/adhan_mustafa_ismail.mp3',
    'fajr_abu_rahiq': 'assets/audio/adhan_fajr_abu_rahiq.mp3',
  };

  static Stream<PlayerState> get stateStream => _player.playerStateStream;

  /// Start [selection], or stop it if it is the one already playing.
  static Future<AdhanPreviewResult> toggle(
    AdhanSoundSelection selection,
  ) async {
    if (playing.value == selection.id) {
      await stop();
      return AdhanPreviewResult.stopped;
    }

    final source = _sourceFor(selection);
    if (source == null) {
      return AdhanPreviewResult.unavailable;
    }

    try {
      await _player.stop();
      await _player.setAudioSource(_audioSource(selection, source));
      playing.value = selection.id;
      _listenForCompletion();
      await _player.play();
      return AdhanPreviewResult.started;
    } catch (e, stack) {
      AppLogger.error('Could not preview the adhan', e, stack);
      playing.value = null;
      return AdhanPreviewResult.failed;
    }
  }

  static Future<void> stop() async {
    playing.value = null;
    await _player.stop();
  }

  static void _listenForCompletion() {
    _completionSub?.cancel();
    _completionSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playing.value = null;
      }
    });
  }

  static AudioSource _audioSource(AdhanSoundSelection selection, String source) {
    final tag = MediaItem(
      id: 'adhan_preview_${selection.id}',
      album: 'Adhan',
      title: selection.title ?? selection.id,
      artist: 'الفجر',
    );
    if (source.startsWith('assets/')) {
      return AudioSource.asset(source, tag: tag);
    }
    return AudioSource.uri(Uri.parse(source), tag: tag);
  }

  /// Where the audio for a selection lives, or null if it cannot be played.
  static String? _sourceFor(AdhanSoundSelection selection) {
    if (selection.uri != null && selection.uri!.isNotEmpty) {
      return selection.uri;
    }
    return assets[selection.id];
  }
}
