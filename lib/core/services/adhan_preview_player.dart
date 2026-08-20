import 'package:just_audio/just_audio.dart';

import '../models/adhan_sound.dart';
import '../utils/app_logger.dart';

/// Plays an adhan out loud, right now, so it can be heard before it is chosen.
///
/// The old preview posted a notification and hoped the channel would sound it.
/// That fails in the one moment it matters: a channel's sound is frozen when
/// the channel is created, foreground notifications are often silenced by the
/// system, and on the web there is no channel at all. Picking a call to prayer
/// you have never heard is not a choice — so the preview plays the file itself.
class AdhanPreviewPlayer {
  AdhanPreviewPlayer._();

  static final AudioPlayer _player = AudioPlayer();

  /// The id currently sounding, so the button can show stop instead of play.
  static String? _playingId;

  static String? get playingId => _playingId;

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
  ///
  /// Returns false when there is nothing to play — the system default, for
  /// instance, which belongs to the OS and cannot be read back.
  static Future<bool> toggle(AdhanSoundSelection selection) async {
    if (_playingId == selection.id) {
      await stop();
      return true;
    }

    final source = _sourceFor(selection);
    if (source == null) {
      return false;
    }

    try {
      await _player.stop();
      if (source.startsWith('assets/')) {
        await _player.setAsset(source);
      } else {
        await _player.setUrl(source);
      }
      _playingId = selection.id;
      await _player.play();

      // Clear the flag when it finishes on its own.
      _player.playerStateStream
          .firstWhere(
            (state) => state.processingState == ProcessingState.completed,
          )
          .then((_) => _playingId = null);

      return true;
    } catch (e, stack) {
      AppLogger.error('Could not preview the adhan', e, stack);
      _playingId = null;
      return false;
    }
  }

  static Future<void> stop() async {
    _playingId = null;
    await _player.stop();
  }

  /// Where the audio for a selection lives, or null if it cannot be played.
  static String? _sourceFor(AdhanSoundSelection selection) {
    if (selection.uri != null && selection.uri!.isNotEmpty) {
      // An imported file or a system sound: a content:// or file:// URI.
      return selection.uri;
    }
    return assets[selection.id];
  }
}
