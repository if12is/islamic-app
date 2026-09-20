import '../../domain/entities/riwaya.dart';
import 'quran_local_service.dart';
import 'warsh_mushaf_service.dart';

/// The verses of a surah in whichever reading the reader has chosen.
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

  /// The surah as [edition] reads it.
  ///
  /// Falls back to Hafs when the other text is not on the device and cannot be
  /// fetched. The caller is told which it got via [WarshMushafService.isCached]
  /// or by comparing lengths — silently showing Hafs under a Warsh heading is
  /// exactly the substitution this change exists to end, so the reader is told
  /// on screen rather than left to notice.
  static Future<List<QuranVerse>> versesOfSurah(
    MushafEdition edition,
    int surahNumber,
  ) async {
    if (edition == MushafEdition.hafs) {
      return QuranLocalService.versesOfSurah(surahNumber);
    }

    final verses = await WarshMushafService.surah(edition, surahNumber);
    if (verses.isEmpty) {
      return const [];
    }

    return buildVerses(edition, surahNumber, verses);
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
            // This mushaf's own leaf, not the Hafs one: a Warsh reader turning
            // pages is turning the pages of the book in front of them.
            page: verse.page,
            hizbQuarter: reference.hizbQuarter,
            surahNameAr: info.nameAr,
            surahNameEn: info.nameEn,
            isSajdah: reference.isSajdah,
            // Carried so the audio layer can ask a Hafs-numbered recording for
            // the right file. Two of the three Warsh recitations are filed
            // that way, and without this they recite the neighbouring ayah all
            // the way down the surah.
            hafsNumberInSurah: hafsNumber,
          );
        }(),
    ];
  }
}
