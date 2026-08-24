/// The 136 chapters of Hisn al-Muslim, grouped by the situation you are in.
///
/// The flat list is complete and searchable, but nobody browses 136 rows to
/// find what to say on a journey. The grouping is by chapter number rather
/// than by keyword because the book is already ordered by subject — chapters
/// 94 to 104 are the travel chapters, in the order Ibn Qayyim's arrangement
/// puts them, and reordering them by string matching would only scramble that.
library;

/// One shelf of the library.
enum DuaTheme {
  day,
  prayer,
  home,
  distress,
  family,
  illness,
  nature,
  travel,
  hajj,
  manners,
  remembrance,
  ruqyah,
}

extension DuaThemeInfo on DuaTheme {
  /// The localization key for the shelf's name.
  String get labelKey => 'dua_theme_$name';

  /// A one-line description of what is on it.
  String get descriptionKey => 'dua_theme_${name}_desc';
}

/// Which shelf a chapter sits on.
class DuaLibrary {
  DuaLibrary._();

  /// The whole book, in order.
  static const int chapterCount = 136;

  /// Chapters whose id in `azkar.json` is a word rather than `hisn_N`.
  ///
  /// They are the same chapters in the same positions; only the ids were made
  /// readable because other screens link straight to them.
  static const Map<String, int> namedChapters = {
    'morning': 1,
    'evening': 2,
    'wakeup': 3,
    'adhan': 16,
    'salat_opening': 17,
    'sujood': 20,
    'after_prayer': 26,
    'sleep': 28,
    'worry': 34,
    'distress': 35,
    'tasbeeh': 136,
  };

  /// The chapter number behind a category id, or null if it is not one.
  static int? chapterOf(String categoryId) {
    final named = namedChapters[categoryId];
    if (named != null) {
      return named;
    }
    if (!categoryId.startsWith('hisn_')) {
      return null;
    }
    final number = int.tryParse(categoryId.substring(5));
    if (number == null || number < 1 || number > chapterCount) {
      return null;
    }
    return number;
  }

  /// Which shelf a category belongs on.
  ///
  /// Anything the book does not account for lands on [DuaTheme.remembrance]
  /// rather than nowhere: a chapter that appears on no shelf is a chapter the
  /// library has quietly lost.
  static DuaTheme themeOf(String categoryId) {
    final chapter = chapterOf(categoryId);
    if (chapter == null) {
      return DuaTheme.remembrance;
    }
    return themeOfChapter(chapter);
  }

  static DuaTheme themeOfChapter(int chapter) {
    // Waking, morning, evening, the night, and going back to sleep.
    if (chapter <= 3 || (chapter >= 28 && chapter <= 33) || chapter == 134) {
      return DuaTheme.day;
    }
    // Wudu, the walk to the mosque, the adhan, and everything inside the
    // prayer through to the remembrance that follows it.
    if ((chapter >= 7 && chapter <= 10) || (chapter >= 13 && chapter <= 27)) {
      return DuaTheme.prayer;
    }
    // Dressing, entering and leaving the house, eating and fasting.
    if ((chapter >= 4 && chapter <= 6) ||
        chapter == 11 ||
        chapter == 12 ||
        (chapter >= 67 && chapter <= 75)) {
      return DuaTheme.home;
    }
    // Worry, grief, debt, fear, an enemy, whispering doubts.
    if (chapter >= 34 && chapter <= 45) {
      return DuaTheme.distress;
    }
    // A newborn, protecting children, and marriage.
    if (chapter == 46 || chapter == 47 || (chapter >= 78 && chapter <= 80)) {
      return DuaTheme.family;
    }
    // Visiting the sick through to burial and visiting graves.
    if (chapter >= 48 && chapter <= 59) {
      return DuaTheme.illness;
    }
    // Wind, thunder, rain, the new moon.
    if (chapter >= 60 && chapter <= 66) {
      return DuaTheme.nature;
    }
    // Riding out, entering a town, stopping for the night, coming home.
    if (chapter >= 94 && chapter <= 104) {
      return DuaTheme.travel;
    }
    // Ihram through to the stoning.
    if (chapter >= 114 && chapter <= 120) {
      return DuaTheme.hajj;
    }
    // Salawat, greetings, and the remembrance chapters that close the book.
    if (chapter == 106 ||
        (chapter >= 128 && chapter <= 130) ||
        chapter == 135 ||
        chapter == 136) {
      return DuaTheme.remembrance;
    }
    // The two ruqyah chapters, kept together and on their own.
    if (chapter == 132 || chapter == 133) {
      return DuaTheme.ruqyah;
    }
    // Sneezing, sitting with people, praise, being wronged, good news — the
    // manners chapters, which are scattered through the second half.
    return DuaTheme.manners;
  }

  /// Every chapter on a shelf, in the book's order.
  static List<int> chaptersOf(DuaTheme theme) => [
    for (var chapter = 1; chapter <= chapterCount; chapter++)
      if (themeOfChapter(chapter) == theme) chapter,
  ];

  /// The two chapters the ruqyah screen reads, in order: the Qur'an first,
  /// then what is narrated from the Sunnah.
  static const List<String> ruqyahCategoryIds = ['hisn_132', 'hisn_133'];
}
