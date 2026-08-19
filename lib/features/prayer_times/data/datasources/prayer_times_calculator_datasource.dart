import '../../../../core/services/prayer_calculation_service.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../models/prayer_times_model.dart';

/// On-device prayer times, no network involved.
///
/// This is the primary source for prayer times: it is instant, works offline,
/// and can produce any date — the remote Aladhan source is only a fallback for
/// when a device somehow fails to calculate locally.
class PrayerTimesCalculatorDataSource {
  const PrayerTimesCalculatorDataSource();

  /// Human-readable prayer names kept identical to the Aladhan payload so the
  /// rest of the app (which matches on `fajr`, `sunrise`, …) keeps working.
  static const Map<String, String> _displayNames = {
    PrayerIds.fajr: 'Fajr',
    PrayerIds.sunrise: 'Sunrise',
    PrayerIds.dhuhr: 'Dhuhr',
    PrayerIds.asr: 'Asr',
    PrayerIds.maghrib: 'Maghrib',
    PrayerIds.isha: 'Isha',
  };

  PrayerTimesModel getPrayerTimes({
    required double latitude,
    required double longitude,
    required int method,
    required String location,
    DateTime? date,
    PrayerCalculationSettings settings = const PrayerCalculationSettings(),
  }) {
    final day = PrayerCalculationService.computeDay(
      latitude: latitude,
      longitude: longitude,
      method: method,
      date: date,
      settings: settings,
    );

    final now = DateTime.now();

    return PrayerTimesModel(
      prayers: [
        for (final prayer in day.prayers)
          PrayerEntity(
            name: _displayNames[prayer.id] ?? prayer.id,
            time: formatTime(prayer.time),
            hasPassed: prayer.time.isBefore(now),
          ),
      ],
      hijriDate: HijriDateEntity(
        day: day.hijri.day,
        month: day.hijri.month,
        year: day.hijri.year,
        monthName: day.hijri.monthNameEn,
        monthArabic: day.hijri.monthNameAr,
      ),
      gregorianDate: formatDate(day.date),
      location: location,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 24-hour `HH:mm`, matching what the Aladhan parser used to produce.
  static String formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// `DD-MM-YYYY`, matching the Aladhan gregorian date format.
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }
}
