import '../domain/haramain_week.dart';

/// When the app is allowed to go to the network for the schedule.
///
/// The announcement appears once a week, so asking often buys nothing and
/// costs the user's data. The rules, in order:
///  * no cached week: ask;
///  * the cached week is over: ask, because the new one is out since
///    Saturday night;
///  * Saturday from 21:00 Makkah time, while the cached week still ends
///    today: ask every 30 minutes, because the new one lands in that window;
///  * otherwise: once every 6 hours, to catch a correction.
/// On top of the rules, an unsuccessful look is not repeated within 30
/// minutes, so a week that is over but not yet replaced does not turn every
/// page opening into a download.
class HaramainRefreshPolicy {
  const HaramainRefreshPolicy._();

  static const Duration saturdayEveningGap = Duration(minutes: 30);
  static const Duration quietGap = Duration(hours: 6);
  static const int saturdayEveningHour = 21;

  static bool shouldFetch({
    required HaramainWeek? cached,
    required DateTime? lastCheckedAt,
    required DateTime now,
  }) {
    if (cached == null) {
      return true;
    }
    final since =
        lastCheckedAt == null ? null : now.difference(lastCheckedAt.toUtc());
    // A clock that moved backwards must not freeze refreshing for days.
    final age = since == null || since.isNegative ? null : since;

    if (age == null) {
      return true;
    }
    if (cached.hasEndedAt(now)) {
      // Eager only while the new week is plausibly about to appear, through
      // Sunday. Some weeks are never reposted at all, and a fallback look
      // reads a month-long sitemap of a megabyte; asking every half hour for
      // a post that is not coming would spend someone's data for nothing.
      final overdue =
          makkahNow(now).difference(cached.endsOn) > const Duration(days: 2);
      return age >= (overdue ? quietGap : saturdayEveningGap);
    }

    final makkah = makkahNow(now);
    final endsToday =
        makkah.year == cached.endsOn.year &&
        makkah.month == cached.endsOn.month &&
        makkah.day == cached.endsOn.day;
    if (makkah.weekday == DateTime.saturday &&
        makkah.hour >= saturdayEveningHour &&
        endsToday) {
      return age >= saturdayEveningGap;
    }
    return age >= quietGap;
  }
}
