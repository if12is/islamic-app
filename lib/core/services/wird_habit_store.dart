import 'package:shared_preferences/shared_preferences.dart';

/// When this person actually reads.
///
/// Nothing leaves the device: the only thing recorded is which hour of the day
/// a reading session happened in, kept as twenty-four counts. That is enough
/// to move the reminder to the hour someone already reads at, and not enough
/// to reconstruct anything about them.
///
/// A reminder at a time you were never going to read is a reminder you learn
/// to swipe away, which costs more than it is worth.
class WirdHabitStore {
  WirdHabitStore._();

  /// `wird_hours` — twenty-four comma-separated counts, hour 0 first.
  static const String hoursKey = 'wird_hours';

  /// The last day a session was counted, so one long sitting counts once per
  /// hour rather than once per page turn.
  static const String lastNotedKey = 'wird_last_noted';

  /// Below this there is not enough evidence to move anything.
  static const int minimumSessions = 5;

  /// Counts decay so a habit that changed in Ramadan does not hold for a year.
  static const int decayAbove = 200;

  /// Record that reading happened at [when].
  static Future<void> noteSession(
    SharedPreferences prefs, {
    DateTime? when,
  }) async {
    final now = when ?? DateTime.now();
    final stamp = '${now.year}-${now.month}-${now.day}-${now.hour}';
    if (prefs.getString(lastNotedKey) == stamp) {
      return;
    }

    final counts = readCounts(prefs);
    counts[now.hour] = counts[now.hour] + 1;

    await prefs.setString(hoursKey, encode(decay(counts)));
    await prefs.setString(lastNotedKey, stamp);
  }

  static List<int> readCounts(SharedPreferences prefs) =>
      decode(prefs.getString(hoursKey));

  /// The hour this person usually reads in, or null while it is a guess.
  ///
  /// It is the busiest hour, not the average: averaging someone who reads
  /// after fajr and again before sleep produces midday, which is the one hour
  /// they never read in.
  static int? usualHour(List<int> counts) {
    final total = counts.fold(0, (sum, value) => sum + value);
    if (total < minimumSessions) {
      return null;
    }

    var best = 0;
    for (var hour = 1; hour < counts.length; hour++) {
      if (counts[hour] > counts[best]) {
        best = hour;
      }
    }
    return counts[best] == 0 ? null : best;
  }

  /// When the reminder should fire: a little before the usual hour, so it
  /// lands as a nudge rather than an interruption partway through.
  static ({int hour, int minute})? suggestedTime(List<int> counts) {
    final hour = usualHour(counts);
    if (hour == null) {
      return null;
    }
    // Ten minutes before the hour they usually start.
    final minutes = hour * 60 - 10;
    final wrapped = minutes < 0 ? minutes + 24 * 60 : minutes;
    return (hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  /// Halve every count once one of them gets large, keeping the shape and
  /// letting a new habit overtake an old one within a few weeks.
  static List<int> decay(List<int> counts) {
    final peak = counts.fold(0, (best, value) => value > best ? value : best);
    if (peak <= decayAbove) {
      return counts;
    }
    return [for (final value in counts) value ~/ 2];
  }

  static String encode(List<int> counts) => counts.join(',');

  static List<int> decode(String? raw) {
    final counts = List<int>.filled(24, 0);
    if (raw == null || raw.isEmpty) {
      return counts;
    }
    final parts = raw.split(',');
    for (var hour = 0; hour < 24 && hour < parts.length; hour++) {
      final value = int.tryParse(parts[hour].trim());
      if (value != null && value > 0) {
        counts[hour] = value;
      }
    }
    return counts;
  }
}
