/// How firmly a narration about a surah's virtue is established.
///
/// This is stated on every entry rather than left out, because the popular
/// virtues and the authenticated ones are not the same set, and an app that
/// prints them identically teaches people something untrue. A weak narration
/// is not forbidden to read — but it should not be dressed as a sound one.
enum NarrationGrade {
  /// In Bukhari or Muslim.
  agreed,

  /// Authenticated outside the two Sahihs.
  authentic,

  /// Good, though below authentic.
  good,

  /// Widely repeated, but not established.
  weak,

  /// No narration; the practice rests on general merit.
  customary,
}

/// When during the day a surah is read.
enum ReadingTime {
  /// After Fajr, at the start of the day.
  morning,

  /// After Asr or Maghrib.
  evening,

  /// The last thing before sleeping.
  beforeSleep,

  /// Friday, any time before Maghrib.
  friday,

  /// After each of the five prayers.
  afterEveryPrayer,
}

/// A surah or passage worth returning to, and why.
class SurahVirtue {
  const SurahVirtue({
    required this.id,
    required this.surahNumber,
    required this.nameAr,
    required this.time,
    required this.virtueAr,
    required this.sourceAr,
    required this.grade,
    this.fromAyah,
    this.toAyah,
  });

  final String id;
  final int surahNumber;
  final String nameAr;
  final ReadingTime time;

  /// What the narration says, in the words of the narration where possible.
  final String virtueAr;

  /// Who reported it, so the claim can be checked rather than taken on trust.
  final String sourceAr;

  final NarrationGrade grade;

  /// Set when only part of the surah is meant.
  final int? fromAyah;
  final int? toAyah;

  bool get isPartial => fromAyah != null;

  /// Whether this is firm enough to state as an established virtue.
  bool get isEstablished =>
      grade == NarrationGrade.agreed ||
      grade == NarrationGrade.authentic ||
      grade == NarrationGrade.good;

  /// The grade in one word, to sit beside the text wherever it is shown.
  String get gradeAr => switch (grade) {
    NarrationGrade.agreed => 'متفق عليه',
    NarrationGrade.authentic => 'صحيح',
    NarrationGrade.good => 'حسن',
    NarrationGrade.weak => 'ضعيف',
    NarrationGrade.customary => 'لم يرد فيه حديث',
  };

  /// The virtue with its grade and source attached, for a notification body
  /// or anywhere else that has one line and no room for a badge.
  ///
  /// The grade travels with the text on purpose. A weak narration printed on
  /// its own reads as an established one, and repeating it that way is how it
  /// becomes established in people's minds.
  String get virtueWithGradeAr => '$virtueAr\n— $gradeAr · $sourceAr';
}

/// The daily and weekly readings, with their sources.
class SurahVirtues {
  SurahVirtues._();

