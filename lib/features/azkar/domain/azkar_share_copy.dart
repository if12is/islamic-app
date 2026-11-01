import '../../quran/data/services/quran_local_service.dart';

/// Morning or evening, for the short card someone shares.
enum AzkarSharePeriod { morning, evening }

/// One line on that card, and how many times the Sunnah asks for it.
class AzkarShareLine {
  const AzkarShareLine({required this.text, this.count = 1});

  final String text;
  final int count;
}

/// The important morning and evening adhkar, not the whole chapter.
///
/// Ayat al-Kursi, the three Quls (each three times, as in Hisn al-Muslim),
/// sayyid al-istighfar, and two short sunnah duas. Long enough to be the
/// practice, short enough for a status image.
class AzkarShareCopy {
  AzkarShareCopy._();

  static const String morningTitle = 'أذكار الصباح';
  static const String eveningTitle = 'أذكار المساء';

  static String title(AzkarSharePeriod period) =>
      period == AzkarSharePeriod.morning ? morningTitle : eveningTitle;

  static List<AzkarShareLine> lines(AzkarSharePeriod period) =>
      period == AzkarSharePeriod.morning ? _morning : _evening;

  /// Morning and evening categories, including a remote list whose id is not
  /// exactly `morning` / `evening` but whose Arabic name still says so.
  static AzkarSharePeriod? fromCategory({
    required String id,
    required String nameAr,
  }) {
    final key = id.toLowerCase();
    if (key == 'morning' || nameAr.contains('صباح')) {
      return AzkarSharePeriod.morning;
    }
    if (key == 'evening' || nameAr.contains('مساء')) {
      return AzkarSharePeriod.evening;
    }
    return null;
  }

  static final List<AzkarShareLine> _morning = _build(morning: true);
  static final List<AzkarShareLine> _evening = _build(morning: false);

  static List<AzkarShareLine> _build({required bool morning}) {
    final became = morning ? 'أَصْبَحْتُ' : 'أَمْسَيْتُ';
    final came = morning ? 'أَصْبَحَ' : 'أَمْسَى';
    return [
      AzkarShareLine(text: QuranLocalService.verseText(2, 255)),
      AzkarShareLine(text: _surah(112, 4), count: 3),
      AzkarShareLine(text: _surah(113, 5), count: 3),
      AzkarShareLine(text: _surah(114, 6), count: 3),
      const AzkarShareLine(
        text:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي، فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ.',
      ),
      AzkarShareLine(
        count: 4,
        text:
            'اللَّهُمَّ إِنِّي $became أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ.',
      ),
      AzkarShareLine(
        text:
            'اللَّهُمَّ مَا $came بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ، فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ.',
      ),
    ];
  }

  /// A Qul with the basmala, the way the morning and evening adhkar are read.
  static String _surah(int number, int verses) {
    final parts = <String>[
      QuranLocalService.basmala,
      for (var i = 1; i <= verses; i++) QuranLocalService.verseText(number, i),
    ];
    return parts.join(' ');
  }
}
