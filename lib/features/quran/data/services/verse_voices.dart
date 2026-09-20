import '../../../../core/services/data_saver.dart';
import '../../domain/entities/riwaya.dart';
import 'ayah_timing_service.dart';
import 'reciter_catalogue.dart';
import 'verse_reciters.dart';

/// A voice that can play a single ayah, whichever way it manages it.
///
/// There are two ways, and the reader should never have to know which. One is
/// a corpus of per-ayah files; the other is a whole-surah recording plus the
/// provider's marks for where each verse falls. Before this, only the first
/// existed, which is why a reader of Qalun had no ayah playback at all: the
/// per-ayah host carries Hafs and three Warsh folders and nothing else.
class PlayableVerseVoice {
  const PlayableVerseVoice({
    required this.id,
    required this.nameAr,
    required this.styleAr,
    required this.riwayaId,
    required this.counting,
    this.file,
    this.clip,
  });

  factory PlayableVerseVoice.fromFile(VerseReciter reciter) =>
      PlayableVerseVoice(
        id: reciter.id,
        nameAr: reciter.nameAr,
        styleAr: reciter.styleAr,
        riwayaId: reciter.riwayaId,
        counting: reciter.counting,
        file: reciter,
      );

  /// A whole-surah recording that has verse marks.
  ///
  /// [counting] is **measured**, not taken from the reading. Most Warsh and
  /// Qalun recordings are marked the way their mushaf is printed — 285 marks
  /// for al-Baqarah, 130 for al-Tawbah — but not all of them: Muhammad Sayed's
  /// Warsh recording is marked in Hafs numbers. A reading and the numbering of
  /// a recording of it are two different facts, and the second is knowable
  /// only by asking.
  factory PlayableVerseVoice.fromClip(
    ReciterVoice voice,
    VerseCounting counting,
  ) => PlayableVerseVoice(
    id: voice.id,
    nameAr: voice.nameAr,
    styleAr: voice.styleAr,
    riwayaId: voice.riwayaId,
    counting: counting,
    clip: voice,
  );

  final String id;
  final String nameAr;
  final String styleAr;
  final int riwayaId;

  /// Which numbering to address this voice by.
  final VerseCounting counting;

  /// Set when the voice has per-ayah files.
  final VerseReciter? file;

  /// Set when the voice is a whole-surah recording cut at the marks.
  final ReciterVoice? clip;

  bool get isClipped => clip != null;

  String get label => styleAr.isEmpty ? nameAr : '$nameAr — $styleAr';
}

/// Which voices may be offered for playing one ayah at a time.
///
/// The rule the whole feature turns on: a row that cannot play does not
/// appear. A recording in the wrong reading is hidden, a recording missing
/// this surah is hidden, and a whole-surah recording with no verse marks is
/// hidden — rather than listed and quietly answered by a different sheikh.
class VerseVoices {
  VerseVoices._();

  /// The largest list of recordings worth asking about all at once.
  ///
  /// The question "can this be cut at the ayah" is one small request per
  /// recording, and it is remembered on the device afterwards. Warsh has
  /// sixteen recordings and Qalun twelve, so each reading is settled in one
  /// short pass. Hafs has two hundred and nineteen, and it needs none: the
  /// per-ayah host already carries forty-odd Hafs voices, the longest list in
  /// the app.
  ///
  /// A whole small list is asked about, never an arbitrary prefix of a large
  /// one — a list that is half-probed shows a different set of rows depending
  /// on how far the probing got, which is not a list anyone can trust.
  static const int probeLimit = 32;

  /// Per-ayah files for [edition] — the fast, always-available half.
  static List<PlayableVerseVoice> files(MushafEdition edition) => [
    for (final reciter in VerseReciters.forEdition(edition))
      PlayableVerseVoice.fromFile(reciter),
  ];

