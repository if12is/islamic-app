import '../data/services/warsh_mushaf_service.dart';
import 'entities/riwaya.dart';

/// Lines up one reading's verse numbers with another's.
///
/// Two readings of the same surah do not agree on where the verses end. Hafs
/// counts al-Baqarah at 286 and al-Tawbah at 129; Warsh counts them at 285 and
/// 130. Al-Fatiha has seven in both, but not the same seven — Warsh's first
/// verse is Hafs's first and second together.
///
/// Nothing warns you about this. A recording indexed under one scheme, asked
/// for a number from the other, returns a neighbouring ayah rather than an
/// error, and goes on doing it for the length of the surah. So every crossing
/// between a number on the page and a number in a URL, a bookmark or a saved
/// position has to go through here.
class VerseAlignment {
  const VerseAlignment._();

  /// The verse number to ask a recording for.
  ///
  /// [verseNumber] is what the reader is looking at, in [edition]'s counting.
  /// [recordingCounting] is how the recording's own files are numbered, which
  /// is a property of the recording and not of the reading it recites: two of
  /// the three Warsh recordings on the per-ayah host are filed under Hafs
  /// numbers.
  ///
  /// [surahVerses] is the surah in [edition], carrying the mapping the
  /// provider supplies. When it is missing the number is passed through — the
  /// honest fallback, since inventing an offset would be a guess that sounds
  /// exactly like a correct answer.
  static int audioVerseNumber({
    required MushafEdition edition,
    required VerseCounting recordingCounting,
    required int verseNumber,
    required List<MushafVerse> surahVerses,
  }) {
    if (edition.counting == recordingCounting) {
      return verseNumber;
    }

    if (edition.counting == VerseCounting.hafs) {
      // Reading Hafs, recording numbered the other way.
      return _toEditionNumber(verseNumber, surahVerses);
    }

    // Reading a non-Hafs mushaf, recording numbered in Hafs.
    for (final verse in surahVerses) {
      if (verse.number == verseNumber) {
        return verse.primaryHafsNumber;
      }
    }
    return verseNumber;
  }

  /// The Hafs verse number for a verse of [surahVerses].
  ///
  /// What a bookmark, a last-read position and a wird reference are stored in,
  /// so that a reader who switches reading keeps their place instead of
  /// landing a verse or two off.
  static int toHafs(int verseNumber, List<MushafVerse> surahVerses) {
    for (final verse in surahVerses) {
      if (verse.number == verseNumber) {
        return verse.primaryHafsNumber;
      }
    }
    return verseNumber;
  }

  /// The verse of [surahVerses] that contains Hafs verse [hafsNumber].
  ///
  /// The inverse, and not a symmetrical one: a Warsh verse can cover two Hafs
  /// verses, so several Hafs numbers can land on the same one.
  static int fromHafs(int hafsNumber, List<MushafVerse> surahVerses) =>
      _toEditionNumber(hafsNumber, surahVerses);

  static int _toEditionNumber(int hafsNumber, List<MushafVerse> surahVerses) {
    for (final verse in surahVerses) {
      if (verse.hafsNumbers.contains(hafsNumber)) {
        return verse.number;
      }
    }
    // Past the end of the mapping, clamp rather than run off: a Hafs 2:286
    // read against Warsh, which stops at 285, is the last verse of the surah
    // and not a verse that does not exist.
    if (surahVerses.isNotEmpty) {
      final last = surahVerses.last;
      if (last.hafsNumbers.isNotEmpty && hafsNumber > last.primaryHafsNumber) {
        return last.number;
      }
    }
    return hafsNumber;
  }
}
