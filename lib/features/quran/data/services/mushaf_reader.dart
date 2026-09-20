import '../../domain/entities/riwaya.dart';
import 'mushaf_service.dart';
import 'quran_local_service.dart';

/// The verses of the Qur'an in whichever reading the reader has chosen.
///
/// Everything above this point in the app — the index, the juz and hizb
/// markers, bookmarks, the wird, the last-read position, the audio queue —
/// speaks [QuranVerse]. Rather than teach all of it a second shape, a
/// non-Hafs mushaf is returned in the same one: its own text, its own verse
/// numbers and its own pagination, with the juz, hizb and Hafs page carried
/// over from the Hafs verse it corresponds to.
///
/// That correspondence is the provider's, not a guess. Warsh's opening verse
/// of al-Fatiha covers Hafs 1 and 2; al-Tawbah gains a verse and al-Baqarah
/// loses one. Deriving the division marks from the mapped Hafs verse keeps a
/// reader who switches reading on the same juz and the same hizb, rather than
/// drifting by a verse for the length of a surah.
class MushafReader {
  MushafReader._();

  /// The reading the app is set to.
  ///
  /// Mirrored out of `ReaderSettings` on every change so that code with no
  /// `Ref` to hand — a notification body, a share card, a widget built deep
  /// inside a list — shows the same text as the reader does. It is a cache of
  /// a preference, never the place the preference is decided.
  static MushafEdition current = MushafEdition.hafs;

  /// The surah as [edition] reads it.
  ///
  /// Returns empty when the other text is not on the device and cannot be
  /// fetched. The caller says so on screen rather than falling back silently —
  /// Hafs under a Warsh heading is exactly the substitution this change exists
  /// to end.
  static Future<List<QuranVerse>> versesOfSurah(
    MushafEdition edition,
    int surahNumber,
  ) async {
    if (edition == MushafEdition.hafs) {
      return QuranLocalService.versesOfSurah(surahNumber);
    }

    final verses = await MushafService.surah(edition, surahNumber);
    if (verses.isEmpty) {
      return const [];
    }

    return buildVerses(edition, surahNumber, verses);
  }

  /// The same selection as [hafsVerses], read in [edition].
  ///
  /// This is what makes a juz, a hizb and a page obey the reader's choice.
  /// The **division** stays where Hafs puts it: a juz boundary is a fact about
  /// the Hafs index the whole app is built on, the provider publishes its
  /// mushafs a surah at a time, and moving the boundaries as well would shift
  /// every saved position. What changes is the text on the page, which is the
  /// thing the reader actually reads.
  ///
  /// A verse is included when it carries any part of a requested Hafs verse,
  /// so a merged verse — Warsh's al-Fatiha 1, which is Hafs 1 and 2 — appears
  /// once and whole rather than half of it going missing at a boundary.
  ///
  /// Returns empty unless **every** surah in the selection is available, since
  /// a page that is Warsh above the surah break and Hafs below it is worse
  /// than a page that admits it could not fetch the reading.
  static Future<List<QuranVerse>> versesLike(
    MushafEdition edition,
    List<QuranVerse> hafsVerses,
  ) async {
    if (edition == MushafEdition.hafs || hafsVerses.isEmpty) {
      return hafsVerses;
    }

    final wanted = _group(hafsVerses);
    final result = <QuranVerse>[];
    for (final entry in wanted.entries) {
      final source = await MushafService.surah(edition, entry.key);
      final slice = _slice(edition, entry.key, entry.value, source);
      if (slice.isEmpty) {
        return const [];
      }
      result.addAll(slice);
    }
    return result;
  }

  /// [versesLike] without waiting, for a builder that cannot await.
  ///
  /// Null when any surah in the selection is not in memory yet. The caller
  /// draws Hafs for that one frame and calls [warmAll], which makes the next
  /// build succeed — the page-turning view flips through the whole book, so
  /// the surahs it needs are not known until the reader gets there.
  static List<QuranVerse>? versesLikeSync(
    MushafEdition edition,
    List<QuranVerse> hafsVerses,
  ) {
    if (edition == MushafEdition.hafs || hafsVerses.isEmpty) {
      return hafsVerses;
    }

    final result = <QuranVerse>[];
    for (final entry in _group(hafsVerses).entries) {
      final source = MushafService.inMemory(edition, entry.key);
      if (source == null) {
        return null;
      }
      final slice = _slice(edition, entry.key, entry.value, source);
      if (slice.isEmpty) {
        return null;
      }
      result.addAll(slice);
    }
    return result;
  }