  static const List<SurahVirtue> all = [
    SurahVirtue(
      id: 'kahf',
      surahNumber: 18,
      nameAr: 'الكهف',
      time: ReadingTime.friday,
      virtueAr:
          'من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين.',
      sourceAr: 'رواه الحاكم والبيهقي، وصححه الألباني',
      grade: NarrationGrade.authentic,
    ),
    SurahVirtue(
      id: 'kahf_ten',
      surahNumber: 18,
      nameAr: 'أوائل الكهف',
      time: ReadingTime.friday,
      virtueAr: 'من حفظ عشر آيات من أول سورة الكهف عُصم من الدجال.',
      sourceAr: 'رواه مسلم',
      grade: NarrationGrade.agreed,
      fromAyah: 1,
      toAyah: 10,
    ),
    SurahVirtue(
      id: 'mulk',
      surahNumber: 67,
      nameAr: 'الملك',
      time: ReadingTime.beforeSleep,
      virtueAr:
          'سورة من القرآن ثلاثون آية شفعت لرجل حتى غُفر له، وهي: تبارك الذي بيده الملك.',
      sourceAr: 'رواه أبو داود والترمذي، وحسّنه الألباني',
      grade: NarrationGrade.good,
    ),
    SurahVirtue(
      id: 'sajdah',
      surahNumber: 32,
      nameAr: 'السجدة',
      time: ReadingTime.beforeSleep,
      virtueAr:
          'كان النبي ﷺ لا ينام حتى يقرأ «الم تنزيل» السجدة و«تبارك الذي بيده الملك».',
      sourceAr: 'رواه الترمذي وصححه',
      grade: NarrationGrade.authentic,
    ),
    SurahVirtue(
      id: 'baqarah_end',
      surahNumber: 2,
      nameAr: 'خواتيم البقرة',
      time: ReadingTime.beforeSleep,
      virtueAr: 'من قرأ بالآيتين من آخر سورة البقرة في ليلة كفتاه.',
      sourceAr: 'متفق عليه — البخاري ومسلم',
      grade: NarrationGrade.agreed,
      fromAyah: 285,
      toAyah: 286,
    ),
    SurahVirtue(
      id: 'ayat_kursi',
      surahNumber: 2,
      nameAr: 'آية الكرسي',
      time: ReadingTime.afterEveryPrayer,
      virtueAr:
          'من قرأ آية الكرسي دُبُر كل صلاة مكتوبة لم يمنعه من دخول الجنة إلا أن يموت.',
      sourceAr: 'رواه النسائي، وصححه الألباني',
      grade: NarrationGrade.authentic,
      fromAyah: 255,
      toAyah: 255,
    ),
    SurahVirtue(
      id: 'muawwidhat',
      surahNumber: 112,
      nameAr: 'المعوّذات',
      time: ReadingTime.afterEveryPrayer,
      virtueAr:
          'أمر النبي ﷺ أن يقرأ المعوّذات — الإخلاص والفلق والناس — دبر كل صلاة.',
      sourceAr: 'رواه أبو داود والترمذي، وحسّنه الألباني',
      grade: NarrationGrade.good,
    ),
    SurahVirtue(
      id: 'ikhlas',
      surahNumber: 112,
      nameAr: 'الإخلاص',
      time: ReadingTime.morning,
      virtueAr: 'قل هو الله أحد تعدل ثلث القرآن.',
      sourceAr: 'رواه البخاري ومسلم',
      grade: NarrationGrade.agreed,
    ),
    SurahVirtue(
      id: 'baqarah',
      surahNumber: 2,
      nameAr: 'البقرة',
      time: ReadingTime.morning,
      virtueAr:
          'لا تجعلوا بيوتكم مقابر، إن الشيطان ينفر من البيت الذي تُقرأ فيه سورة البقرة.',
      sourceAr: 'رواه مسلم',
      grade: NarrationGrade.agreed,
    ),
    // The two below are read by a great many people every day. Their commonly
    // quoted virtues are not authenticated, and saying so is the honest thing
    // — the reading itself remains good, as reading any Quran is.
    SurahVirtue(
      id: 'yaseen',
      surahNumber: 36,
      nameAr: 'يس',
      time: ReadingTime.morning,
      virtueAr:
          'يقرؤها كثير من الناس أول النهار. وما اشتُهر في فضلها الخاص لم يثبت، وفضل قراءة القرآن ثابت على كل حال.',
      sourceAr: 'أحاديث فضلها الخاص ضعيفة — والقراءة خير في ذاتها',
      grade: NarrationGrade.weak,
    ),
    SurahVirtue(
      id: 'waqiah',
      surahNumber: 56,
      nameAr: 'الواقعة',
      time: ReadingTime.evening,
      virtueAr:
          'اشتُهر: «من قرأ سورة الواقعة كل ليلة لم تصبه فاقة أبدًا» — وهو حديث ضعيف عند أهل العلم.',
      sourceAr: 'رواه البيهقي وابن السني، وضعّفه المحققون',
      grade: NarrationGrade.weak,
    ),
  ];

  /// What to read at this point in the day, Friday included.
  static List<SurahVirtue> forTime(ReadingTime time) =>
      all.where((item) => item.time == time).toList();

  /// Only what rests on an authenticated narration.
  static List<SurahVirtue> get established =>
      all.where((item) => item.isEstablished).toList();

  static SurahVirtue? byId(String id) {
    for (final item in all) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Today's suggestion, rotating so the same surah is not offered every day.
  ///
  /// Friday always yields al-Kahf: it is the one reading tied to a day rather
  /// than an hour, and missing it means waiting a week.
  static SurahVirtue suggestionFor(DateTime date) {
    if (date.weekday == DateTime.friday) {
      return byId('kahf')!;
    }
    final pool = established;
    return pool[date.difference(DateTime(2020)).inDays % pool.length];
  }
}
