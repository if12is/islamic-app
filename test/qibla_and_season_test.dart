import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/hijri_service.dart';
import 'package:islamic_app/core/services/seasonal_theme.dart';
import 'package:islamic_app/core/utils/qibla_math.dart';

void main() {
  group('Qibla maths', () {
    test('measures the shorter way around the circle', () {
      expect(QiblaMath.difference(0, 0), 0);
      expect(QiblaMath.difference(10, 350), 20);
      expect(QiblaMath.difference(350, 10), 20);
      expect(QiblaMath.difference(0, 180), 180);
      expect(QiblaMath.difference(90, 270), 180);
    });

    test('aligned means within five degrees', () {
      expect(QiblaMath.isAligned(0), isTrue);
      expect(QiblaMath.isAligned(5), isTrue);
      expect(QiblaMath.isAligned(5.1), isFalse);
      expect(QiblaMath.isAligned(40), isFalse);
    });

    test('smoothing moves toward the reading without overshooting', () {
      final step = QiblaMath.smooth(0, 100);
      expect(step, greaterThan(0));
      expect(step, lessThan(100));

      // Repeated steps converge on the target.
      var heading = 0.0;
      for (var i = 0; i < 60; i++) {
        heading = QiblaMath.smooth(heading, 100);
      }
      expect(heading, closeTo(100, 0.5));
    });

    test('smoothing crosses north the short way', () {
      // From 355° toward 5° should go up through 360, not down through 180.
      final step = QiblaMath.smooth(355, 5);
      expect(step > 355 || step < 5, isTrue);
      expect(step, isNot(closeTo(180, 90)));

      final result = QiblaMath.smooth(5, 355);
      expect(result, inInclusiveRange(0, 360));
    });

    test('haptics speed up as the angle closes', () {
      final far = QiblaMath.hapticInterval(80)!;
      final near = QiblaMath.hapticInterval(10)!;

      expect(near.inMilliseconds, lessThan(far.inMilliseconds));
      expect(near.inMilliseconds, greaterThanOrEqualTo(150));
      expect(far.inMilliseconds, lessThanOrEqualTo(1200));
    });

    test('haptics stay silent when aligned or pointing away', () {
      expect(QiblaMath.hapticInterval(0), isNull);
      expect(QiblaMath.hapticInterval(4), isNull);
      expect(QiblaMath.hapticInterval(120), isNull);
    });
  });

  group('Seasonal theme', () {
    /// The Gregorian day a given Hijri date falls on.
    DateTime gregorianFor(int month, int day) {
      final year = HijriService.fromGregorian(DateTime(2026, 8, 20)).hYear;
      return HijriService.toGregorian(year, month, day);
    }

    test('Ramadan turns the season on, and the last ten sharpen it', () {
      expect(
        SeasonalTheme.detect(now: gregorianFor(9, 5)),
        SeasonalEvent.ramadan,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(9, 20)),
        SeasonalEvent.ramadan,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(9, 21)),
        SeasonalEvent.lastTenNights,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(9, 27)),
        SeasonalEvent.lastTenNights,
      );
    });

    test('both Eids are recognised, and only for their days', () {
      expect(
        SeasonalTheme.detect(now: gregorianFor(10, 1)),
        SeasonalEvent.eidFitr,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(10, 3)),
        SeasonalEvent.eidFitr,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(10, 5)),
        SeasonalEvent.none,
      );

      expect(
        SeasonalTheme.detect(now: gregorianFor(12, 10)),
        SeasonalEvent.eidAdha,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(12, 13)),
        SeasonalEvent.eidAdha,
      );
      expect(
        SeasonalTheme.detect(now: gregorianFor(12, 20)),
        SeasonalEvent.none,
      );
    });

    test('ordinary days get no decoration at all', () {
      expect(
        SeasonalTheme.detect(now: gregorianFor(2, 12)),
        SeasonalEvent.none,
      );
      expect(SeasonalTheme.paletteFor(SeasonalEvent.none), isNull);
      expect(SeasonalTheme.greetingKey(SeasonalEvent.none), isEmpty);
    });

    test('every season has a palette and its own greeting', () {
      final greetings = <String>{};
      for (final event in SeasonalEvent.values) {
        if (event == SeasonalEvent.none) {
          continue;
        }
        expect(SeasonalTheme.paletteFor(event), isNotNull);
        greetings.add(SeasonalTheme.greetingKey(event));
      }
      expect(greetings, hasLength(SeasonalEvent.values.length - 1));
    });
  });
}
