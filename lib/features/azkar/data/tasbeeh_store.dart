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
///
/// Counts are kept per phrase, not as one running number. Someone who has said
/// سبحان الله four thousand times and الحمد لله two hundred wants to see those
/// two facts, not their sum — and the sum is still shown, underneath.
class TasbeehStore {
  TasbeehStore._();

  static const String _modeKey = 'tasbeeh_mode';
  static const String _endlessKey = 'tasbeeh_endless_total';
  static const String _endlessPhraseKey = 'tasbeeh_endless_phrase';
  static const String _todayKey = 'tasbeeh_endless_today';
  static const String _todayDateKey = 'tasbeeh_endless_today_date';

  /// Per-phrase lifetime totals: `tasbeeh_phrase_total_<index>`.
  static const String _phraseTotalPrefix = 'tasbeeh_phrase_total_';

  /// Per-phrase count for the current day, in rounds mode.
  static const String _roundsPrefix = 'tasbeeh_rounds_';
  static const String _roundsDateKey = 'tasbeeh_rounds_date';

  /// One round of tasbeeh after prayer.
  static const int roundTarget = 33;

  /// How many phrases the counter cycles through.
  static const int phraseCount = 6;

  static TasbeehMode mode(SharedPreferences prefs) =>
      prefs.getString(_modeKey) == TasbeehMode.endless.name
          ? TasbeehMode.endless
          : TasbeehMode.rounds;

  static Future<void> setMode(SharedPreferences prefs, TasbeehMode mode) =>
      prefs.setString(_modeKey, mode.name);

  /// The lifetime total across every phrase — the number under the beads.
  static int total(SharedPreferences prefs) => prefs.getInt(_endlessKey) ?? 0;

  /// The lifetime total for one phrase — the number on the beads.
  static int totalFor(SharedPreferences prefs, int phraseIndex) =>
      prefs.getInt('$_phraseTotalPrefix$phraseIndex') ?? 0;

  /// Place a total onto one phrase without touching the grand total.
  ///
  /// Only for restoring a backup written before counts were split per phrase;
  /// ordinary counting goes through [increment].
  static Future<void> seedPhraseTotal(
    SharedPreferences prefs,
    int phraseIndex,
    int total,
  ) => prefs.setInt('$_phraseTotalPrefix$phraseIndex', total);

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

  /// Add one to [phraseIndex], and hand back that phrase's new total.
  static Future<int> increment(
    SharedPreferences prefs, {
    int phraseIndex = 0,
    DateTime? now,
  }) async {
    await prefs.setInt(_endlessKey, total(prefs) + 1);

    final phraseNext = totalFor(prefs, phraseIndex) + 1;
    await prefs.setInt('$_phraseTotalPrefix$phraseIndex', phraseNext);

    final key = _dayKey(now ?? DateTime.now());
    final todayCount =
        prefs.getString(_todayDateKey) == key
            ? (prefs.getInt(_todayKey) ?? 0)
            : 0;
    await prefs.setString(_todayDateKey, key);
    await prefs.setInt(_todayKey, todayCount + 1);

    return phraseNext;
  }

  // --- Rounds mode -------------------------------------------------------
  //
  // A round is per phrase and per day. Moving between phrases used to lose the
  // count, so someone who did سبحان الله thirty-three times and stepped forward
  // came back to zero — and the daily wird, reading a different store, never
  // saw any of it.

  /// Today's count for one phrase, 0 to [roundTarget].
  static int roundCount(
    SharedPreferences prefs,
    int phraseIndex, {
    DateTime? now,
  }) {
    if (!_roundsAreToday(prefs, now)) {
      return 0;
    }
    return prefs.getInt('$_roundsPrefix$phraseIndex') ?? 0;
  }

  /// Add one to a phrase's round, stopping at [roundTarget].
  static Future<int> incrementRound(
    SharedPreferences prefs,
    int phraseIndex, {
    DateTime? now,
  }) async {
    await _rollRoundsDay(prefs, now);

    final next = roundCount(prefs, phraseIndex, now: now) + 1;
    final capped = next > roundTarget ? roundTarget : next;
    await prefs.setInt('$_roundsPrefix$phraseIndex', capped);
    return capped;
  }

  /// How many phrases have reached [roundTarget] today.
  static int roundsCompleted(
    SharedPreferences prefs,
    int phraseCount, {
    DateTime? now,
  }) {
    if (!_roundsAreToday(prefs, now)) {
      return 0;
    }
    var done = 0;
    for (var index = 0; index < phraseCount; index++) {
      if ((prefs.getInt('$_roundsPrefix$index') ?? 0) >= roundTarget) {
        done++;
      }
    }
    return done;
  }

  /// Start the round over — one phrase, or all of them.
  static Future<void> resetRounds(
    SharedPreferences prefs, {
    int? phraseIndex,
    int phraseCount = 0,
  }) async {
    if (phraseIndex != null) {
      await prefs.remove('$_roundsPrefix$phraseIndex');
      return;
    }
    for (var index = 0; index < phraseCount; index++) {
      await prefs.remove('$_roundsPrefix$index');
    }
  }

  static bool _roundsAreToday(SharedPreferences prefs, DateTime? now) =>
      prefs.getString(_roundsDateKey) == _dayKey(now ?? DateTime.now());

  /// Clear yesterday's rounds the first time today's count is touched.
  static Future<void> _rollRoundsDay(
    SharedPreferences prefs,
    DateTime? now,
  ) async {
    final key = _dayKey(now ?? DateTime.now());
    if (prefs.getString(_roundsDateKey) == key) {
      return;
    }
    for (final stored in prefs.getKeys().toList()) {
      if (stored.startsWith(_roundsPrefix)) {
        await prefs.remove(stored);
      }
    }
    await prefs.setString(_roundsDateKey, key);
  }

  /// Clearing a lifetime total is deliberate and rare: only the user, from
  /// behind a confirmation, may do it.
  ///
  /// Pass [phraseIndex] to clear one phrase, or nothing to clear everything.
  static Future<void> clearTotal(
    SharedPreferences prefs, {
    int? phraseIndex,
    int phraseCount = 0,
  }) async {
    if (phraseIndex != null) {
      final removed = totalFor(prefs, phraseIndex);
      await prefs.remove('$_phraseTotalPrefix$phraseIndex');
      final remaining = total(prefs) - removed;
      await prefs.setInt(_endlessKey, remaining > 0 ? remaining : 0);
      return;
    }

    await prefs.remove(_endlessKey);
    await prefs.remove(_todayKey);
    await prefs.remove(_todayDateKey);
    for (var index = 0; index < phraseCount; index++) {
      await prefs.remove('$_phraseTotalPrefix$index');
    }
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
