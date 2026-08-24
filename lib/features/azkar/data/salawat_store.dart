import 'package:shared_preferences/shared_preferences.dart';

/// Where the count of prayers upon the Prophet ﷺ lives.
///
/// Same shape as the tasbeeh: a lifetime total that never resets itself, and a
/// daily figure that rolls at midnight. Written on every tap rather than at the
/// end of a session, for the same reason — a count lost to a force-quit is a
/// count nobody trusts again.
class SalawatStore {
  SalawatStore._();

  static const String totalKey = 'salawat_total';
  static const String todayKey = 'salawat_today';
  static const String todayDateKey = 'salawat_today_date';
  static const String formKey = 'salawat_form';

  static int total(SharedPreferences prefs) => prefs.getInt(totalKey) ?? 0;

  /// Which wording is on screen.
  static String formId(SharedPreferences prefs) =>
      prefs.getString(formKey) ?? 'ibrahimiyyah';

  static Future<void> setFormId(SharedPreferences prefs, String id) =>
      prefs.setString(formKey, id);

  static int today(SharedPreferences prefs, {DateTime? now}) {
    if (prefs.getString(todayDateKey) != _dayKey(now ?? DateTime.now())) {
      return 0;
    }
    return prefs.getInt(todayKey) ?? 0;
  }

  /// Add one, and hand back the new lifetime total.
  static Future<int> increment(SharedPreferences prefs, {DateTime? now}) async {
    final next = total(prefs) + 1;
    await prefs.setInt(totalKey, next);

    final key = _dayKey(now ?? DateTime.now());
    final todayCount =
        prefs.getString(todayDateKey) == key
            ? (prefs.getInt(todayKey) ?? 0)
            : 0;
    await prefs.setString(todayDateKey, key);
    await prefs.setInt(todayKey, todayCount + 1);

    return next;
  }

  /// Only the user, deliberately.
  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(totalKey);
    await prefs.remove(todayKey);
    await prefs.remove(todayDateKey);
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
