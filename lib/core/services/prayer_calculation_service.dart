import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

import '../utils/input_validators.dart';

// Re-exported so callers can configure the calculation without importing the
// adhan package directly.
export 'package:adhan/adhan.dart'
    show CalculationMethod, HighLatitudeRule, Madhab;

/// Prayer ids used across scheduling, storage, and UI.
class PrayerIds {
  PrayerIds._();

  static const String fajr = 'fajr';
  static const String sunrise = 'sunrise';
  static const String dhuhr = 'dhuhr';
  static const String asr = 'asr';
  static const String maghrib = 'maghrib';
  static const String isha = 'isha';

  /// Every entry of the daily timetable, in order.
  static const List<String> all = [fajr, sunrise, dhuhr, asr, maghrib, isha];

  /// Only the five obligatory prayers (sunrise is a timetable entry, not a prayer).
  static const List<String> obligatory = [fajr, dhuhr, asr, maghrib, isha];
}

/// A single computed timetable entry.
class ComputedPrayer {
  const ComputedPrayer({required this.id, required this.time});

  final String id;
  final DateTime time;
}

/// Hijri date parts resolved for a Gregorian day.
class HijriParts {
  const HijriParts({
    required this.day,
    required this.month,
    required this.year,
    required this.monthNameEn,
    required this.monthNameAr,
  });

  final int day;
  final int month;
  final int year;
  final String monthNameEn;
  final String monthNameAr;
}

/// One fully computed day: prayer times plus the matching Hijri date.
class ComputedPrayerDay {
  const ComputedPrayerDay({
    required this.date,
    required this.prayers,
    required this.hijri,
  });

  final DateTime date;
  final List<ComputedPrayer> prayers;
  final HijriParts hijri;

  DateTime? timeOf(String prayerId) {
    for (final prayer in prayers) {
      if (prayer.id == prayerId) {
        return prayer.time;
      }
    }
    return null;
  }
}

/// Optional fine-tuning applied on top of a calculation method.
class PrayerCalculationSettings {
  const PrayerCalculationSettings({
    this.hanafiAsr = false,
    this.highLatitudeRule = HighLatitudeRule.middle_of_the_night,
    this.minuteAdjustments = const {},
    this.hijriOffsetDays = 0,
  });

  /// Asr shadow length: Hanafi doubles it.
  final bool hanafiAsr;

  /// Bounds for Fajr/Isha in places where the sun does not dip far enough.
  final HighLatitudeRule highLatitudeRule;

  /// Per-prayer manual offsets in minutes, keyed by [PrayerIds].
  final Map<String, int> minuteAdjustments;

  /// Manual Hijri correction (some regions run a day ahead or behind).
  final int hijriOffsetDays;

  Map<String, dynamic> toJson() => {
    'hanafiAsr': hanafiAsr,
    'highLatitudeRule': highLatitudeRule.name,
    'minuteAdjustments': minuteAdjustments,
    'hijriOffsetDays': hijriOffsetDays,
  };

  factory PrayerCalculationSettings.fromJson(Map<dynamic, dynamic> json) {
    final rawAdjustments = json['minuteAdjustments'];
    final adjustments = <String, int>{};
    if (rawAdjustments is Map) {
      for (final entry in rawAdjustments.entries) {
        final id = InputValidators.sanitizePrayerId(entry.key.toString());
        final value = entry.value;
        if (PrayerIds.all.contains(id) && value is num) {
          adjustments[id] = value.toInt().clamp(-60, 60);
        }
      }
    }

    return PrayerCalculationSettings(
      hanafiAsr: json['hanafiAsr'] == true,
      highLatitudeRule: HighLatitudeRule.values.firstWhere(
        (rule) => rule.name == json['highLatitudeRule'],
        orElse: () => HighLatitudeRule.middle_of_the_night,
      ),
      minuteAdjustments: adjustments,
      hijriOffsetDays:
          (json['hijriOffsetDays'] is num)
              ? (json['hijriOffsetDays'] as num).toInt().clamp(-2, 2)
              : 0,
    );
  }

  PrayerCalculationSettings copyWith({
    bool? hanafiAsr,
    HighLatitudeRule? highLatitudeRule,
    Map<String, int>? minuteAdjustments,
    int? hijriOffsetDays,
  }) {
    return PrayerCalculationSettings(
      hanafiAsr: hanafiAsr ?? this.hanafiAsr,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      minuteAdjustments: minuteAdjustments ?? this.minuteAdjustments,
      hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
    );
  }
}

/// Offline prayer time calculation.
///
/// Replaces the network round-trip to Aladhan with an on-device astronomical
/// calculation, so prayer times work in airplane mode and can be computed for
/// any future date — which is what makes advance notification scheduling
/// possible at all.
///
/// Method ids stay compatible with the Aladhan ids already stored in
/// preferences, so switching calculation engines does not reset user settings.
class PrayerCalculationService {
  PrayerCalculationService._();

