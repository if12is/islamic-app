/// Which metal sets the threshold this year.
enum NisabBasis {
  /// 85 g of gold — the higher threshold, so fewer people owe.
  gold,

  /// 595 g of silver — the lower threshold, so more people owe and more of
  /// the poor are reached. The majority of contemporary councils prefer it
  /// for cash, which is why it is the default here.
  silver,
}

/// What a person holds, in one currency.
class ZakatAssets {
  const ZakatAssets({
    this.cash = 0,
    this.savings = 0,
    this.goldGrams = 0,
    this.silverGrams = 0,
    this.businessGoods = 0,
    this.receivables = 0,
    this.debts = 0,
  });

  /// Money in hand and in current accounts.
  final double cash;

  /// Money set aside, including deposits.
  final double savings;

  /// Gold held as a store of value, by weight.
  final double goldGrams;
  final double silverGrams;

  /// Stock held for sale, at its selling value today.
  final double businessGoods;

  /// Loans owed to the person that they expect to be repaid.
  final double receivables;

  /// Debts falling due, subtracted before the threshold is applied.
  final double debts;

  ZakatAssets copyWith({
    double? cash,
    double? savings,
    double? goldGrams,
    double? silverGrams,
    double? businessGoods,
    double? receivables,
    double? debts,
  }) {
    return ZakatAssets(
      cash: cash ?? this.cash,
      savings: savings ?? this.savings,
      goldGrams: goldGrams ?? this.goldGrams,
      silverGrams: silverGrams ?? this.silverGrams,
      businessGoods: businessGoods ?? this.businessGoods,
      receivables: receivables ?? this.receivables,
      debts: debts ?? this.debts,
    );
  }
}

/// What the metals are worth per gram today, which only the user can know.
class MetalPrices {
  const MetalPrices({required this.goldPerGram, required this.silverPerGram});

  final double goldPerGram;
  final double silverPerGram;

  bool get isComplete => goldPerGram > 0 && silverPerGram > 0;
}

/// The answer, with the arithmetic left visible.
class ZakatResult {
  const ZakatResult({
    required this.totalAssets,
    required this.netWealth,
    required this.nisab,
    required this.due,
    required this.basis,
  });

  /// Everything owned that zakat touches, before debts.
  final double totalAssets;

  /// After debts. This is what the threshold is measured against.
  final double netWealth;

  /// The threshold, in the same currency.
  final double nisab;

  /// 2.5% of [netWealth], or zero when below the threshold.
  final double due;

  final NisabBasis basis;

  bool get isDue => due > 0;

  /// How far short a person is, when they are below the threshold. Shown so
  /// the answer is "not yet, and here is by how much" rather than a bare no.
  double get shortfall => isDue ? 0 : (nisab - netWealth).clamp(0, nisab);
}

/// Works out the zakat due on wealth held for a lunar year.
///
/// Deliberately not automatic: the rate is fixed, but the gold and silver
/// prices change daily and differ by market, so the user supplies them. An app
/// that quietly used a stale price would produce a number someone might act on
/// as if it were a fatwa.
///
/// This covers zakat on wealth (نقود وذهب وفضة وعروض تجارة). It does not cover
/// zakat on crops, livestock, or minerals, which have their own thresholds and
/// rates, and it is arithmetic rather than a ruling — the screen says so.
class ZakatCalculator {
  ZakatCalculator._();

  /// Two and a half percent — one fortieth.
  static const double rate = 0.025;

  /// The classical thresholds, in grams.
  static const double goldNisabGrams = 85;
  static const double silverNisabGrams = 595;

  /// A lunar year, which is what the wealth must be held for.
  static const int hawlDays = 354;

  static double nisabValue(MetalPrices prices, NisabBasis basis) =>
      switch (basis) {
        NisabBasis.gold => goldNisabGrams * prices.goldPerGram,
        NisabBasis.silver => silverNisabGrams * prices.silverPerGram,
      };

  static ZakatResult calculate({
    required ZakatAssets assets,
    required MetalPrices prices,
    NisabBasis basis = NisabBasis.silver,
  }) {
    final totalAssets =
        assets.cash +
        assets.savings +
        assets.businessGoods +
        assets.receivables +
        (assets.goldGrams * prices.goldPerGram) +
        (assets.silverGrams * prices.silverPerGram);

    // Debts due are taken off first; zakat is on what is actually owned.
    final netWealth = totalAssets - assets.debts;
    final nisab = nisabValue(prices, basis);

    // Below the threshold nothing is owed — and a negative net worth must not
    // produce a negative "due", which a bare multiplication would.
    final due = (netWealth >= nisab && nisab > 0) ? netWealth * rate : 0.0;

    return ZakatResult(
      totalAssets: totalAssets,
      netWealth: netWealth,
      nisab: nisab,
      due: due,
      basis: basis,
    );
  }

  /// When the lunar year completes, counting from [start].
  static DateTime hawlCompletesOn(DateTime start) =>
      start.add(const Duration(days: hawlDays));

  /// Days left until the wealth has been held a full lunar year.
  static int daysUntilHawl(DateTime start, {DateTime? now}) {
    final due = hawlCompletesOn(start);
    final today = now ?? DateTime.now();
    return due.difference(today).inDays;
  }
}
