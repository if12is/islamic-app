import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/theme/app_density.dart';
import 'package:islamic_app/core/theme/design_tokens.dart';

void main() {
  group('AppDensity.fromWidth', () {
    test('a comfortable phone keeps the drawn sizes', () {
      final density = AppDensity.fromWidth(390);

      expect(density.textFactor, 1);
      expect(density.pagePadding, AppSpacing.page);
      expect(density.isCompact, isFalse);
      expect(density.isTight, isFalse);
    });

    test('a wider phone does not grow past 1', () {
      expect(AppDensity.fromWidth(430).textFactor, 1);
    });

    test('a comfortable phone keeps the dashboard tile rhythm', () {
      final density = AppDensity.fromWidth(390);

      expect(density.shortcutTileHeight, 104);
      expect(density.shortcutLabelBoxHeight, 13 * 1.25 * 2);
      expect(density.navLabelSize, 11);
      expect(density.navSlotHeight, greaterThanOrEqualTo(48));
    });

    test('a tight phone keeps a smaller but still even tile', () {
      final density = AppDensity.fromWidth(320);

      expect(density.shortcutTileHeight, 88);
      expect(density.shortcutLabelBoxHeight, 12 * 1.25 * 2);
      expect(density.navLabelSize, 10);
    });

    test('the tightest phone we support shrinks type and gutters', () {
      final density = AppDensity.fromWidth(320);

      expect(density.textFactor, AppDensity.minTextFactor);
      expect(density.pagePadding, AppDensity.tightPage);
      expect(density.isTight, isTrue);
    });

    test('a 360-wide compact phone sits between the two', () {
      final density = AppDensity.fromWidth(360);

      expect(density.textFactor, greaterThan(AppDensity.minTextFactor));
      expect(density.textFactor, lessThan(1));
      expect(density.pagePadding, greaterThan(AppDensity.tightPage));
      expect(density.pagePadding, lessThan(AppSpacing.page));
      expect(density.isTight, isFalse);
      expect(density.isCompact, isTrue);
    });
  });
}
