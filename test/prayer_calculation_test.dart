import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/prayer_calculation_service.dart';
import 'package:islamic_app/features/prayer_times/data/datasources/prayer_times_calculator_datasource.dart';

void main() {
  // Cairo, so the expectations below are about a real place.
  const latitude = 30.0444;
  const longitude = 31.2357;
  final date = DateTime(2026, 6, 15);

  group('PrayerCalculationService', () {
    test('returns the six daily entries in chronological order', () {
      final day = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
      );

      expect(day.prayers.map((prayer) => prayer.id).toList(), PrayerIds.all);

      final times = day.prayers.map((prayer) => prayer.time).toList();
      for (var i = 1; i < times.length; i++) {
        expect(
          times[i].isAfter(times[i - 1]),
          isTrue,
          reason: '${day.prayers[i].id} must come after ${day.prayers[i - 1].id}',
        );
      }
    });

    test('every prayer falls on the requested day', () {
      final day = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
      );

      for (final prayer in day.prayers) {
        expect(prayer.time.year, date.year);
        expect(prayer.time.month, date.month);
        expect(prayer.time.day, date.day);
      }
    });

    test('calculation method changes Fajr and Isha', () {
      final egyptian = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
      );
      final ummAlQura = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 4,
        date: date,
      );

      expect(
        egyptian.timeOf(PrayerIds.fajr),
        isNot(equals(ummAlQura.timeOf(PrayerIds.fajr))),
      );
      expect(
        egyptian.timeOf(PrayerIds.isha),
        isNot(equals(ummAlQura.timeOf(PrayerIds.isha))),
      );

      // Dhuhr tracks solar noon, so it barely moves between methods (the
      // minute of difference is Umm al-Qura's own method adjustment).
      expect(
        egyptian
            .timeOf(PrayerIds.dhuhr)!
            .difference(ummAlQura.timeOf(PrayerIds.dhuhr)!)
            .inMinutes
            .abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('Hanafi Asr is later than Shafi Asr', () {
      final shafi = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
      );
      final hanafi = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
        settings: const PrayerCalculationSettings(hanafiAsr: true),
      );

      expect(
        hanafi.timeOf(PrayerIds.asr)!.isAfter(shafi.timeOf(PrayerIds.asr)!),
        isTrue,
      );
    });

    test('manual minute offsets shift only the prayer they target', () {
      final base = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
      );
      final adjusted = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        date: date,
        settings: const PrayerCalculationSettings(
          minuteAdjustments: {PrayerIds.maghrib: 5},
        ),
      );

      expect(
        adjusted.timeOf(PrayerIds.maghrib)!.difference(
          base.timeOf(PrayerIds.maghrib)!,
        ),
        const Duration(minutes: 5),
      );
      expect(adjusted.timeOf(PrayerIds.fajr), base.timeOf(PrayerIds.fajr));
    });

    test('computeRange returns consecutive days', () {
      final days = PrayerCalculationService.computeRange(
        latitude: latitude,
        longitude: longitude,
        method: 3,
        from: date,
        days: 7,
      );

      expect(days, hasLength(7));
      for (var i = 0; i < days.length; i++) {
        expect(days[i].date, DateTime(date.year, date.month, date.day + i));
      }
    });

    test('rejects impossible coordinates', () {
      expect(
        () => PrayerCalculationService.computeDay(
          latitude: 120,
          longitude: longitude,
          method: 3,
          date: date,
        ),
        throwsArgumentError,
      );
    });

    test('resolves a Hijri date with both month names', () {
      final hijri = PrayerCalculationService.hijriFor(date);

      expect(hijri.day, inInclusiveRange(1, 30));
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.year, greaterThan(1400));
      expect(hijri.monthNameAr, isNotEmpty);
      expect(hijri.monthNameEn, isNotEmpty);
      expect(hijri.monthNameAr, isNot(hijri.monthNameEn));
    });
  });

  group('PrayerTimesCalculatorDataSource', () {
    test('maps to the Aladhan-compatible model shape', () {
      const calculator = PrayerTimesCalculatorDataSource();
      final model = calculator.getPrayerTimes(
        latitude: latitude,
        longitude: longitude,
        method: 5,
        location: 'Cairo',
        date: date,
      );

      expect(model.prayers.map((prayer) => prayer.name).toList(), [
        'Fajr',
        'Sunrise',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]);
      expect(model.gregorianDate, '15-06-2026');
      expect(model.location, 'Cairo');

      for (final prayer in model.prayers) {
        expect(prayer.time, matches(RegExp(r'^\d{2}:\d{2}$')));
      }
    });
  });
}
