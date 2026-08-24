import '../../quran/data/services/quran_local_service.dart';

/// Whether a passage is one the Sunnah names for ruqyah, or one scholars read.
///
/// The distinction matters and is usually dropped. Al-Fatihah, Ayat al-Kursi,
/// the closing verses of al-Baqarah and the three Muʿawwidhat are named in
/// hadith. The longer set — al-Aʿraf, Yunus, Taha, as-Saffat and the rest — is
/// a scholarly compilation, chosen because of what those verses are about. It
/// is entirely permissible to read them; it is not honest to present them as
/// though the Prophet ﷺ named them.
enum RuqyahBasis { narrated, chosen }

/// One passage of the ruqyah.
class RuqyahPassage {
  const RuqyahPassage({
    required this.surahNumber,
    required this.fromVerse,
    required this.toVerse,
    required this.basis,
    this.noteAr = '',
  });

  final int surahNumber;
  final int fromVerse;
  final int toVerse;
  final RuqyahBasis basis;

  /// Why it is here — the hadith for a narrated passage, the subject for a
  /// chosen one.
  final String noteAr;

  int get verseCount => toVerse - fromVerse + 1;

  String get titleAr {
    final name = QuranLocalService.surahInfo(surahNumber).nameAr;
    if (fromVerse == toVerse) {
      return 'سورة $name — آية $fromVerse';
    }
    if (verseCount == QuranLocalService.surahInfo(surahNumber).versesCount) {
      return 'سورة $name';
    }
    return 'سورة $name — $fromVerse‑$toVerse';
  }

  List<QuranVerse> get verses => [
    for (var number = fromVerse; number <= toVerse; number++)
      QuranLocalService.verse(surahNumber, number),
  ];
}

/// The ruqyah, in reading order.
class RuqyahPassages {
  RuqyahPassages._();

  static const List<RuqyahPassage> narrated = [
    RuqyahPassage(
      surahNumber: 1,
      fromVerse: 1,
      toVerse: 7,
      basis: RuqyahBasis.narrated,
      noteAr:
          'رقى بها الصحابي سيد القوم فبرأ، فأقرّه النبي ﷺ وقال: «وما أدراك '
          'أنها رقية؟» — رواه البخاري ومسلم.',
    ),
    RuqyahPassage(
      surahNumber: 2,
      fromVerse: 255,
      toVerse: 255,
      basis: RuqyahBasis.narrated,
      noteAr:
          'آية الكرسي: «من قرأها حين يأوي إلى فراشه لم يزل عليه من الله حافظ '
          'ولا يقربه شيطان حتى يصبح» — رواه البخاري.',
    ),
    RuqyahPassage(
      surahNumber: 2,
      fromVerse: 285,
      toVerse: 286,
      basis: RuqyahBasis.narrated,
      noteAr:
          'خواتيم البقرة: «من قرأ بالآيتين من آخر سورة البقرة في ليلة كفتاه» '
          '— رواه البخاري ومسلم.',
    ),
    RuqyahPassage(
      surahNumber: 112,
      fromVerse: 1,
      toVerse: 4,
      basis: RuqyahBasis.narrated,
      noteAr:
          'كان النبي ﷺ ينفث بالمعوذات في كفيه ويمسح بهما ما استطاع من جسده '
          '— رواه البخاري.',
    ),
    RuqyahPassage(
      surahNumber: 113,
      fromVerse: 1,
      toVerse: 5,
      basis: RuqyahBasis.narrated,
      noteAr: 'من المعوذات التي كان يرقي بها نفسه ﷺ — رواه البخاري.',
    ),
    RuqyahPassage(
      surahNumber: 114,
      fromVerse: 1,
      toVerse: 6,
      basis: RuqyahBasis.narrated,
      noteAr: 'من المعوذات التي كان يرقي بها نفسه ﷺ — رواه البخاري.',
    ),
  ];

  /// Read by scholars for ruqyah because of their subject, not because a
  /// hadith names them for it.
  static const List<RuqyahPassage> chosen = [
    RuqyahPassage(
      surahNumber: 2,
      fromVerse: 1,
      toVerse: 5,
      basis: RuqyahBasis.chosen,
      noteAr: 'أوائل البقرة، في صفة المتقين.',
    ),
    RuqyahPassage(
      surahNumber: 2,
      fromVerse: 102,
      toVerse: 103,
      basis: RuqyahBasis.chosen,
      noteAr: 'في ذمّ السحر وبيان أنه لا يضرّ إلا بإذن الله.',
    ),
    RuqyahPassage(
      surahNumber: 7,
      fromVerse: 117,
      toVerse: 122,
      basis: RuqyahBasis.chosen,
      noteAr: 'إبطال سحر سحرة فرعون.',
    ),
    RuqyahPassage(
      surahNumber: 10,
      fromVerse: 79,
      toVerse: 82,
      basis: RuqyahBasis.chosen,
      noteAr: '«إن الله سيبطله إن الله لا يصلح عمل المفسدين».',
    ),
    RuqyahPassage(
      surahNumber: 20,
      fromVerse: 65,
      toVerse: 69,
      basis: RuqyahBasis.chosen,
      noteAr: '«ولا يفلح الساحر حيث أتى».',
    ),
    RuqyahPassage(
      surahNumber: 23,
      fromVerse: 115,
      toVerse: 118,
      basis: RuqyahBasis.chosen,
      noteAr: 'خواتيم المؤمنون.',
    ),
    RuqyahPassage(
      surahNumber: 37,
      fromVerse: 1,
      toVerse: 10,
      basis: RuqyahBasis.chosen,
      noteAr: 'في حفظ السماء من كل شيطان مارد.',
    ),
    RuqyahPassage(
      surahNumber: 59,
      fromVerse: 21,
      toVerse: 24,
      basis: RuqyahBasis.chosen,
      noteAr: 'خواتيم الحشر.',
    ),
  ];

  static List<RuqyahPassage> get all => [...narrated, ...chosen];

  /// The verses of a set, flattened for the player.
  static List<QuranVerse> versesOf(List<RuqyahPassage> passages) => [
    for (final passage in passages) ...passage.verses,
  ];

  /// How many verses a set is, without building them.
  static int verseCountOf(List<RuqyahPassage> passages) =>
      passages.fold(0, (sum, passage) => sum + passage.verseCount);
}
