import '../../../core/services/prayer_calculation_service.dart';

/// One row of the monthly timetable.
class TimetableDay {
  const TimetableDay({
    required this.date,
    required this.times,
    required this.hijri,
  });

  final DateTime date;

  /// Every entry of [PrayerIds.all], in that order.
  final Map<String, DateTime> times;

  final HijriParts hijri;

  DateTime? operator [](String prayerId) => times[prayerId];

  /// Friday, which is worth marking on any timetable.
  bool get isFriday => date.weekday == DateTime.friday;

  bool isSameDayAs(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;
}

/// A whole month of prayer times, calculated on the device.
///
/// The Ramadan imsakiya already covers one Hijri month and three of its
/// columns. This is the other half of the same need: any month, every entry,
/// for people who plan a week of travel or print a page for a wall — and it
/// comes from the same calculation as the daily screen, so a row here can
/// never disagree with what the app said this morning.
class MonthlyTimetable {
  const MonthlyTimetable({
    required this.year,
    required this.month,
    required this.days,
  });

  final int year;
  final int month;
  final List<TimetableDay> days;

  /// The Hijri months this Gregorian month falls across — usually two, since
  /// the two calendars do not line up and pretending they do would misdate
  /// half the rows.
  List<HijriParts> get hijriSpan {
    final seen = <String, HijriParts>{};
    for (final day in days) {
      seen['${day.hijri.year}-${day.hijri.month}'] = day.hijri;
    }
    return seen.values.toList();
  }

  /// Days in a Gregorian month, leap years included.
  static int daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  static MonthlyTimetable build({
    required int year,
    required int month,
    required double latitude,
    required double longitude,
    required int method,
    PrayerCalculationSettings settings = const PrayerCalculationSettings(),
  }) {
    final total = daysIn(year, month);

    final days = <TimetableDay>[];
    for (var day = 1; day <= total; day++) {
      final computed = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: method,
        date: DateTime(year, month, day),
        settings: settings,
      );

      days.add(
        TimetableDay(
          date: computed.date,
          hijri: computed.hijri,
          times: {
            for (final id in PrayerIds.all)
              if (computed.timeOf(id) != null) id: computed.timeOf(id)!,
          },
        ),
      );
    }

    return MonthlyTimetable(year: year, month: month, days: days);
  }

  /// Step a month without ever producing an invalid date.
  ///
  /// `DateTime(2026, 13, 1)` rolls into January 2027 on its own, which is what
  /// makes this safe at the year boundary in both directions.
  static (int, int) shift(int year, int month, int by) {
    final moved = DateTime(year, month + by, 1);
    return (moved.year, moved.month);
  }
}
