import 'package:just_audio/just_audio.dart';

/// The one audio player in the app.
///
/// `just_audio_background` attaches its media notification to the first player
/// that is created and supports no others: a second player either plays with
/// no notification or throws outright when it is handed a source, depending on
/// which was built first. The app had three — the surah list, the verse-by-verse
/// controller, and the adhan preview — so which one worked depended on which
/// screen the user happened to open first, and previewing an adhan could leave
/// the Quran unable to play at all.
///
/// One player also matches what a listener expects. Nobody wants a call to
/// prayer and a recitation at once; starting either should stop the other, and
/// with a single player that happens by construction rather than by bookkeeping.
class AppAudio {
  AppAudio._();

  static AudioPlayer? _player;

  /// Created on first use, and never disposed while the app is alive: the
  /// background service holds a reference to it for the whole session.
  static AudioPlayer get player => _player ??= AudioPlayer();

  /// Whether anything has asked for the player yet.
  static bool get isCreated => _player != null;

  /// Only for tests, which need a clean player between cases.
  static Future<void> resetForTesting() async {
    await _player?.dispose();
    _player = null;
  }
}
