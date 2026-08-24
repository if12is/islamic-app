import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app should be sparing with someone's data allowance.
///
/// This is a setting, not a guess. Detecting the connection type would let the
/// app decide for you and would be wrong in both directions — plenty of people
/// have an unmetered SIM and a metered hotspot. Someone who knows their own
/// plan can say so once.
///
/// What it actually changes is deliberately small and real:
/// * verse recitation streams at 64 kbps instead of 128, which halves it;
/// * the reciter catalogue stops refreshing itself in the background;
/// * a download bigger than [warnAboveBytes] asks first.
///
/// It does not touch anything already on the device: the Mushaf, the azkar and
/// the prayer times were never network work to begin with.
class DataSaver {
  DataSaver._();

  static const String enabledKey = 'data_saver_enabled';
  static const String warnKey = 'data_saver_warn_mb';

  /// Bitrates the verse-audio CDN publishes.
  static const int lowBitrate = 64;
  static const int normalBitrate = 128;

  /// Default: anything over 20 MB asks before it starts.
  static const int defaultWarnMegabytes = 20;

  static bool _enabled = false;
  static int _warnMegabytes = defaultWarnMegabytes;

  /// Read once at startup so the rest of the app can ask synchronously — a
  /// URL builder cannot await a preference.
  static Future<void> load([SharedPreferences? prefs]) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    _enabled = store.getBool(enabledKey) ?? false;
    _warnMegabytes = store.getInt(warnKey) ?? defaultWarnMegabytes;
  }

  static bool get isEnabled => _enabled;

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
  }

  static int get warnMegabytes => _warnMegabytes;

  static Future<void> setWarnMegabytes(int value) async {
    _warnMegabytes = value.clamp(1, 500);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(warnKey, _warnMegabytes);
  }

  static int get warnAboveBytes => _warnMegabytes * 1024 * 1024;

  /// The bitrate verse audio should be fetched at.
  static int get audioBitrate => _enabled ? lowBitrate : normalBitrate;

  /// Whether a background refresh that costs data should run at all.
  static bool get allowsBackgroundRefresh => !_enabled;

  /// Whether a download of [bytes] should be confirmed first.
  ///
  /// A size of zero or less means the server did not state one, which is most
  /// chunked responses — asking about an unknown size would mean a dialog on
  /// every download, so those go ahead.
  static bool shouldConfirm(int bytes) =>
      _enabled && bytes > 0 && bytes >= warnAboveBytes;

  /// A whole surah at 128 kbps, roughly. The Mushaf is about 1 GB across the
  /// 114, and they vary from half a minute to two hours, so this is only ever
  /// used to size a warning, never to report a total.
  static const int averageSurahBytes = 9 * 1024 * 1024;

  /// Rough size of a batch of [surahCount] surahs, for the warning.
  static int estimateBatchBytes(int surahCount) =>
      surahCount * averageSurahBytes;

  /// Whether queueing [surahCount] surahs at once should ask first.
  static bool shouldConfirmBatch(int surahCount) =>
      shouldConfirm(estimateBatchBytes(surahCount));

  /// Reset, for tests.
  static void resetForTest() {
    _enabled = false;
    _warnMegabytes = defaultWarnMegabytes;
  }
}
