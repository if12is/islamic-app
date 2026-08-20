class AzkarCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final List<ZekrItem> azkar;

  const AzkarCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.azkar,
  });
}

class ZekrItem {
  final int id;
  final String textAr;
  final String textEn;
  final int targetCount;

  /// What the Sunnah says this dhikr brings, when the source records it.
  final String virtue;

  /// Where it is narrated (Bukhari, Muslim, …).
  final String reference;

  const ZekrItem({
    required this.id,
    required this.textAr,
    required this.textEn,
    required this.targetCount,
    this.virtue = '',
    this.reference = '',
  });
}
