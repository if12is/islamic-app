import 'package:shared_preferences/shared_preferences.dart';

import 'seasonal_theme.dart';

/// Decides whether the seasonal opening plays, and remembers that it did.
///
/// An intro is a greeting, not a toll booth: it plays at most once a day, it
/// can be skipped at any moment, and a switch in settings turns it off for
/// good. Nothing about it may delay the app — if the video fails to load, the
/// app simply carries on.
class SeasonalIntroService {
  SeasonalIntroService._();

  static const String enabledKey = 'seasonal_intro_enabled';
  static const String lastShownKey = 'seasonal_intro_last_shown';

  /// Videos bundled per season. Seasons without one simply have no intro.
  static const Map<SeasonalEvent, String> assets = {
    SeasonalEvent.ramadan: 'assets/video/ramadan_intro.mp4',
    SeasonalEvent.lastTenNights: 'assets/video/ramadan_intro.mp4',
  };

  static String? assetFor(SeasonalEvent event) => assets[event];

  static bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(enabledKey) ?? true;

  static Future<void> setEnabled(SharedPreferences prefs, bool enabled) async {
    await prefs.setBool(enabledKey, enabled);
  }

  /// True when today's greeting has not played yet.
  static bool shouldShow(
    SharedPreferences prefs,
    SeasonalEvent event, {
    DateTime? now,
  }) {
    if (!isEnabled(prefs) || assetFor(event) == null) {
      return false;
    }
    return prefs.getString(lastShownKey) != _dayKey(now ?? DateTime.now());
  }

  static Future<void> markShown(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    await prefs.setString(lastShownKey, _dayKey(now ?? DateTime.now()));
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
