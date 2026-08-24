import 'package:quran/quran.dart' as quran;

import '../../../../core/services/data_saver.dart';
import 'verse_reciters.dart';
import 'quran_meta_data.dart';

/// A single verse with everything the reader needs to render and locate it.
class QuranVerse {
  const QuranVerse({
    required this.surahNumber,
    required this.numberInSurah,
    required this.globalNumber,
    required this.text,
    required this.juz,
    required this.page,
    required this.hizbQuarter,
    required this.surahNameAr,
    required this.surahNameEn,
    required this.isSajdah,
  });

  final int surahNumber;
  final int numberInSurah;

  /// 1-6236, the running verse number used by the audio CDN.
  final int globalNumber;

  final String text;
  final int juz;
  final int page;

  /// 1-240. Hizb `n` covers quarters `4n-3 .. 4n`.
  final int hizbQuarter;

  final String surahNameAr;
  final String surahNameEn;
  final bool isSajdah;

  /// `2:255` — the canonical way to address a verse.
  String get key => '$surahNumber:$numberInSurah';

  /// 1-60.
  int get hizb => ((hizbQuarter - 1) ~/ 4) + 1;

  /// 0 = start of the hizb, 1 = quarter, 2 = half, 3 = three quarters.
  int get quarterInHizb => (hizbQuarter - 1) % 4;

  /// True at the exact verse a quarter starts on.
  bool get startsHizbQuarter {
    final reference = hizbQuarterStarts[hizbQuarter - 1];
    return reference[0] == surahNumber && reference[1] == numberInSurah;
  }

  bool get isFirstOfSurah => numberInSurah == 1;
}

