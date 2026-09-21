/// Recorded recitations: rare historical ones, and the Taraweeh of the two
/// Harams.
///
/// Broadcasts are live and have no length; these are the opposite — a night
/// of Taraweeh runs an hour and a half, and a listener will stop half way and
/// come back. So they are modelled apart from [Broadcast] rather than bent to
/// fit it.
library;

/// Which shelf a collection sits on.
enum RecordingCategory {
  /// Old recordings of the great reciters: concerts, radio archives, tapes.
  rare,

  /// Whole Ramadans of Taraweeh from al-Masjid al-Haram and al-Masjid
  /// an-Nabawi.
  taraweeh,
}

/// Where a collection's files come from.
enum RecordingSource {
  /// The Internet Archive. The list of files is read from its metadata API
  /// and each file streams from its download path.
  archive,

  /// A recording already in the mp3quran catalogue the app uses for its
  /// reciters, addressed by that catalogue's own id.
  mp3quran,
}

/// How to turn a collection's file names into titles someone can read.
///
/// Uploaders name files however they like, and the names are the only
/// description most files have. Each collection says which of these its files
/// follow; nothing is guessed per file.
enum TrackLayout {
  /// `01ramadan1445first4rakah…mp3` — a night of Taraweeh cut into its
  /// sets of rak`ahs. Titled by night and by which rak`ahs each part holds.
  night,

  /// `002.mp3`, `002-Surah-Al-Baqarah.mp3` — one file per surah, named by its
  /// number. Titled with the surah's Arabic name.
  surah,

  /// The file carries a readable Arabic `title` of its own, under the
  /// uploader's tag. Used as given, with the tag and the running number
  /// taken off.
  titled,

  /// `021 s 50 55 اجمل تلاوة نادرة…mp3` — the surah numbers follow an `s`,
  /// and the rest of the name is written for a video site. Titled from the
  /// surah numbers alone, with the year if the name has one; a name with no
  /// numbers keeps its Arabic words, stripped of the site's decoration.
  surahTagged,
}

/// A curated set of recordings, shown as one card.
class RecordingCollection {
  const RecordingCollection({
    required this.id,
    required this.titleAr,
    required this.reciterAr,
    required this.category,
    required this.source,
    required this.identifier,
    required this.layout,
    this.subtitleAr = '',
    this.noteAr = '',
    this.exclude = const [],
    this.minLength,
  });

  /// Stable across releases: kept in preferences as the key for remembered
  /// positions and cached track lists.
  final String id;

  final String titleAr;

  /// Who recites. For Taraweeh, the imams of that Ramadan.
  final String reciterAr;

  /// A year, a place, a count — the one line under the title.
  final String subtitleAr;

  /// Why it is here, when that is worth a sentence.
  final String noteAr;

  final RecordingCategory category;
  final RecordingSource source;

  /// The archive item's identifier, or the mp3quran voice id.
  final String identifier;

  final TrackLayout layout;

  /// Lower-case fragments of file names to leave out.
  ///
  /// The Haramain uploads carry every part twice — with the takbirat of the
  /// prayer and without — and listing both doubles every night with a
  /// near-identical copy. The prayer as it was prayed is kept.
  final List<String> exclude;

  /// Files shorter than this are left out, where a collection mixes its
  /// recitations with the uploader's spoken signature or with clips cut for
  /// a video site. Not set on the surah-by-surah Taraweeh, where al-`Asr is
  /// thirteen seconds long and belongs there.
  final Duration? minLength;
}

/// One file of a collection.
class RecordingTrack {
  const RecordingTrack({
    required this.id,
    required this.titleAr,
    required this.url,
    this.subtitleAr = '',
    this.duration,
    this.group,
    this.order = 0,
  });

  /// Unique within the whole app, so a remembered position cannot land on a
  /// different collection's file of the same name.
  final String id;

  final String titleAr;
  final String subtitleAr;
  final String url;

  /// From the host's metadata, when it gives one.
  final Duration? duration;

  /// The heading this track sits under, such as a night of Ramadan. Null
  /// where a collection has no grouping.
  final String? group;

  /// Position within the collection.
  final int order;
}
