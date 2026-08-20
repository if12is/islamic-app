import 'package:shared_preferences/shared_preferences.dart';

/// The two ways people count.
enum TasbeehMode {
  /// Counts to 33 and rolls to the next phrase. Good for a set after prayer.
  rounds,

  /// Counts without end and never resets itself. The number is a lifetime
  /// total that survives closing the app, changing the phrase, and the passing
  /// of years — you pick it up wherever you left it.
  endless,
}

/// Where the tasbeeh totals live.
///
/// The endless count is the one thing in this app a person could plausibly
/// spend years building, so it is written on every tap rather than at the end
/// of a session: a count lost to a force-quit is a count nobody trusts again.
class TasbeehStore {
  TasbeehStore._();

  static const String _modeKey = 'tasbeeh_mode';
  static const String _endlessKey = 'tasbeeh_endless_total';
  static const String _endlessPhraseKey = 'tasbeeh_endless_phrase';
  static const String _todayKey = 'tasbeeh_endless_today';
  static const String _todayDateKey = 'tasbeeh_endless_today_date';

  static TasbeehMode mode(SharedPreferences prefs) =>
      prefs.getString(_modeKey) == TasbeehMode.endless.name
          ? TasbeehMode.endless
          : TasbeehMode.rounds;

  static Future<void> setMode(SharedPreferences prefs, TasbeehMode mode) =>
      prefs.setString(_modeKey, mode.name);

  /// The lifetime total.
  static int total(SharedPreferences prefs) => prefs.getInt(_endlessKey) ?? 0;

  /// Which phrase the endless counter is on.
  static int phraseIndex(SharedPreferences prefs) =>
      prefs.getInt(_endlessPhraseKey) ?? 0;

  static Future<void> setPhraseIndex(SharedPreferences prefs, int index) =>
      prefs.setInt(_endlessPhraseKey, index);

  /// How many were counted today, so the screen can show progress without
  /// touching the lifetime number.
  static int today(SharedPreferences prefs, {DateTime? now}) {
    final key = _dayKey(now ?? DateTime.now());
    if (prefs.getString(_todayDateKey) != key) {
      return 0;
    }
    return prefs.getInt(_todayKey) ?? 0;
  }

  /// Add one, and hand back the new lifetime total.
  static Future<int> increment(SharedPreferences prefs, {DateTime? now}) async {
    final next = total(prefs) + 1;
    await prefs.setInt(_endlessKey, next);

    final key = _dayKey(now ?? DateTime.now());
    final todayCount =
        prefs.getString(_todayDateKey) == key
            ? (prefs.getInt(_todayKey) ?? 0)
            : 0;
    await prefs.setString(_todayDateKey, key);
    await prefs.setInt(_todayKey, todayCount + 1);

    return next;
  }

  /// Clearing the lifetime total is deliberate and rare: only the user, from
  /// behind a confirmation, may do it.
  static Future<void> clearTotal(SharedPreferences prefs) async {
    await prefs.remove(_endlessKey);
    await prefs.remove(_todayKey);
    await prefs.remove(_todayDateKey);
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
