import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/prayer_calculation_service.dart';
import 'package:islamic_app/features/prayer_times/domain/monthly_timetable.dart';

/// Cairo, and the Egyptian General Authority method the app numbers 5.
const double _lat = 30.0444;
const double _lon = 31.2357;
const int _method = 5;

MonthlyTimetable build(int year, int month) => MonthlyTimetable.build(
  year: year,
  month: month,
  latitude: _lat,
  longitude: _lon,
  method: _method,
);

void main() {
  group('How long a month is', () {
    test('the ordinary lengths', () {
      expect(MonthlyTimetable.daysIn(2026, 1), 31);
      expect(MonthlyTimetable.daysIn(2026, 4), 30);
      expect(MonthlyTimetable.daysIn(2026, 12), 31);
    });

    test('February in a common year and a leap year', () {
      expect(MonthlyTimetable.daysIn(2026, 2), 28);
      expect(MonthlyTimetable.daysIn(2028, 2), 29);
    });

    test('the hundred-year rules, which a naive check gets wrong', () {
      // 1900 was not a leap year; 2000 was.
      expect(MonthlyTimetable.daysIn(1900, 2), 28);
      expect(MonthlyTimetable.daysIn(2000, 2), 29);
    });
  });

  group('Stepping from month to month', () {
    test('forward past December lands in the next January', () {
      expect(MonthlyTimetable.shift(2026, 12, 1), (2027, 1));
    });

    test('back past January lands in the previous December', () {
      expect(MonthlyTimetable.shift(2026, 1, -1), (2025, 12));
    });

    test('a step within the year is just the next month', () {
      expect(MonthlyTimetable.shift(2026, 6, 1), (2026, 7));
      expect(MonthlyTimetable.shift(2026, 6, -1), (2026, 5));
    });

    test('a long jump still lands on a real month', () {
      final (year, month) = MonthlyTimetable.shift(2026, 3, 25);
      expect(year, 2028);
      expect(month, 4);
    });
  });

  group('A built month', () {
    test('has a row for every day, and no more', () {
      expect(build(2026, 2).days, hasLength(28));
      expect(build(2028, 2).days, hasLength(29));
      expect(build(2026, 8).days, hasLength(31));
    });

    test('the rows run in order from the first of the month', () {
      final table = build(2026, 8);
      expect(table.days.first.date.day, 1);
      expect(table.days.last.date.day, 31);
      for (var i = 0; i < table.days.length; i++) {
        expect(table.days[i].date.day, i + 1);
      }
    });

    test('every day carries all six entries of the timetable', () {
      for (final day in build(2026, 8).days) {
        for (final id in PrayerIds.all) {
          expect(day[id], isNotNull, reason: '${day.date} is missing $id');
        }
      }
    });

    test('the day runs in the order the prayers do', () {
      // A method or offset that reordered them would produce a timetable that
      // reads plausibly and is wrong, which is the worst kind.
      for (final day in build(2026, 8).days) {
        var previous = day[PrayerIds.fajr]!;
        for (final id in PrayerIds.all.skip(1)) {
          final time = day[id]!;
          expect(
            time.isAfter(previous),
            isTrue,
            reason: '$id came before the entry above it on ${day.date}',
          );
          previous = time;
        }
      }
    });

    test('it agrees with the daily calculation exactly', () {
      // The whole point of calculating this on the device: a row here can
      // never disagree with what the app said that morning.
      final table = build(2026, 8);
      for (final day in [table.days.first, table.days[14], table.days.last]) {
        final daily = PrayerCalculationService.computeDay(
          latitude: _lat,
          longitude: _lon,
          method: _method,
          date: day.date,
        );
        for (final id in PrayerIds.all) {
          expect(day[id], daily.timeOf(id), reason: '$id on ${day.date}');
        }
      }
    });

    test('Fridays are marked, and nothing else is', () {
      final table = build(2026, 8);
      final fridays = table.days.where((day) => day.isFriday).toList();

      // August 2026 begins on a Saturday, so its Fridays are the 7th, 14th,
      // 21st and 28th.
      expect(fridays.map((day) => day.date.day), [7, 14, 21, 28]);
    });

    test('today is recognised, and neighbouring days are not', () {
      final table = build(2026, 8);
      final tenth = table.days[9];
      expect(tenth.isSameDayAs(DateTime(2026, 8, 10, 23, 59)), isTrue);
      expect(tenth.isSameDayAs(DateTime(2026, 8, 11)), isFalse);
      expect(tenth.isSameDayAs(DateTime(2027, 8, 10)), isFalse);
    });
  });

  group('The Hijri months a Gregorian month crosses', () {
    test('a Gregorian month almost always spans two of them', () {
      // Naming only one would misdate half the sheet.
      final span = build(2026, 8).hijriSpan;
      expect(span.length, 2);
      expect(span.first.month, isNot(span.last.month));
    });

    test('the span is listed in the order the days run', () {
      final table = build(2026, 8);
      final span = table.hijriSpan;
      expect(span.first.month, table.days.first.hijri.month);
      expect(span.last.month, table.days.last.hijri.month);
    });

    test('every entry of the span is named in both languages', () {
      for (final parts in build(2026, 8).hijriSpan) {
        expect(parts.monthNameAr, isNotEmpty);
        expect(parts.monthNameEn, isNotEmpty);
        expect(parts.year, greaterThan(1400));
      }
    });
  });
}