  /// Fetch every surah a selection touches, so a later [versesLikeSync] works.
  static Future<void> warmAll(
    Iterable<int> surahNumbers, {
    MushafEdition? edition,
  }) async {
    for (final surahNumber in surahNumbers) {
      await warm(surahNumber, edition: edition);
    }
  }

  /// The surahs a selection touches, and which Hafs verses of each.
  ///
  /// Insertion-ordered, so a juz that runs from the end of one surah into the
  /// next comes back the way the reader reads it.
  static Map<int, Set<int>> _group(List<QuranVerse> hafsVerses) {
    final wanted = <int, Set<int>>{};
    for (final verse in hafsVerses) {
      wanted
          .putIfAbsent(verse.surahNumber, () => <int>{})
          .add(verse.hafsVerseNumber);
    }
    return wanted;
  }

  static List<QuranVerse> _slice(
    MushafEdition edition,
    int surahNumber,
    Set<int> hafsNumbers,
    List<MushafVerse> source,
  ) {
    if (source.isEmpty) {
      return const [];
    }
    final slice = [
      for (final verse in source)
        if (hafsNumbers.any(verse.coversHafs)) verse,
    ];
    return slice.isEmpty ? const [] : buildVerses(edition, surahNumber, slice);
  }

  /// Put a surah of [current] within reach of [textOf].
  ///
  /// Anything that draws a single ayah outside the reader calls this once and
  /// then rebuilds; until it resolves, [textOf] answers in Hafs.
  static Future<void> warm(int surahNumber, {MushafEdition? edition}) async {
    final target = edition ?? current;
    if (target == MushafEdition.hafs) {
      return;
    }
    await MushafService.surah(target, surahNumber);
  }

  /// The text of a Hafs-addressed verse, in [current], without waiting.
  ///
  /// Every place in the app that shows one ayah outside the reader — the ayah
  /// of the day, a bookmark preview, a share card, a memorisation prompt —
  /// asks here. The address stays Hafs on purpose: that is what those records
  /// are stored in, and re-storing them per reading would strand every
  /// bookmark a reader already has.
  ///
  /// Answers in Hafs when the other mushaf is not in memory yet. That is a
  /// fallback with a visible remedy ([warm]), not a silent substitution: the
  /// reader's own page never takes this path.
  /// All of it: where this reading splits the Hafs verse in two, both halves
  /// are joined, because half an ayah is not an answer.
  static String textOf(int surahNumber, int hafsVerse) {
    final verses = _inMemoryVerses(surahNumber, hafsVerse);
    if (verses.isEmpty) {
      return QuranLocalService.verseText(surahNumber, hafsVerse);
    }
    return verses.map((verse) => verse.text).join(' ');
  }

  /// How this reading numbers that verse: `٢٨٥`, or `٧٠-٧١` where it splits it.
  ///
  /// So a share card or a note reads «البقرة ٢٨٥» to a Warsh reader and
  /// «البقرة ٢٨٦» to a Hafs one, for the same stored bookmark.
  static String numberLabelOf(int surahNumber, int hafsVerse) {
    final verses = _inMemoryVerses(surahNumber, hafsVerse);
    if (verses.isEmpty) {
      return '$hafsVerse';
    }
    if (verses.length == 1) {
      return '${verses.first.number}';
    }
    return '${verses.first.number}-${verses.last.number}';
  }

  /// A full record for a Hafs address, in [current] where it is loaded.
  ///
  /// One record even where this reading splits the verse in two: the text is
  /// both halves and the number is the first. Anything showing a range of
  /// verses should call [rangeOf], which keeps the halves apart.
  static QuranVerse verseOf(int surahNumber, int hafsVerse) {
    final reference = QuranLocalService.verse(surahNumber, hafsVerse);
    final verse = _inMemoryVerse(surahNumber, hafsVerse);
    if (verse == null) {
      return reference;
    }
    return QuranVerse(
      surahNumber: surahNumber,
      numberInSurah: verse.number,
      globalNumber: reference.globalNumber,
      text: textOf(surahNumber, hafsVerse),
      juz: reference.juz,
      // The Hafs leaf, as everywhere else — see [buildVerses]. This field
      // indexes the reading log and the page view, not just a label.
      page: reference.page,
      hizbQuarter: reference.hizbQuarter,
      surahNameAr: reference.surahNameAr,
      surahNameEn: reference.surahNameEn,
      isSajdah: reference.isSajdah,
      hafsNumberInSurah: hafsVerse,
    );
  }

