import 'package:shared_preferences/shared_preferences.dart';

import '../../features/azkar/data/salawat_store.dart';
import '../../features/quran/data/services/quran_local_service.dart';

/// What Friday asks for, and whether today's has been done.
///
/// The Friday reminders keep coming until the answer here is yes, so this is
/// the one place that decides it — the scheduler reads it before queueing,
/// and the reader and the salawat counter read it the moment something
/// changes.
class FridayProgress {
  FridayProgress._();

  static const int kahfSurah = 18;

  /// Salawat counted on the counter before Friday's reminders stop.
  ///
  /// The Sunnah asks for "much" and names no number; a hundred is a count a
  /// person can hold themselves to in a few minutes, and the screen that
  /// counts them already exists.
  static const int salawatGoal = 100;

  /// Share of Al-Kahf's pages that has to be opened on the day to count as
  /// read. The reader logs the page at the top of the screen as it settles,
  /// so a steady read can skip one or two of its dozen pages without the
  /// surah having been skipped at all.
  static const double kahfCoverage = 0.75;

  static const String _kahfDonePrefix = 'friday_kahf_done_';

  static Set<int>? _kahfPages;

  /// The Mushaf pages Al-Kahf is printed on.
  static Set<int> kahfPages() => _kahfPages ??= {
    for (final verse in QuranLocalService.versesOfSurah(kahfSurah)) verse.page,
  };

  static bool isFriday(DateTime date) => date.weekday == DateTime.friday;

  /// Whether the pages read today add up to Al-Kahf.
  static bool kahfCovered(Set<int> pagesReadToday) {
    final pages = kahfPages();
    final read = pages.intersection(pagesReadToday).length;
    return read >= (pages.length * kahfCoverage).ceil();
  }

  static bool isKahfRead(SharedPreferences prefs, DateTime date) =>
      prefs.getBool('$_kahfDonePrefix${dayKey(date)}') ?? false;

  static Future<void> markKahfRead(SharedPreferences prefs, DateTime date) =>
      prefs.setBool('$_kahfDonePrefix${dayKey(date)}', true);

  /// Whether the day's salawat have reached [salawatGoal]. Only today can be
  /// known: the counter keeps a running figure for the current day alone.
  static bool isSalawatDone(SharedPreferences prefs, DateTime date) {
    final now = DateTime.now();
    if (dayKey(date) != dayKey(now)) {
      return false;
    }
    return SalawatStore.today(prefs, now: now) >= salawatGoal;
  }

  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
