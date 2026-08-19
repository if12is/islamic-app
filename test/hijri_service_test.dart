import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/hijri_service.dart';

void main() {
  group('HijriService conversion', () {
    test('converts a Gregorian day and back again', () {
      final date = DateTime(2026, 8, 19);
      final hijri = HijriService.fromGregorian(date);

      expect(hijri.hYear, greaterThan(1400));
      expect(hijri.hMonth, inInclusiveRange(1, 12));
      expect(hijri.hDay, inInclusiveRange(1, 30));

      final roundTrip = HijriService.toGregorian(
        hijri.hYear,
        hijri.hMonth,
        hijri.hDay,
      );
      expect(roundTrip, DateTime(date.year, date.month, date.day));
    });

    test('applies the manual day offset in both directions', () {
      final date = DateTime(2026, 8, 19);
      final plain = HijriService.fromGregorian(date);
      final shifted = HijriService.fromGregorian(date, offsetDays: 1);

      // One Gregorian day forward is one Hijri day forward.
      final plainGregorian = HijriService.toGregorian(
        plain.hYear,
        plain.hMonth,
        plain.hDay,
      );
      final shiftedGregorian = HijriService.toGregorian(
        shifted.hYear,
        shifted.hMonth,
        shifted.hDay,
      );
      expect(
        shiftedGregorian.difference(plainGregorian),
        const Duration(days: 1),
      );

      // And the offset is undone when converting back.
      expect(
        HijriService.toGregorian(
          shifted.hYear,
          shifted.hMonth,
          shifted.hDay,
          offsetDays: 1,
        ),
        plainGregorian,
      );
    });

    test('months are 29 or 30 days', () {
      final year = HijriService.fromGregorian(DateTime(2026, 8, 19)).hYear;
      for (var month = 1; month <= 12; month++) {
        expect(
          HijriService.daysInMonth(year, month),
          inInclusiveRange(29, 30),
          reason: 'month $month',
        );
      }
    });

    test('names every month', () {
      expect(HijriService.monthName(1), 'محرم');
      expect(HijriService.monthName(9), 'رمضان');
      expect(HijriService.monthName(12), 'ذو الحجة');
      expect(HijriService.monthNamesAr, hasLength(12));
    });
  });

  group('HijriService events', () {
    test('marks the fixed occasions', () {
      expect(
        HijriService.eventsOn(1, 10).map((event) => event.key),
        contains('event_ashura'),
      );
      expect(
        HijriService.eventsOn(12, 9).map((event) => event.key),
        contains('event_arafah'),
      );
      expect(
        HijriService.eventsOn(10, 1).map((event) => event.key),
        contains('event_eid_fitr'),
      );
      expect(HijriService.eventsOn(2, 7), isEmpty);
    });

    test('adds the white days to every month', () {
      for (final day in [13, 14, 15]) {
        expect(
          HijriService.eventsOn(4, day).map((event) => event.key),
          contains('event_white_days'),
        );
      }
      expect(
        HijriService.eventsOn(4, 16).map((event) => event.key),
        isNot(contains('event_white_days')),
      );
    });

    test('marks the days of Tashreeq', () {
      for (final day in [11, 12, 13]) {
        expect(
          HijriService.eventsOn(12, day).map((event) => event.key),
          contains('event_tashreeq'),
        );
      }
    });

    test('knows Ramadan and its last ten nights', () {
      expect(HijriService.isRamadan(9), isTrue);
      expect(HijriService.isRamadan(8), isFalse);
      expect(HijriService.isLastTenOfRamadan(9, 21), isTrue);
      expect(HijriService.isLastTenOfRamadan(9, 20), isFalse);
    });

    test('flags Monday and Thursday as fasting weekdays', () {
      expect(
        HijriService.isRecommendedFastingWeekday(DateTime(2026, 8, 17)),
        isTrue,
      );
      expect(
        HijriService.isRecommendedFastingWeekday(DateTime(2026, 8, 20)),
        isTrue,
      );
      expect(
        HijriService.isRecommendedFastingWeekday(DateTime(2026, 8, 19)),
        isFalse,
      );
    });
  });
}
