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

  const ZekrItem({
    required this.id,
    required this.textAr,
    required this.textEn,
    required this.targetCount,
  });
}
