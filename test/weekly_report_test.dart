import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/reading_progress_store.dart';
import 'package:islamic_app/features/quran/domain/weekly_report.dart';

ReadingDay _day(DateTime date, {int pages = 0, int minutes = 0}) => ReadingDay(
  date: date,
  pages: {for (var i = 1; i <= pages; i++) i},
  minutes: minutes,
);

void main() {
  group('Where the week starts', () {
    // The week here runs Saturday to Friday. A report that ends on a Sunday
    // buries Friday — the day with al-Kahf and the longest sitting — in the
    // middle of the chart.
    test('every day of the week resolves back to its Saturday', () {
      // 2026-08-22 is a Saturday.
      final saturday = DateTime(2026, 8, 22);
      for (var offset = 0; offset < 7; offset++) {
        final day = saturday.add(Duration(days: offset));
        expect(
          WeeklyReport.weekStart(day),
          saturday,
          reason: 'weekday ${day.weekday}',
        );
      }
    });

    test('the next Saturday starts a new week', () {
      expect(
        WeeklyReport.weekStart(DateTime(2026, 8, 29)),
        DateTime(2026, 8, 29),
      );
    });

    test('a time of day does not shift the week', () {
      expect(
        WeeklyReport.weekStart(DateTime(2026, 8, 25, 23, 59)),
        DateTime(2026, 8, 22),
      );
    });
  });

  group('Reading a week out of the log', () {
    final saturday = DateTime(2026, 8, 22);
    final days = [
      _day(saturday, pages: 5, minutes: 20),
      _day(saturday.add(const Duration(days: 2)), pages: 12, minutes: 40),
      _day(saturday.add(const Duration(days: 6)), pages: 3, minutes: 10),
      // Last week, which must not leak into this one.
      _day(saturday.subtract(const Duration(days: 3)), pages: 40, minutes: 90),
    ];

    test('only this week is counted', () {
      final report = WeeklyReport.of(days, now: DateTime(2026, 8, 26));
      expect(report.pages, 20);
      expect(report.minutes, 70);
      expect(report.daysRead, 3);
      expect(report.pagesPerDay, [5, 0, 12, 0, 0, 0, 3]);
    });

    test('the best day is the one that carried the week', () {
      final report = WeeklyReport.of(days, now: DateTime(2026, 8, 26));
      expect(report.bestDayIndex, 2, reason: 'Monday, with twelve pages');
    });

    test('the average is over the days read, not over seven', () {
      // Dividing by seven punishes someone who read hard on three days, which
      // is the opposite of what a report is for.
      final report = WeeklyReport.of(days, now: DateTime(2026, 8, 26));
      expect(report.averageOnReadDays, closeTo(20 / 3, 0.001));
    });

    test('last week can be read by stepping back', () {
      final previous = WeeklyReport.of(
        days,
        now: DateTime(2026, 8, 26),
        weeksAgo: 1,
      );
      expect(previous.pages, 40);
      expect(previous.start, DateTime(2026, 8, 15));
    });

    test('an empty week says so instead of showing zeros as a shape', () {
      final report = WeeklyReport.of(const [], now: DateTime(2026, 8, 26));
      expect(report.isEmpty, isTrue);
      expect(report.bestDayIndex, isNull);
      expect(report.averageOnReadDays, 0);
      expect(report.mushafShare, 0);
    });
  });

  group('Comparing with last week', () {
    WeeklyReport report(int pages) => WeeklyReport(
      start: DateTime(2026, 8, 22),
      pagesPerDay: [pages, 0, 0, 0, 0, 0, 0],
      minutesPerDay: const [0, 0, 0, 0, 0, 0, 0],
      streak: 0,
    );

    test('the difference is signed, not absolute', () {
      expect(WeeklyReport.changeInPages(report(30), report(10)), 20);
      expect(WeeklyReport.changeInPages(report(10), report(30)), -20);
      expect(WeeklyReport.changeInPages(report(10), report(10)), 0);
    });
  });

  group('How much of the Mushaf a week covered', () {
    test('never reports more than all of it', () {
      final report = WeeklyReport(
        start: DateTime(2026, 8, 22),
        pagesPerDay: const [604, 604, 0, 0, 0, 0, 0],
        minutesPerDay: const [0, 0, 0, 0, 0, 0, 0],
        streak: 2,
      );
      expect(report.mushafShare, 1.0);
    });
  });
}