/// Surah index entry.
class QuranSurahInfo {
  const QuranSurahInfo({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.versesCount,
    required this.isMeccan,
    required this.firstPage,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final int versesCount;
  final bool isMeccan;
  final int firstPage;
}

/// The Quran, on the device.
///
/// Text, page/juz indexes, and verse audio URLs all come from the bundled
/// `quran` package, so opening the reader is instant and works with no
/// network at all. Nothing here performs I/O.
class QuranLocalService {
  QuranLocalService._();

  static const int surahCount = quran.totalSurahCount;
  static const int juzCount = quran.totalJuzCount;
  static const int pageCount = quran.totalPagesCount;
  static const int hizbCount = 60;
  static const int quarterCount = 240;
  static const int verseCount = 6236;

  static List<QuranSurahInfo>? _surahCache;

  /// Full surah index, built once per session.
  static List<QuranSurahInfo> surahs() {
    return _surahCache ??= List<QuranSurahInfo>.generate(surahCount, (index) {
      final id = index + 1;
      return QuranSurahInfo(
        id: id,
        nameAr: quran.getSurahNameArabic(id),
        nameEn: quran.getSurahName(id),
        versesCount: quran.getVerseCount(id),
        isMeccan: quran.getPlaceOfRevelation(id).toLowerCase() == 'makkah',
        firstPage: quran.getPageNumber(id, 1),
      );
    });
  }

  static QuranSurahInfo surahInfo(int surahNumber) {
    _assertSurah(surahNumber);
    return surahs()[surahNumber - 1];
  }

  /// The basmala exactly as the bundled text writes it.
  ///
  /// Taken from al-Fatihah, where it is a verse in its own right, so it always
  /// matches the spelling used elsewhere — the package writes الرَّحْمَـٰنِ with a
  /// dagger alef, which does not match the more common ٱلرَّحْمَٰنِ character for
  /// character. Comparing against a hand-typed constant would silently fail.
  static String get basmala => _basmala ??= quran.getVerse(1, 1).trim();
  static String? _basmala;

  /// The text of one verse as the app shows it.
  ///
  /// Every reader of the bundled text goes through here, so the page, the
  /// search, and the corpus all agree on what a verse says.
  static String verseText(int surahNumber, int verseNumber) =>
      stripLeadingBasmala(
        quran.getVerse(surahNumber, verseNumber),
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );

  /// The verse text without the basmala the source glues onto it.
  ///
  /// Every surah's first verse arrives with the basmala prepended, except
  /// al-Fatihah (where it is verse 1) and at-Tawbah (which has none). The
  /// reader draws the basmala itself as a centred line above the text, so it
  /// appeared twice — once in the header and again at the head of verse 1.
  ///
  /// Only the very start of a first verse is touched. An-Naml 30 quotes the
  /// basmala inside the verse — «إِنَّهُ مِنْ سُلَيْمَانَ وَإِنَّهُ بِسْمِ اللَّهِ...» — and
  /// stripping it from anywhere but the front would delete revelation.
  static String stripLeadingBasmala(
    String text, {
    required int surahNumber,
    required int verseNumber,
  }) {
    if (verseNumber != 1 || surahNumber == 1 || surahNumber == 9) {
      return text;
    }
    if (!text.startsWith(basmala)) {
      return text;
    }
    return text.substring(basmala.length).trimLeft();
  }

  static QuranVerse verse(int surahNumber, int verseNumber) {
    _assertSurah(surahNumber);
    final count = quran.getVerseCount(surahNumber);
    if (verseNumber < 1 || verseNumber > count) {
      throw ArgumentError(
        'Verse $verseNumber is out of range for surah '
        '$surahNumber (1-$count)',
      );
    }

    final info = surahInfo(surahNumber);
    return QuranVerse(
      surahNumber: surahNumber,
      numberInSurah: verseNumber,
      globalNumber: globalVerseNumber(surahNumber, verseNumber),
      text: verseText(surahNumber, verseNumber),
      juz: quran.getJuzNumber(surahNumber, verseNumber),
      page: quran.getPageNumber(surahNumber, verseNumber),
      hizbQuarter: hizbQuarterOf(surahNumber, verseNumber),
      surahNameAr: info.nameAr,
      surahNameEn: info.nameEn,
      isSajdah: isSajdahVerse(surahNumber, verseNumber),
    );
  }

  /// Every verse of a surah, in order.
  static List<QuranVerse> versesOfSurah(int surahNumber) {
    _assertSurah(surahNumber);
    final count = quran.getVerseCount(surahNumber);
    return List<QuranVerse>.generate(
      count,
      (index) => verse(surahNumber, index + 1),
    );
  }

  /// Every verse of a juz, in order, across surah boundaries.
  static List<QuranVerse> versesOfJuz(int juzNumber) {
    if (juzNumber < 1 || juzNumber > juzCount) {
      throw ArgumentError('Juz must be between 1 and $juzCount');
    }

    final ranges = quran.getSurahAndVersesFromJuz(juzNumber);
    final verses = <QuranVerse>[];
    final surahNumbers = ranges.keys.toList()..sort();

    for (final surahNumber in surahNumbers) {
      final range = ranges[surahNumber]!;
      for (var ayah = range.first; ayah <= range.last; ayah++) {
        verses.add(verse(surahNumber, ayah));
      }
    }
    return verses;
  }

  /// Every verse printed on a Mushaf page.
  static List<QuranVerse> versesOfPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > pageCount) {
      throw ArgumentError('Page must be between 1 and $pageCount');
    }

    final verses = <QuranVerse>[];
    for (final entry in quran.getPageData(pageNumber)) {
      final surahNumber = entry['surah'] as int;
      final start = entry['start'] as int;
      final end = entry['end'] as int;
      for (var ayah = start; ayah <= end; ayah++) {
        verses.add(verse(surahNumber, ayah));
      }
    }
    return verses;
  }

  /// Every verse of a hizb quarter (1-240).
  static List<QuranVerse> versesOfHizbQuarter(int quarter) {
    if (quarter < 1 || quarter > quarterCount) {
      throw ArgumentError('Quarter must be between 1 and $quarterCount');
    }

    final start = globalVerseNumber(
      hizbQuarterStarts[quarter - 1][0],
      hizbQuarterStarts[quarter - 1][1],
    );
    final end =
        quarter == quarterCount
            ? verseCount
            : globalVerseNumber(
                  hizbQuarterStarts[quarter][0],
                  hizbQuarterStarts[quarter][1],
                ) -
                1;

    return [
      for (var global = start; global <= end; global++)
        verseByGlobalNumber(global),
    ];
  }