  /// Aladhan method id -> adhan calculation method.
  static CalculationMethod methodFor(int aladhanMethodId) {
    switch (aladhanMethodId) {
      case 1:
        return CalculationMethod.karachi;
      case 2:
        return CalculationMethod.north_america;
      case 4:
        return CalculationMethod.umm_al_qura;
      case 5:
        return CalculationMethod.egyptian;
      case 7:
        return CalculationMethod.tehran;
      case 8:
        return CalculationMethod.dubai;
      case 9:
        return CalculationMethod.kuwait;
      case 10:
        return CalculationMethod.qatar;
      case 11:
        return CalculationMethod.singapore;
      case 13:
        return CalculationMethod.turkey;
      case 15:
        return CalculationMethod.moon_sighting_committee;
      case 3:
      default:
        return CalculationMethod.muslim_world_league;
    }
  }

  static CalculationParameters parametersFor(
    int aladhanMethodId,
    PrayerCalculationSettings settings,
  ) {
    final params = methodFor(aladhanMethodId).getParameters();
    params.madhab = settings.hanafiAsr ? Madhab.hanafi : Madhab.shafi;
    params.highLatitudeRule = settings.highLatitudeRule;

    final adjustments = settings.minuteAdjustments;
    params.adjustments = PrayerAdjustments(
      fajr: adjustments[PrayerIds.fajr] ?? 0,
      sunrise: adjustments[PrayerIds.sunrise] ?? 0,
      dhuhr: adjustments[PrayerIds.dhuhr] ?? 0,
      asr: adjustments[PrayerIds.asr] ?? 0,
      maghrib: adjustments[PrayerIds.maghrib] ?? 0,
      isha: adjustments[PrayerIds.isha] ?? 0,
    );

    return params;
  }

  /// Compute one day of prayer times for [date] (defaults to today).
  ///
  /// Throws [ArgumentError] when the coordinates are outside valid ranges.
  static ComputedPrayerDay computeDay({
    required double latitude,
    required double longitude,
    required int method,
    DateTime? date,
    PrayerCalculationSettings settings = const PrayerCalculationSettings(),
  }) {
    if (!InputValidators.isLatitude(latitude) ||
        !InputValidators.isLongitude(longitude)) {
      throw ArgumentError('Invalid coordinates for prayer calculation');
    }

    final day = _dateOnly(date ?? DateTime.now());
    final times = PrayerTimes(
      Coordinates(latitude, longitude),
      DateComponents.from(day),
      parametersFor(method, settings),
    );

    return ComputedPrayerDay(
      date: day,
      prayers: [
        ComputedPrayer(id: PrayerIds.fajr, time: times.fajr),
        ComputedPrayer(id: PrayerIds.sunrise, time: times.sunrise),
        ComputedPrayer(id: PrayerIds.dhuhr, time: times.dhuhr),
        ComputedPrayer(id: PrayerIds.asr, time: times.asr),
        ComputedPrayer(id: PrayerIds.maghrib, time: times.maghrib),
        ComputedPrayer(id: PrayerIds.isha, time: times.isha),
      ],
      hijri: hijriFor(day, offsetDays: settings.hijriOffsetDays),
    );
  }

  /// Compute [days] consecutive days starting at [from] (defaults to today).
  static List<ComputedPrayerDay> computeRange({
    required double latitude,
    required double longitude,
    required int method,
    DateTime? from,
    int days = 7,
    PrayerCalculationSettings settings = const PrayerCalculationSettings(),
  }) {
    final start = _dateOnly(from ?? DateTime.now());
    final safeDays = days.clamp(1, 60);

    return List<ComputedPrayerDay>.generate(safeDays, (index) {
      return computeDay(
        latitude: latitude,
        longitude: longitude,
        method: method,
        date: DateTime(start.year, start.month, start.day + index),
        settings: settings,
      );
    });
  }

  /// Qibla bearing from true north for the given coordinates.
  static double qiblaDirection({
    required double latitude,
    required double longitude,
  }) {
    return Qibla(Coordinates(latitude, longitude)).direction;
  }

  /// Hijri date for a Gregorian [date], with both English and Arabic month names.
  static HijriParts hijriFor(DateTime date, {int offsetDays = 0}) {
    final adjusted = DateTime(
      date.year,
      date.month,
      date.day + offsetDays.clamp(-2, 2),
    );

    final arabic = HijriCalendar.setLocal('ar')
      ..gregorianToHijri(adjusted.year, adjusted.month, adjusted.day);
    final monthNameAr = arabic.getLongMonthName();

    final english = HijriCalendar.setLocal('en')
      ..gregorianToHijri(adjusted.year, adjusted.month, adjusted.day);
    final monthNameEn = english.getLongMonthName();

    // Leave the shared locale on Arabic: it is the app default.
    HijriCalendar.setLocal('ar');

    return HijriParts(
      day: english.hDay,
      month: english.hMonth,
      year: english.hYear,
      monthNameEn: monthNameEn,
      monthNameAr: monthNameAr,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
