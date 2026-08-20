import 'package:hijri/hijri_calendar.dart';

/// A notable day in the Islamic calendar.
class HijriEvent {
  const HijriEvent({
    required this.key,
    required this.month,
    required this.day,
    this.isFasting = false,
  });

  /// Localization key for the event name.
  final String key;

  final int month;
  final int day;

  /// Whether the day is commonly fasted, so the UI can mark it.
  final bool isFasting;
}

/// Hijri conversions and the events the calendar highlights.
///
/// The `hijri` package uses the Umm al-Qura tables; a manual day offset is
/// supported because moon sighting differs from country to country.
class HijriService {
  HijriService._();

  static const List<String> monthNamesAr = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<HijriEvent> events = [
    HijriEvent(key: 'event_islamic_new_year', month: 1, day: 1),
    HijriEvent(key: 'event_ashura', month: 1, day: 10, isFasting: true),
    HijriEvent(key: 'event_mawlid', month: 3, day: 12),
    HijriEvent(key: 'event_isra_miraj', month: 7, day: 27),
    HijriEvent(key: 'event_mid_shaban', month: 8, day: 15),
    HijriEvent(key: 'event_ramadan_start', month: 9, day: 1, isFasting: true),
    // The 27th is the most likely night in the reports, not a certainty; the
    // wording in the UI says so, and every odd night of the last ten is
    // marked as well.
    HijriEvent(key: 'event_laylat_qadr_expected', month: 9, day: 27),
    HijriEvent(key: 'event_eid_fitr', month: 10, day: 1),
    HijriEvent(key: 'event_arafah', month: 12, day: 9, isFasting: true),
    HijriEvent(key: 'event_eid_adha', month: 12, day: 10),
  ];

  /// Hijri date for a Gregorian day, with the user's manual correction.
  static HijriCalendar fromGregorian(DateTime date, {int offsetDays = 0}) {
    final adjusted = DateTime(
      date.year,
      date.month,
      date.day + offsetDays.clamp(-2, 2),
    );
    return HijriCalendar.fromDate(adjusted);
  }

  /// Gregorian day for a Hijri date, undoing the manual correction.
  static DateTime toGregorian(
    int year,
    int month,
    int day, {
    int offsetDays = 0,
  }) {
    final gregorian = HijriCalendar().hijriToGregorian(year, month, day);
    return DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day - offsetDays.clamp(-2, 2),
    );
  }

  static int daysInMonth(int year, int month) =>
      HijriCalendar().getDaysInMonth(year, month);

  static String monthName(int month) => monthNamesAr[(month.clamp(1, 12)) - 1];

  /// Events falling on a Hijri day, plus the recurring ones: the white days
  /// and the last ten nights of Ramadan.
  static List<HijriEvent> eventsOn(int month, int day) {
    final matches =
        events
            .where((event) => event.month == month && event.day == day)
            .toList();

    if (isLastTenOfRamadan(month, day)) {
      matches.add(
        HijriEvent(
          key:
              isOddNightOfLastTen(month, day)
                  ? 'event_odd_night'
                  : 'event_last_ten',
          month: month,
          day: day,
          isFasting: true,
        ),
      );
    }

    if (day >= 13 && day <= 15) {
      matches.add(
        HijriEvent(
          key: 'event_white_days',
          month: month,
          day: day,
          isFasting: true,
        ),
      );
    }

    if (month == 12 && day >= 11 && day <= 13) {
      matches.add(HijriEvent(key: 'event_tashreeq', month: month, day: day));
    }

    return matches;
  }

  /// Monday and Thursday, the two recommended fasting weekdays.
  static bool isRecommendedFastingWeekday(DateTime date) =>
      date.weekday == DateTime.monday || date.weekday == DateTime.thursday;

  /// Whether a Hijri date falls in Ramadan.
  static bool isRamadan(int month) => month == 9;

  /// The last ten nights of Ramadan.
  static bool isLastTenOfRamadan(int month, int day) => month == 9 && day >= 21;

  /// The odd nights of the last ten — where Laylat al-Qadr is sought.
  static bool isOddNightOfLastTen(int month, int day) =>
      isLastTenOfRamadan(month, day) && day.isOdd;
}
