import 'package:shared_preferences/shared_preferences.dart';

/// Whether the reader's walkthrough should run, and when it last did.
///
/// Three states, not two. "Never seen it", "seen it a while ago", and "do not
/// show me this again" are different answers, and a single boolean would force
/// the third onto anyone who saw the first — which is how a helpful tour turns
/// into something people dismiss without reading.
class ReaderTourStore {
  ReaderTourStore._();

  /// Milliseconds since the epoch of the last showing.
  static const String lastShownKey = 'reader_tour_last_shown';

  /// Set once the reader says they have it.
  static const String dismissedKey = 'reader_tour_dismissed';

  /// A reminder is welcome; a weekly interruption is not.
  ///
  /// Long enough that nobody sees it twice in the same sitting or the same
  /// week of daily reading, short enough that a feature learned and forgotten
  /// comes back round.
  static const Duration repeatAfter = Duration(days: 30);

  static bool shouldShow(SharedPreferences prefs, {DateTime? now}) {
    if (prefs.getBool(dismissedKey) == true) {
      return false;
    }

    final last = prefs.getInt(lastShownKey);
    if (last == null) {
      return true;
    }

    final at = DateTime.fromMillisecondsSinceEpoch(last);
    final since = (now ?? DateTime.now()).difference(at);
    // A clock that has gone backwards — a device whose date was wrong and got
    // corrected — should not be read as "due again".
    if (since.isNegative) {
      return false;
    }
    return since >= repeatAfter;
  }

  static Future<void> markShown(SharedPreferences prefs, {DateTime? now}) =>
      prefs.setInt(
        lastShownKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );

  static Future<void> dismissForever(SharedPreferences prefs) =>
      prefs.setBool(dismissedKey, true);

  /// For a reader who wants it back, from the settings sheet.
  static Future<void> reset(SharedPreferences prefs) async {
    await prefs.remove(dismissedKey);
    await prefs.remove(lastShownKey);
  }
}