  /// Every verse of a hizb (1-60): four consecutive quarters.
  static List<QuranVerse> versesOfHizb(int hizb) {
    if (hizb < 1 || hizb > hizbCount) {
      throw ArgumentError('Hizb must be between 1 and $hizbCount');
    }

    final verses = <QuranVerse>[];
    for (var quarter = (hizb - 1) * 4 + 1; quarter <= hizb * 4; quarter++) {
      verses.addAll(versesOfHizbQuarter(quarter));
    }
    return verses;
  }

  /// Which of the 240 quarters a verse belongs to.
  static int hizbQuarterOf(int surahNumber, int verseNumber) {
    final global = globalVerseNumber(surahNumber, verseNumber);

    var low = 0;
    var high = hizbQuarterStarts.length - 1;
    var result = 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final start = globalVerseNumber(
        hizbQuarterStarts[mid][0],
        hizbQuarterStarts[mid][1],
      );
      if (start <= global) {
        result = mid + 1;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }

  /// Where a quarter begins.
  static QuranVerse hizbQuarterStart(int quarter) {
    final safe = quarter.clamp(1, quarterCount);
    final reference = hizbQuarterStarts[safe - 1];
    return verse(reference[0], reference[1]);
  }

  /// Where a hizb begins.
  static QuranVerse hizbStart(int hizb) =>
      hizbQuarterStart((hizb.clamp(1, hizbCount) - 1) * 4 + 1);

  /// Where a page begins, for the page index.
  static QuranVerse pageStart(int pageNumber) {
    final data = quran.getPageData(pageNumber.clamp(1, pageCount));
    final first = data.first;
    return verse(first['surah'] as int, first['start'] as int);
  }

  /// Surah names printed on a page, in order.
  static List<String> surahNamesOnPage(int pageNumber) {
    return [
      for (final entry in quran.getPageData(pageNumber.clamp(1, pageCount)))
        quran.getSurahNameArabic(entry['surah'] as int),
    ];
  }

  /// The 15 sajdah verses, in Mushaf order.
  static List<QuranVerse> sajdahList() {
    return [
      for (final reference in sajdahVerses) verse(reference[0], reference[1]),
    ];
  }

  static bool isSajdahVerse(int surahNumber, int verseNumber) {
    for (final reference in sajdahVerses) {
      if (reference[0] == surahNumber && reference[1] == verseNumber) {
        return true;
      }
    }
    return false;
  }

  /// Pages a surah spans, for the reader's page indicator.
  static List<int> pagesOfSurah(int surahNumber) {
    _assertSurah(surahNumber);
    return quran.getSurahPages(surahNumber);
  }

  /// Running 1-6236 verse number.
  static int globalVerseNumber(int surahNumber, int verseNumber) {
    var total = 0;
    for (var surah = 1; surah < surahNumber; surah++) {
      total += quran.getVerseCount(surah);
    }
    return total + verseNumber;
  }

  /// Reverse of [globalVerseNumber].
  static QuranVerse verseByGlobalNumber(int globalNumber) {
    var remaining = globalNumber.clamp(1, verseCount);
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = quran.getVerseCount(surah);
      if (remaining <= count) {
        return verse(surah, remaining);
      }
      remaining -= count;
    }
    return verse(1, 1);
  }

  /// A stable verse for a given day — same verse for everyone, all day long.
  static QuranVerse verseOfTheDay(DateTime date) {
    final dayNumber =
        DateTime(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime(2000, 1, 1)).inDays;
    final index = (dayNumber.abs() * 7919) % verseCount;
    return verseByGlobalNumber(index + 1);
  }