  /// A run of Hafs-addressed verses, as [current] divides them.
  ///
  /// Not one verse per Hafs number — the readings disagree about where verses
  /// end in **both** directions, and a loop over the numbers gets both wrong.
  /// Warsh and Qalun open al-Fatiha with one verse covering Hafs 1 and 2, so
  /// that loop returns the same verse twice; and they split Hafs 9:70 into two
  /// verses, so it returns only the first of them and the rest of the words
  /// never appear. Taking every verse that carries any part of the range,
  /// once, is right in both directions.
  static List<QuranVerse> rangeOf(int surahNumber, int fromHafs, int toHafs) {
    final source =
        current == MushafEdition.hafs
            ? null
            : MushafService.inMemory(current, surahNumber);
    if (source == null) {
      return [
        for (var hafs = fromHafs; hafs <= toHafs; hafs++)
          QuranLocalService.verse(surahNumber, hafs),
      ];
    }

    final wanted = {for (var hafs = fromHafs; hafs <= toHafs; hafs++) hafs};
    return buildVerses(current, surahNumber, [
      for (final verse in source)
        if (wanted.any(verse.coversHafs)) verse,
    ]);
  }

  /// Every verse of [current] carrying any part of one Hafs verse.
  ///
  /// Usually one. Two where this reading splits that Hafs verse, which Warsh
  /// and Qalun do at al-Tawbah 70 among others — and where returning only the
  /// first would drop half the words with nothing to show it had happened.
  static List<MushafVerse> _inMemoryVerses(int surahNumber, int hafsVerse) {
    if (current == MushafEdition.hafs) {
      return const [];
    }
    final source = MushafService.inMemory(current, surahNumber);
    if (source == null) {
      return const [];
    }
    return [
      for (final verse in source)
        if (verse.coversHafs(hafsVerse)) verse,
    ];
  }

  static MushafVerse? _inMemoryVerse(int surahNumber, int hafsVerse) {
    final verses = _inMemoryVerses(surahNumber, hafsVerse);
    return verses.isEmpty ? null : verses.first;
  }

  /// Turn a fetched mushaf into the shape the rest of the app reads.
  ///
  /// Separate from the fetch so it can be tested without a network or a disk.
  static List<QuranVerse> buildVerses(
    MushafEdition edition,
    int surahNumber,
    List<MushafVerse> source,
  ) {
    final info = QuranLocalService.surahInfo(surahNumber);
    final hafsCount = info.versesCount;

    return [
      for (final verse in source)
        () {
          // The Hafs verse this one stands on, for the divisions. Clamped
          // because a reading can carry a verse the other does not — Warsh
          // numbers al-Tawbah to 130 where Hafs stops at 129 — and the last
          // verse of a surah is still inside that surah's last juz.
          final hafsNumber = verse.primaryHafsNumber.clamp(1, hafsCount);
          final reference = QuranLocalService.verse(surahNumber, hafsNumber);

          return QuranVerse(
            surahNumber: surahNumber,
            numberInSurah: verse.number,
            globalNumber: reference.globalNumber,
            text: verse.text,
            juz: reference.juz,
            // The Hafs leaf, not this mushaf's own.
            //
            // It is tempting to give a Warsh reader the pages of the book in
            // front of them, and it was wrong: this number is not only a
            // label. It indexes the page-turning view, the reading log behind
            // the streak and the khatmah plan, the "you have read three
            // quarters of al-Kahf" follow-up — every one of them defined over
            // the 604 Hafs leaves. Carrying two meanings in one field made
            // each of those count a different book. The divisions follow Hafs
            // for the same reason the juz and the hizb do; the words on the
            // page are the reader's own.
            page: reference.page,
            hizbQuarter: reference.hizbQuarter,
            surahNameAr: info.nameAr,
            surahNameEn: info.nameEn,
            isSajdah: reference.isSajdah,
            // Carried so the audio layer can ask a Hafs-numbered recording for
            // the right file. Two of the three Warsh recitations are filed
            // that way, and without this they recite the neighbouring ayah all
            // the way down the surah.
            hafsNumberInSurah: hafsNumber,
            // And all of them, for finding this verse from a stored Hafs
            // address. A merged verse answers to two, and searching by the
            // first alone loses every reference to the second.
            hafsNumbersInSurah: verse.hafsNumbers,
          );
        }(),
    ];
  }
}
