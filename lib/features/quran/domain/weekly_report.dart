import '../data/reading_progress_store.dart';

/// A week of reading, summed up.
///
/// The week runs Saturday to Friday, which is the week people here actually
/// live: a report that ends on a Sunday puts Friday — the day with al-Kahf and
/// the longest sitting — in the middle of nothing.
class WeeklyReport {
  const WeeklyReport({
    required this.start,
    required this.pagesPerDay,
    required this.minutesPerDay,
    required this.streak,
  });

  /// The Saturday the week began on, at midnight.
  final DateTime start;

  /// Seven entries, Saturday first.
  final List<int> pagesPerDay;
  final List<int> minutesPerDay;

  /// The run of consecutive days ending today, which may reach back before
  /// this week — it is a fact about the reader, not about the week.
  final int streak;

  DateTime get end => start.add(const Duration(days: 6));

  int get pages => pagesPerDay.fold(0, (sum, value) => sum + value);
  int get minutes => minutesPerDay.fold(0, (sum, value) => sum + value);

  int get daysRead => pagesPerDay.where((value) => value > 0).length;

  bool get isEmpty => pages == 0 && minutes == 0;

  /// Roughly how much of the Mushaf this week covered, 0–1.
  double get mushafShare => (pages / 604).clamp(0.0, 1.0);

  /// Which day carried the week. Null when nothing was read at all.
  int? get bestDayIndex {
    if (pages == 0) {
      return null;
    }
    var best = 0;
    for (var i = 1; i < pagesPerDay.length; i++) {
      if (pagesPerDay[i] > pagesPerDay[best]) {
        best = i;
      }
    }
    return best;
  }

  /// Pages a day across the days that were read, not across all seven.
  ///
  /// Dividing by seven punishes someone who read hard on three days, which is
  /// the opposite of what a report is for.
  double get averageOnReadDays => daysRead == 0 ? 0 : pages / daysRead;

  /// The week [now] falls in.
  static WeeklyReport of(
    List<ReadingDay> days, {
    DateTime? now,
    int weeksAgo = 0,
  }) {
    final start = weekStart(
      now ?? DateTime.now(),
    ).subtract(Duration(days: 7 * weeksAgo));

    final pages = List<int>.filled(7, 0);
    final minutes = List<int>.filled(7, 0);

    for (final day in days) {
      final index = day.date.difference(start).inDays;
      if (index < 0 || index > 6) {
        continue;
      }
      pages[index] = day.pageCount;
      minutes[index] = day.minutes;
    }

    return WeeklyReport(
      start: start,
      pagesPerDay: pages,
      minutesPerDay: minutes,
      streak: ReadingProgressStore.currentStreakOf(days, now: now),
    );
  }

  /// The Saturday on or before [date], at midnight.
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    // weekday runs Monday=1 … Sunday=7, and Saturday is 6. Adding one and
    // taking the remainder gives how many days back the last Saturday was:
    // Saturday itself lands on 0.
    final offset = (day.weekday + 1) % 7;
    return day.subtract(Duration(days: offset));
  }

  /// How this week compares with the one before it, as a signed page count.
  static int changeInPages(WeeklyReport thisWeek, WeeklyReport lastWeek) =>
      thisWeek.pages - lastWeek.pages;
}