  /// Offline verse search that ignores diacritics and letter variants.
  ///
  /// Returns matches in Mushaf order; [limit] keeps the result list bounded
  /// for the UI.
  static List<QuranVerse> search(String query, {int limit = 60}) {
    final needle = normalizeArabic(query);
    if (needle.length < 2) {
      return const [];
    }

    final results = <QuranVerse>[];
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = quran.getVerseCount(surah);
      for (var ayah = 1; ayah <= count; ayah++) {
        final text = normalizeArabic(verseText(surah, ayah));
        if (text.contains(needle)) {
          results.add(verse(surah, ayah));
          if (results.length >= limit) {
            return results;
          }
        }
      }
    }
    return results;
  }

  /// Surah name search for the index screen (Arabic or English, accent-free).
  static List<QuranSurahInfo> searchSurahs(String query) {
    final needle = normalizeArabic(query);
    if (needle.isEmpty) {
      return surahs();
    }

    final lower = query.trim().toLowerCase();
    return surahs().where((surah) {
      return normalizeArabic(surah.nameAr).contains(needle) ||
          surah.nameEn.toLowerCase().contains(lower) ||
          surah.id.toString() == lower;
    }).toList();
  }

  /// Per-ayah audio for the reader's player, the memorisation loop, the
  /// ruqyah queue and the verse video.
  ///
  /// It used to come from the islamic.network CDN, which turned out to serve
  /// only ten of its many editions per ayah and to answer 403 for the rest —
  /// including Sudais, who was in the app's own list of seven, so the verse
  /// player had been quietly broken on him. Every voice in [VerseReciters] was
  /// requested and answered before it was written down.
  ///
  /// The data saver picks the smaller recording of the same voice where the
  /// host publishes one — it stores each bitrate as its own directory rather
  /// than as a parameter, so this is a different folder, not a smaller number
  /// in the URL. [small] overrides the setting, for callers that know better.
  static String audioUrlForVerse(
    int surahNumber,
    int verseNumber, {
    String reciterCode = VerseReciters.defaultId,
    bool? small,
  }) {
    _assertSurah(surahNumber);
    return VerseReciters.byId(
      reciterCode,
    ).urlFor(surahNumber, verseNumber, small: small ?? DataSaver.isEnabled);
  }

  /// Whole-surah audio from the same CDN.
  /// Where each reciter's whole-surah recordings live, on mp3quran.net.
  ///
  /// Verse-by-verse audio comes from the islamic.network CDN, which carries
  /// every edition. Whole surahs there are a different matter: only ar.alafasy
  /// answers and every other edition returns 403, which reached the player as
  /// a bare PlayerException. So the surah player worked on the default voice
  /// and failed on all the rest — the error was real, but it was the address
  /// that was wrong, not the player.
  static const Map<String, String> surahAudioHosts = {
    'ar.alafasy': 'https://server8.mp3quran.net/afs',
    'ar.mahermuaiqly': 'https://server12.mp3quran.net/maher',
    'ar.husary': 'https://server13.mp3quran.net/husr',
    'ar.minshawi': 'https://server10.mp3quran.net/minsh',
    'ar.abdurrahmaansudais': 'https://server11.mp3quran.net/sds',
    'ar.shaatree': 'https://server11.mp3quran.net/shatri',
    'ar.ahmedajamy': 'https://server10.mp3quran.net/ajm',
  };

  /// Hosts learned at runtime from the full reciter catalogue.
  ///
  /// The bundled seven are a floor, not the whole list: the catalogue fetches
  /// every recording mp3quran publishes and registers them here, so a voice
  /// chosen from it resolves the same way a bundled one does.
  static final Map<String, String> _registeredHosts = {};

  static void registerSurahHost(String reciterCode, String server) {
    if (reciterCode.isEmpty || !server.startsWith('https://')) {
      return;
    }
    _registeredHosts[reciterCode] = server;
  }

  /// Whether this voice has whole-surah recordings at all.
  static bool hasSurahAudio(String reciterCode) =>
      surahAudioHosts.containsKey(reciterCode) ||
      _registeredHosts.containsKey(reciterCode);

  /// The whole-surah recording, from whichever host actually serves it.
  static String audioUrlForSurah(
    int surahNumber, {
    String reciterCode = 'ar.alafasy',
    int bitrate = 128,
  }) {
    _assertSurah(surahNumber);

    final host = _registeredHosts[reciterCode] ?? surahAudioHosts[reciterCode];
    if (host != null) {
      final base = host.endsWith('/') ? host : '$host/';
      return '$base${surahNumber.toString().padLeft(3, '0')}.mp3';
    }
    // A voice this build has never heard of: try the CDN and let the caller
    // report what comes back.
    return 'https://cdn.islamic.network/quran/audio-surah/$bitrate/$reciterCode/$surahNumber.mp3';
  }

  static String? _normalizedCorpus;
  static Set<int>? _quranNgrams;

  /// The whole Mushaf, normalized, as one searchable string.
  ///
  /// Built once and kept: used to tell Quranic text apart from du'a inside
  /// azkar, and available to any other exact-match lookup.
  static String normalizedCorpus() {
    if (_normalizedCorpus != null) {
      return _normalizedCorpus!;
    }

    final buffer = StringBuffer();
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = quran.getVerseCount(surah);
      for (var ayah = 1; ayah <= count; ayah++) {
        // Single space between verses, so a quotation that runs across two
        // verses still matches.
        buffer
          ..write(normalizeArabic(verseText(surah, ayah)))
          ..write(' ');
      }
    }
    return _normalizedCorpus = buffer.toString();
  }

  /// Every four-word sequence in the Mushaf, hashed.
  ///
  /// Quoting collections spell the Quran differently — dagger alef versus a
  /// written one, `النفثت` versus `النفاثات` — so matching a whole passage
  /// verbatim fails on a single word. Scoring a passage by how many of its
  /// four-word windows exist in the Mushaf tolerates the spelling and still
  /// refuses ordinary supplication, which shares only the odd phrase.
  ///
  /// The windows run across verse boundaries, because a quoted surah is read
  /// as one continuous passage.
  static Set<int> quranNgrams() {
    if (_quranNgrams != null) {
      return _quranNgrams!;
    }

    final words = <String>[];
    for (var surah = 1; surah <= surahCount; surah++) {
      final count = quran.getVerseCount(surah);
      for (var ayah = 1; ayah <= count; ayah++) {
        words.addAll(skeleton(verseText(surah, ayah)).split(' '));
      }
    }
    words.removeWhere((word) => word.isEmpty);

    final ngrams = <int>{};
    for (var i = 0; i + ngramSize <= words.length; i++) {
      ngrams.add(_hashWindow(words, i));
    }
    return _quranNgrams = ngrams;
  }

  /// Words per matching window.
  static const int ngramSize = 4;

  static int _hashWindow(List<String> words, int start) {
    var hash = 0x811c9dc5;
    for (var i = start; i < start + ngramSize; i++) {
      for (final unit in words[i].codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xffffffff;
      }
      hash ^= 0x20;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Hash of one window of [words] starting at [start]; null when the window
  /// runs past the end.
  static int? windowHash(List<String> words, int start) {
    if (start < 0 || start + ngramSize > words.length) {
      return null;
    }
    return _hashWindow(words, start);
  }

  /// A spelling-insensitive skeleton: normalized, then stripped of alef.
  ///
  /// Alef is where Uthmani and modern orthography disagree most (the dagger
  /// alef in `الرَّحْمَٰن` against the written one in `الرحمان`), so dropping it
  /// makes both spellings compare equal.
  static String skeleton(String input) {
    return normalizeArabic(
      input,
    ).replaceAll('ا', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Strip diacritics and normalize letter variants so search matches what
  /// people actually type.
  static String normalizeArabic(String input) {
    final stripped = input
        .replaceAll(RegExp(r'[ً-ْٰۖ-ۭـ]'), '')
        .replaceAll(RegExp(r'[آأإٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        // Punctuation differs between datasets; matching must not depend on it.
        .replaceAll(
          RegExp(r'[،؛؟!.,:«»"\u2018\u2019\u201C\u201D()\[\]{}﴿﴾۩\u06dd-]'),
          ' ',
        );

    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static void _assertSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > surahCount) {
      throw ArgumentError('Surah must be between 1 and $surahCount');
    }
  }
}
