import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/settings/domain/zakat_calculator.dart';

void main() {
  // Round numbers so the arithmetic is checkable by hand.
  const prices = MetalPrices(goldPerGram: 100, silverPerGram: 1);

  group('The threshold', () {
    test('gold is 85 grams, silver is 595', () {
      expect(ZakatCalculator.nisabValue(prices, NisabBasis.gold), 85 * 100);
      expect(ZakatCalculator.nisabValue(prices, NisabBasis.silver), 595 * 1);
    });

    test('silver is the default, because it reaches more of the poor', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 1000),
        prices: prices,
      );
      expect(result.basis, NisabBasis.silver);
      expect(result.nisab, 595);
    });
  });

  group('Below the threshold', () {
    test('nothing is due', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 500),
        prices: prices,
      );
      expect(result.isDue, isFalse);
      expect(result.due, 0);
    });

    test('it says how far short, not just no', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 500),
        prices: prices,
      );
      expect(result.shortfall, 95);
    });

    test('debts can push someone under it', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 1000, debts: 600),
        prices: prices,
      );
      expect(result.netWealth, 400);
      expect(result.isDue, isFalse);
    });

    test('owing more than is owned never produces a negative amount', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 100, debts: 5000),
        prices: prices,
      );
      expect(result.netWealth, -4900);
      expect(result.due, 0, reason: 'a debt is not a refund');
      expect(result.shortfall, greaterThan(0));
    });
  });

  group('At or above the threshold', () {
    test('exactly on it counts', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 595),
        prices: prices,
      );
      expect(result.isDue, isTrue);
      expect(result.due, closeTo(595 * 0.025, 1e-9));
    });

    test('one fortieth of the whole, not of the excess', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 40000),
        prices: prices,
      );
      expect(result.due, closeTo(1000, 1e-9));
    });

    test('gold and silver are counted by weight at the stated price', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(goldGrams: 100, silverGrams: 200),
        prices: prices,
      );
      expect(result.totalAssets, 100 * 100 + 200 * 1);
      expect(result.due, closeTo(10200 * 0.025, 1e-9));
    });

    test('stock and money owed to you are included', () {
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(
          cash: 1000,
          savings: 2000,
          businessGoods: 3000,
          receivables: 500,
        ),
        prices: prices,
      );
      expect(result.totalAssets, 6500);
      expect(result.netWealth, 6500);
    });

    test('the gold basis lets more people off than the silver one', () {
      const assets = ZakatAssets(cash: 1000);

      final onSilver = ZakatCalculator.calculate(
        assets: assets,
        prices: prices,
        basis: NisabBasis.silver,
      );
      final onGold = ZakatCalculator.calculate(
        assets: assets,
        prices: prices,
        basis: NisabBasis.gold,
      );

      expect(onSilver.isDue, isTrue);
      expect(onGold.isDue, isFalse, reason: '1000 is under 8500');
    });
  });

  group('The lunar year', () {
    test('is 354 days, not 365', () {
      final start = DateTime(2026, 1, 1);
      expect(
        ZakatCalculator.hawlCompletesOn(start),
        start.add(const Duration(days: 354)),
      );
    });

    test('counts down from the day the wealth was reached', () {
      final start = DateTime(2026, 1, 1);
      expect(
        ZakatCalculator.daysUntilHawl(start, now: DateTime(2026, 1, 1)),
        354,
      );
      // 1 Jan + 354 days lands on 21 Dec, so that is the day it completes.
      expect(
        ZakatCalculator.daysUntilHawl(start, now: DateTime(2026, 12, 21)),
        0,
      );
      expect(
        ZakatCalculator.daysUntilHawl(start, now: DateTime(2027, 1, 5)),
        lessThan(0),
        reason: 'the year has already completed',
      );
    });
  });

  group('Prices the user has not supplied', () {
    test('are reported as incomplete rather than assumed', () {
      const missing = MetalPrices(goldPerGram: 0, silverPerGram: 0);
      expect(missing.isComplete, isFalse);

      // With no price there is no threshold, so nothing can be declared due.
      final result = ZakatCalculator.calculate(
        assets: const ZakatAssets(cash: 100000),
        prices: missing,
      );
      expect(result.due, 0);
    });
  });
}