  /// Whole-surah recordings of [edition]'s reading that carry this surah.
  ///
  /// Candidates only — [clips] is what is safe to show.
  static List<ReciterVoice> clipCandidates({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
  }) {
    final matching = [
      for (final voice in voices)
        if (edition.accepts(voice.riwayaId))
          if (voice.moshafId != null)
            // Whether it can be cut at all is settled by at-Tawbah, so a
            // recording that does not contain at-Tawbah cannot be measured
            // and must not be offered: its numbering would be a guess.
            if (voice.has(AyahTimingService.probeSurah))
              if (surahNumber == null || voice.has(surahNumber)) voice,
    ];
    // Complete recordings first: a reader asking for one ayah today will ask
    // for another tomorrow, and a partial recording is a row that works until
    // it does not.
    matching.sort((a, b) => b.surahs.length.compareTo(a.surahs.length));
    return matching;
  }

  /// Ask the provider which of [voices] have verse marks.
  ///
  /// Runs for any reading whose list is short enough to settle in full, which
  /// is every reading but Hafs. It is not only for readings with no per-ayah
  /// corpus: Warsh has three per-ayah folders and sixteen whole-surah
  /// recordings, five of which carry marks — Muhammad Sayed and al-Husary
  /// among them — and leaving those out would keep a reader of Warsh on three
  /// voices while the provider offers eight.
  static Future<void> warmClips({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
  }) async {
    final candidates = clipCandidates(
      voices: voices,
      edition: edition,
      surahNumber: surahNumber,
    );
    if (candidates.length > probeLimit) {
      return;
    }
    // Each answer costs about thirty kilobytes and is kept for good, but a
    // dozen of them at once is not something to spend on someone's allowance
    // without asking. With the data saver on, the list is whatever has been
    // learnt already, and playing a voice still measures that one.
    if (!DataSaver.allowsBackgroundRefresh &&
        candidates.any(
          (voice) => !AyahTimingService.isKnown(voice.moshafId!),
        )) {
      return;
    }
    await AyahTimingService.warmSupport([
      for (final voice in candidates)
        if (voice.moshafId case final id?) id,
    ]);
  }

  /// Whole-surah recordings already known to carry verse marks.
  static List<PlayableVerseVoice> clips({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
  }) => [
    for (final voice in clipCandidates(
      voices: voices,
      edition: edition,
      surahNumber: surahNumber,
    ))
      if (AyahTimingService.knownCounting(voice.moshafId!) case final counting?)
        PlayableVerseVoice.fromClip(voice, counting),
  ];

  /// Everything that can play one ayah in [edition], files first.
  static List<PlayableVerseVoice> all({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
  }) => [
    ...files(edition),
    ...clips(voices: voices, edition: edition, surahNumber: surahNumber),
  ];

  /// The voice to actually play, for a saved choice that may not fit.
  ///
  /// Order matters. A saved per-ayah voice in the right reading wins; then the
  /// same id as a whole-surah recording with marks; then the reading's own
  /// default. It returns null rather than reaching for a Hafs voice, because
  /// the one outcome this feature exists to prevent is a Warsh page reciting
  /// Hafs with nothing on screen admitting it.
  static Future<PlayableVerseVoice?> resolve({
    required String savedId,
    required MushafEdition edition,
    required List<ReciterVoice> voices,
    int? surahNumber,
  }) async {
    final saved = VerseReciters.find(savedId);
    if (saved != null && edition.accepts(saved.riwayaId)) {
      return PlayableVerseVoice.fromFile(saved);
    }

    final catalogued = ReciterCatalogue.byId(savedId, voices);
    if (catalogued != null &&
        edition.accepts(catalogued.riwayaId) &&
        catalogued.moshafId != null &&
        (surahNumber == null || catalogued.has(surahNumber))) {
      final counting = await AyahTimingService.countingOf(catalogued.moshafId!);
      if (counting != null) {
        return PlayableVerseVoice.fromClip(catalogued, counting);
      }
    }

    final fallbackFiles = files(edition);
    if (fallbackFiles.isNotEmpty) {
      return fallbackFiles.first;
    }

    final candidates = clipCandidates(
      voices: voices,
      edition: edition,
      surahNumber: surahNumber,
    );
    if (candidates.length <= probeLimit) {
      for (final voice in candidates) {
        final counting = await AyahTimingService.countingOf(voice.moshafId!);
        if (counting != null) {
          return PlayableVerseVoice.fromClip(voice, counting);
        }
      }
    }
    return null;
  }
}
