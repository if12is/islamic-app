/// The five daily prayers, in the order the announcement lists them.
enum HaramainPrayer { fajr, dhuhr, asr, maghrib, isha }

/// The two mosques the announcement covers.
enum HaramainMosque { haram, nabawi }

/// Who leads one prayer.
class ImamEntry {
  const ImamEntry({
    required this.rawName,
    required this.displayName,
    this.rosterId,
  });

  /// The name as the announcement wrote it, minus titles and punctuation.
  /// Kept so a name the roster does not know yet is still shown, spelled the
  /// way the source spelled it.
  final String rawName;

  /// The roster's canonical spelling when the name was recognised, otherwise
  /// the same as [rawName].
  final String displayName;

  /// Null when the name matched nobody on the roster.
  final String? rosterId;
}

/// One published week of imams.
///
/// The announcement names ONE imam per prayer for the whole week, Sunday to
/// Saturday. There is deliberately no per-day grid here: inventing one would
/// tell people a wrong name on most days.
class HaramainWeek {
  const HaramainWeek({
    required this.startHijri,
    required this.endHijri,
    required this.hijriYear,
    required this.endsOn,
    required this.fetchedAt,
    required this.sourceUrl,
    required this.haram,
    required this.nabawi,
  });

  /// Day and month as published, e.g. «23 ربيع الآخر».
  final String startHijri;
  final String endHijri;
  final int hijriYear;

  /// The Saturday the week ends on, as a calendar date (UTC midnight, the time
  /// of day carries no meaning). The announcement only gives the Hijri date;
  /// the Gregorian day is what lets the app know when the week is over.
  final DateTime endsOn;

  /// The Sunday the week starts on. Derived from [endsOn] rather than
  /// converted from the published start date: «30 ربيع الآخر» does not exist
  /// in a 29-day month, and the week is always seven days long.
  DateTime get startsOn =>
      DateTime.utc(endsOn.year, endsOn.month, endsOn.day - 6);

  /// When this week was last confirmed against the source.
  final DateTime fetchedAt;
  final String sourceUrl;

  final Map<HaramainPrayer, ImamEntry> haram;
  final Map<HaramainPrayer, ImamEntry> nabawi;

  Map<HaramainPrayer, ImamEntry> of(HaramainMosque mosque) =>
      mosque == HaramainMosque.haram ? haram : nabawi;

  /// True once Makkah's calendar has moved past the last day of the week.
  bool hasEndedAt(DateTime now) {
    final today = makkahNow(now);
    return DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).isAfter(DateTime.utc(endsOn.year, endsOn.month, endsOn.day));
  }

  HaramainWeek copyWith({DateTime? fetchedAt}) {
    return HaramainWeek(
      startHijri: startHijri,
      endHijri: endHijri,
      hijriYear: hijriYear,
      endsOn: endsOn,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      sourceUrl: sourceUrl,
      haram: haram,
      nabawi: nabawi,
    );
  }
}

/// Makkah wall-clock time (UTC+3, no daylight saving) for an instant.
///
/// The result is a UTC-flagged [DateTime] whose fields read as Makkah's clock,
/// so `.weekday` and `.hour` answer "what day and hour is it in Makkah".
/// The announcement follows Makkah's week, not the phone's.
DateTime makkahNow(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 3));
