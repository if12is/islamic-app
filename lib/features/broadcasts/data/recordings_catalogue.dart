import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/secure_http_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../quran/data/services/quran_local_service.dart';
import '../../quran/data/services/reciter_catalogue.dart';
import '../domain/recording.dart';

/// Rare recitations and the Taraweeh of the two Harams, curated.
///
/// Curated rather than searched. The Internet Archive holds tens of thousands
/// of items under «تراويح» and «تلاوات نادرة», and a search result is whatever
/// someone uploaded under that word — mislabelled files, a lecture filed as a
/// recitation, a video site's clickbait for a title. Every collection below
/// was opened, its files listed, and a file streamed from it before it was
/// written down; the list of files inside each one is then read live, so a
/// collection that grows does not need a release.
class RecordingsCatalogue {
  RecordingsCatalogue._();

  /// Answers 200 directly — no redirect for the guarded client to refuse.
  static const String metadataEndpoint = 'https://archive.org/metadata/';

  /// Answers 302 to a storage node over https, which the player follows.
  static const String downloadEndpoint = 'https://archive.org/download/';

  static const String _cachePrefix = 'recording_tracks_v1:';
  static const String _cachedAtPrefix = 'recording_tracks_at_v1:';

  /// An archive item almost never changes once it is complete.
  static const Duration refreshAfter = Duration(days: 30);

  /// The provider's own themed stations, shown with the recordings because
  /// they are the same thing live: «تلاوات خاشعة», «تراتيل قصيرة متميزة» and
  /// Muhammad Ayyub's distinguished reading. Addressed by the ids the
  /// broadcast catalogue gives them, so tapping one plays it as a station.
  static const List<String> liveRadioIds = [
    'radio:109',
    'radio:123',
    'radio:261',
  ];

  /// Oldest reciter first on the rare shelf, newest Ramadan first on the
  /// Taraweeh one — the order a reader browsing either would expect.
  static const List<RecordingCollection> collections = [
    // ---------------------------------------------------------------- rare
    RecordingCollection(
      id: 'archive:Mohammed_Refat_uP_bY_mUSLEm',
      titleAr: 'تلاوات خاشعة ونادرة',
      reciterAr: 'محمد رفعت',
      subtitleAr: 'قارئ الإذاعة المصرية الأول',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: 'Mohammed_Refat_uP_bY_mUSLEm',
      layout: TrackLayout.titled,
    ),
    RecordingCollection(
      id: 'archive:Tasjilat-Mojawada_Kharijia_Mustapha_Ismail_uP_bY_mUSLEm',
      titleAr: 'الحفلات المجودة والتسجيلات الخارجية',
      reciterAr: 'مصطفى إسماعيل',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: 'Tasjilat-Mojawada_Kharijia_Mustapha_Ismail_uP_bY_mUSLEm',
      layout: TrackLayout.titled,
    ),
    RecordingCollection(
      id: 'archive:20230814_20230814_1538',
      titleAr: 'تلاوات نادرة',
      reciterAr: 'محمد صديق المنشاوي',
      subtitleAr: 'من الخمسينيات والستينيات',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: '20230814_20230814_1538',
      layout: TrackLayout.surahTagged,
    ),
    RecordingCollection(
      id: 'mp3quran:112:10924',
      titleAr: 'المصحف المرتل — تسجيل عام ١٩٦٧م',
      reciterAr: 'محمد صديق المنشاوي',
      subtitleAr: '١٣٨٧هـ · ١٩٦٧م',
      category: RecordingCategory.rare,
      source: RecordingSource.mp3quran,
      identifier: 'mp3quran:112:10924',
      layout: TrackLayout.surah,
    ),
    RecordingCollection(
      id: 'archive:way2sona_20160404',
      titleAr: 'تلاوات نادرة من المساجد والمحافل',
      reciterAr: 'عبد الباسط عبد الصمد',
      subtitleAr: 'كل تسجيل بمكانه وسنته',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: 'way2sona_20160404',
      layout: TrackLayout.titled,
    ),
    RecordingCollection(
      id: 'archive:Islamic_Tape-623_uP_bY_mUSLEm',
      titleAr: 'المصحف المرتل من الإذاعة السعودية',
      reciterAr: 'عبد الباسط عبد الصمد',
      subtitleAr: 'تسجيلات نادرة',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: 'Islamic_Tape-623_uP_bY_mUSLEm',
      layout: TrackLayout.titled,
    ),

    // ------------------------------------------------------------ taraweeh
    RecordingCollection(
      id: 'archive:ramadan1445makkahtaraweeh',
      titleAr: 'تراويح المسجد الحرام',
      reciterAr: 'أئمة المسجد الحرام',
      subtitleAr: 'رمضان ١٤٤٥هـ · ٢٠٢٤م',
      noteAr: 'كل ليلة كاملة بتكبيراتها، ومعها دعاء ختم القرآن',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'ramadan1445makkahtaraweeh',
      layout: TrackLayout.night,
      exclude: ['notakbeer', 'withouttakbeer'],
    ),
    RecordingCollection(
      id: 'archive:ramadan1444makkahtaraweeh',
      titleAr: 'تراويح المسجد الحرام',
      reciterAr: 'أئمة المسجد الحرام',
      subtitleAr: 'رمضان ١٤٤٤هـ · ٢٠٢٣م',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'ramadan1444makkahtaraweeh',
      layout: TrackLayout.night,
      exclude: ['notakbeer', 'withouttakbeer'],
    ),
    RecordingCollection(
      id: 'archive:ramadan1444madeenahtaraweeh',
      titleAr: 'تراويح المسجد النبوي',
      reciterAr: 'أئمة المسجد النبوي',
      subtitleAr: 'رمضان ١٤٤٤هـ · ٢٠٢٣م',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'ramadan1444madeenahtaraweeh',
      layout: TrackLayout.night,
      exclude: ['notakbeer', 'withouttakbeer'],
    ),
    RecordingCollection(
      id: 'archive:MakkahTaraweeh1438',
      titleAr: 'تراويح المسجد الحرام',
      reciterAr: 'أئمة المسجد الحرام',
      subtitleAr: 'رمضان ١٤٣٨هـ · ٢٠١٧م',
      noteAr: 'المصحف كاملاً من صلاة التراويح، مرتّباً بالسور',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'MakkahTaraweeh1438',
      layout: TrackLayout.surah,
    ),
    RecordingCollection(
      id: 'archive:Makkah_Tarawih_1430',
      titleAr: 'تراويح المسجد الحرام',
      reciterAr: 'المعيقلي · الشريم · السديس · الجهني',
      subtitleAr: 'رمضان ١٤٣٠هـ · ٢٠٠٩م',
      noteAr: 'المصحف كاملاً من صلاة التراويح، مرتّباً بالسور',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'Makkah_Tarawih_1430',
      layout: TrackLayout.surah,
    ),
    RecordingCollection(
      id: 'archive:MakkahTaraweeh1429',
      titleAr: 'تراويح المسجد الحرام',
      reciterAr: 'أئمة المسجد الحرام',
      subtitleAr: 'رمضان ١٤٢٩هـ · ٢٠٠٨م',
      noteAr: 'المصحف كاملاً من صلاة التراويح، مرتّباً بالسور',
      category: RecordingCategory.taraweeh,
      source: RecordingSource.archive,
      identifier: 'MakkahTaraweeh1429',
      layout: TrackLayout.surah,
    ),
  ];

  static List<RecordingCollection> of(RecordingCategory category) => [
    for (final collection in collections)
      if (collection.category == category) collection,
  ];

  static RecordingCollection? byId(String id) {
    for (final collection in collections) {
      if (collection.id == id) {
        return collection;
      }
    }
    return null;
  }

  static final Map<String, List<RecordingTrack>> _memory = {};

  /// The files of [collection], from memory, the device, or the network.
  ///
  /// Returns empty only when there is nothing on the device and the host
  /// cannot be reached — the screen then says so rather than showing an
  /// empty list as though the collection were empty.
  static Future<List<RecordingTrack>> tracks(
    RecordingCollection collection, {
    bool refresh = false,
    Dio? client,
  }) async {
    final remembered = _memory[collection.id];
    if (remembered != null && !refresh) {
      return remembered;
    }

    if (collection.source == RecordingSource.mp3quran) {
      final built = await _mp3quranTracks(collection);
      if (built.isNotEmpty) {
        _memory[collection.id] = built;
      }
      return built;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs, collection.id);
    if (cached.isNotEmpty && !refresh && !_isStale(prefs, collection.id)) {
      return _memory[collection.id] = cached;
    }

    final fetched = await _fetchArchive(collection, client);
    if (fetched.isNotEmpty) {
      await _writeCache(prefs, collection.id, fetched);
      return _memory[collection.id] = fetched;
    }

    // Offline, or the host is down: a stale list still plays.
    if (cached.isNotEmpty) {
      return _memory[collection.id] = cached;
    }
    return const [];
  }

  static Future<List<RecordingTrack>> _mp3quranTracks(
    RecordingCollection collection,
  ) async {
    final voices = await ReciterCatalogue.load();
    final voice = ReciterCatalogue.byId(collection.identifier, voices);
    if (voice == null) {
      return const [];
    }
    final surahs = voice.surahs.toList()..sort();
    return [
      for (final surah in surahs)
        if (voice.urlFor(surah) case final url?)
          RecordingTrack(
            id: '${collection.id}/$surah',
            titleAr: 'سورة ${QuranLocalService.surahInfo(surah).nameAr}',
            url: url,
            order: surah,
          ),
    ];
  }

  static Future<List<RecordingTrack>> _fetchArchive(
    RecordingCollection collection,
    Dio? client,
  ) async {
    try {
      final dio = client ?? SecureHttpClient.create();
      final response = await dio.get<dynamic>(
        '$metadataEndpoint${collection.identifier}',
      );
      final body = response.data;
      return parseArchive(collection, body is String ? jsonDecode(body) : body);
    } catch (e) {
      AppLogger.warning('Could not list ${collection.identifier}: $e');
      return const [];
    }
  }

  // ------------------------------------------------------------- parsing

  /// Read an archive item's metadata into tracks. Pure, for tests.
  ///
  /// Only the uploader's own mp3 files are kept. The archive derives extra
  /// copies of most audio — a 64 kb/s mp3, an ogg, spectrogram images — and
  /// marks them `derivative`; listing those beside the originals would show
  /// every recitation two or three times.
  static List<RecordingTrack> parseArchive(
    RecordingCollection collection,
    Object? decoded,
  ) {
    if (decoded is! Map) {
      return const [];
    }
    final files = decoded['files'];
    if (files is! List) {
      return const [];
    }

    final kept = <_ArchiveFile>[];
    for (final raw in files) {
      if (raw is! Map) {
        continue;
      }
      final name = raw['name'];
      if (name is! String || !name.toLowerCase().endsWith('.mp3')) {
        continue;
      }
      if (raw['source'] != 'original') {
        continue;
      }
      final lower = name.toLowerCase();
      if (collection.exclude.any(lower.contains)) {
        continue;
      }
      final title = raw['title'];
      kept.add(
        _ArchiveFile(
          name: name,
          title: title is String ? title : '',
          duration: parseLength(raw['length']),
        ),
      );
    }

    final titled = _numberRepeats(switch (collection.layout) {
      TrackLayout.night => _nightTracks(kept),
      TrackLayout.surah => _surahTracks(kept),
      TrackLayout.titled => _titledTracks(kept),
      TrackLayout.surahTagged => _surahTaggedTracks(kept),
    });

    return [
      for (var index = 0; index < titled.length; index++)
        RecordingTrack(
          id: '${collection.id}/${titled[index].file.name}',
          titleAr: titled[index].title,
          subtitleAr: titled[index].subtitle,
          url: archiveUrl(collection.identifier, titled[index].file.name),
          duration: titled[index].file.duration,
          group: titled[index].group,
          order: index,
        ),
    ];
  }

  /// `https://archive.org/download/<item>/<file>`, every segment escaped.
  ///
  /// The file names hold Arabic, spaces, guillemets and the odd heart emoji;
  /// escaped as a whole the slash between folders would be escaped too.
  static String archiveUrl(String identifier, String fileName) {
    final path = fileName.split('/').map(Uri.encodeComponent).join('/');
    return '$downloadEndpoint${Uri.encodeComponent(identifier)}/$path';
  }

  /// The archive's `length`, which it writes two different ways.
  ///
  /// Measured on the items above: some give seconds as a decimal
  /// (`1485.19`), others a clock (`28:02`, `1:02:03`). A parser that expects
  /// one throws on the other — which is how the first probe of this list
  /// failed on three collections out of twelve.
  static Duration? parseLength(Object? value) {
    if (value is num) {
      return value > 0 ? Duration(milliseconds: (value * 1000).round()) : null;
    }
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    final text = value.trim();
    if (text.contains(':')) {
      var seconds = 0.0;
      for (final part in text.split(':')) {
        final parsed = double.tryParse(part);
        if (parsed == null) {
          return null;
        }
        seconds = seconds * 60 + parsed;
      }
      return seconds > 0
          ? Duration(milliseconds: (seconds * 1000).round())
          : null;
    }
    final seconds = double.tryParse(text);
    return seconds != null && seconds > 0
        ? Duration(milliseconds: (seconds * 1000).round())
        : null;
  }

  /// The number a file name starts with, for putting files in order.
  ///
  /// Natural order, not the string's: `1, 2, 10, 100` rather than
  /// `1, 10, 100, 2`, which is how one collection of 245 files would
  /// otherwise be listed.
  static int? leadingNumber(String name) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static int _byLeadingNumber(_ArchiveFile a, _ArchiveFile b) {
    final left = leadingNumber(a.name);
    final right = leadingNumber(b.name);
    if (left != null && right != null && left != right) {
      return left.compareTo(right);
    }
    if (left != null && right == null) {
      return -1;
    }
    if (left == null && right != null) {
      return 1;
    }
    return a.name.compareTo(b.name);
  }

  /// A title with the uploader's signature, running number and extension
  /// taken off.
  ///
  /// `002-آل عمران 33-51_uP_bY_mUSLEm` → `آل عمران 33-51`.
  static String cleanTitle(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'[_\s-]*up[_\s]*by[_\s]*[a-z0-9_]*$', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(RegExp(r'^\s*\d+\s*[-_.)]+\s*'), '');
    text = text.replaceAll('_', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(RegExp(r'^[-–·.\s]+|[-–·.\s]+$'), '');
    return text;
  }

  /// Tell apart files that would otherwise read the same.
  ///
  /// Al-Baqarah on the Saudi radio tapes is three files, each titled «البقرة»,
  /// and the Minshawi collection holds two recitations from an-Nahl. A list
  /// with the same line three times in a row gives a listener no way to know
  /// which one they stopped in. Each repeat is numbered beneath its title —
  /// «المقطع», not «الجزء», which in a Qur'an app means a juz'.
  static List<_Titled> _numberRepeats(List<_Titled> items) {
    String keyOf(_Titled item) => '${item.group}\u0000${item.title}';

    final counts = <String, int>{};
    for (final item in items) {
      counts[keyOf(item)] = (counts[keyOf(item)] ?? 0) + 1;
    }

    final seen = <String, int>{};
    return [
      for (final item in items)
        if ((counts[keyOf(item)] ?? 0) < 2)
          item
        else
          () {
            final n = seen[keyOf(item)] = (seen[keyOf(item)] ?? 0) + 1;
            final part = 'المقطع $n';
            return _Titled(
              item.file,
              item.title,
              subtitle:
                  item.subtitle.isEmpty ? part : '${item.subtitle} · $part',
              group: item.group,
            );
          }(),
    ];
  }

  // -------------------------------------------------------------- layouts

  static List<_Titled> _surahTracks(List<_ArchiveFile> files) {
    final sorted = [...files]..sort(_byLeadingNumber);
    return [
      for (final file in sorted)
        () {
          final number = leadingNumber(file.name);
          if (number != null && number >= 1 && number <= 114) {
            return _Titled(
              file,
              'سورة ${QuranLocalService.surahInfo(number).nameAr}',
            );
          }
          return _Titled(file, _fallbackTitle(file));
        }(),
    ];
  }

  static List<_Titled> _titledTracks(List<_ArchiveFile> files) {
    final sorted = [...files]..sort(_byLeadingNumber);
    return [for (final file in sorted) _Titled(file, _fallbackTitle(file))];
  }

  static String _fallbackTitle(_ArchiveFile file) {
    final fromTitle = cleanTitle(file.title);
    if (fromTitle.isNotEmpty) {
      return fromTitle;
    }
    final fromName = cleanTitle(file.name);
    if (fromName.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fromName)) {
      return fromName;
    }
    final number = leadingNumber(file.name);
    return number == null ? 'تلاوة' : 'تلاوة $number';
  }

  /// `021 s 50 55 اجمل تلاوة نادرة … عام 1966 م.mp3` → `من سورتي ق والرحمن`,
  /// with `1966م` beneath.
  ///
  /// The words after the numbers were written to be clicked on a video site —
  /// «هل هذا يعقل !», hearts, exclamation marks — and have no place over a
  /// recitation of the Qur'an. The surah numbers are what the file actually
  /// holds, so they are the title.
  static List<_Titled> _surahTaggedTracks(List<_ArchiveFile> files) {
    final sorted = [...files]..sort(_byLeadingNumber);
    return [
      for (final file in sorted)
        () {
          final surahs = surahsTagged(file.name);
          if (surahs.isEmpty) {
            final number = leadingNumber(file.name);
            return _Titled(file, number == null ? 'تلاوة' : 'تلاوة $number');
          }
          final year = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(file.name);
          return _Titled(
            file,
            surahPhrase(surahs),
            subtitle: year == null ? '' : '${year.group(1)}م',
          );
        }(),
    ];
  }

  /// The surah numbers after the `s` in a tagged file name, in order, once
  /// each, and only real ones.
  static List<int> surahsTagged(String name) {
    final match = RegExp(r'^\s*\d+\s+s\s+([\d\s]+)').firstMatch(name);
    if (match == null) {
      return const [];
    }
    final seen = <int>{};
    return [
      for (final token in match.group(1)!.trim().split(RegExp(r'\s+')))
        if (int.tryParse(token) case final number?)
          if (number >= 1 && number <= 114 && seen.add(number)) number,
    ];
  }

  /// `من سورة ق`, `من سورتي الحجرات وق`, `من سور الصف والجمعة والمنافقون`.
  static String surahPhrase(List<int> surahs) {
    final names = [
      for (final number in surahs) QuranLocalService.surahInfo(number).nameAr,
    ];
    final joined = names.join(' و');
    return switch (names.length) {
      1 => 'من سورة $joined',
      2 => 'من سورتي $joined',
      _ => 'من سور $joined',
    };
  }

  /// One night of Taraweeh, cut into its sets of rak`ahs.
  ///
  /// The names are regular enough to read, but not uniform: within one
  /// Ramadan some nights are cut 4-4-2 and others 6-4, the second set of one
  /// night is `next4` where the rest say `second4`, and the twenty-ninth
  /// night carries the du`a of completing the Qur'an as a file of its own.
  /// So the rak`ah numbers are counted from the parts rather than assumed,
  /// and a file that fits no pattern is kept under a cleaned name instead of
  /// being dropped.
  static List<_Titled> _nightTracks(List<_ArchiveFile> files) {
    final parsed = [for (final file in files) _NightPart.parse(file)];

    final byNight = <int, List<_NightPart>>{};
    final loose = <_ArchiveFile>[];
    for (final part in parsed) {
      if (part.night == null) {
        loose.add(part.file);
      } else {
        byNight.putIfAbsent(part.night!, () => []).add(part);
      }
    }

    final result = <_Titled>[];
    for (final night in byNight.keys.toList()..sort()) {
      final parts =
          byNight[night]!..sort((a, b) {
            final byRank = a.rank.compareTo(b.rank);
            return byRank != 0 ? byRank : a.file.name.compareTo(b.file.name);
          });
      final group = 'الليلة $night';
      var nextRakah = 1;
      for (final part in parts) {
        final count = part.rakahs;
        if (part.isKhatm) {
          result.add(_Titled(part.file, 'دعاء ختم القرآن', group: group));
        } else if (count != null) {
          final last = nextRakah + count - 1;
          result.add(
            _Titled(part.file, 'الركعات $nextRakah–$last', group: group),
          );
          nextRakah = last + 1;
        } else {
          result.add(
            _Titled(part.file, _fallbackTitle(part.file), group: group),
          );
        }
      }
    }

    loose.sort(_byLeadingNumber);
    for (final file in loose) {
      result.add(_Titled(file, _fallbackTitle(file)));
    }
    return result;
  }

  // ----------------------------------------------------------------- cache

  static bool _isStale(SharedPreferences prefs, String id) {
    final at = prefs.getInt('$_cachedAtPrefix$id');
    if (at == null) {
      return true;
    }
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) >=
        refreshAfter;
  }

  static List<RecordingTrack> _readCache(SharedPreferences prefs, String id) {
    final raw = prefs.getString('$_cachePrefix$id');
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw);
      if (list is! List) {
        return const [];
      }
      final tracks = [
        for (final entry in list)
          if (entry is Map)
            if (RecordingTrack.fromJson(Map<String, dynamic>.from(entry))
                case final track?)
              track,
      ]..sort((a, b) => a.order.compareTo(b.order));
      return tracks;
    } catch (e) {
      AppLogger.warning('Recording cache unreadable for $id: $e');
      return const [];
    }
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    String id,
    List<RecordingTrack> tracks,
  ) async {
    try {
      await prefs.setString(
        '$_cachePrefix$id',
        jsonEncode([for (final track in tracks) track.toJson()]),
      );
      await prefs.setInt(
        '$_cachedAtPrefix$id',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning('Could not cache recordings for $id: $e');
    }
  }

  /// Forget what is in memory, for a test.
  static void resetForTest() => _memory.clear();
}

class _ArchiveFile {
  const _ArchiveFile({
    required this.name,
    required this.title,
    required this.duration,
  });

  final String name;
  final String title;
  final Duration? duration;
}

class _Titled {
  const _Titled(this.file, this.title, {this.subtitle = '', this.group});

  final _ArchiveFile file;
  final String title;
  final String subtitle;
  final String? group;
}

/// What a Taraweeh file name says about itself.
class _NightPart {
  const _NightPart({
    required this.file,
    required this.night,
    required this.rank,
    required this.rakahs,
    required this.isKhatm,
  });

  final _ArchiveFile file;
  final int? night;

  /// Where the part falls in the night: first, second, third, fourth, last.
  final int rank;

  /// How many rak`ahs the part holds, when the name says.
  final int? rakahs;

  final bool isKhatm;

  static const Map<String, int> _ranks = {
    'first': 0,
    'second': 1,
    'next': 1,
    'third': 2,
    'fourth': 3,
    'last': 8,
  };

  static _NightPart parse(_ArchiveFile file) {
    final lower = file.name.toLowerCase();
    final night = RegExp(r'^(\d+)ramadan').firstMatch(lower);
    if (night == null) {
      return _NightPart(
        file: file,
        night: null,
        rank: 5,
        rakahs: null,
        isKhatm: false,
      );
    }

    if (lower.contains('khatam') || lower.contains('khatm')) {
      return _NightPart(
        file: file,
        night: int.parse(night.group(1)!),
        rank: 9,
        rakahs: null,
        isKhatm: true,
      );
    }

    final part = RegExp(
      r'(first|second|next|third|fourth|last)(\d+)rakah',
    ).firstMatch(lower);
    return _NightPart(
      file: file,
      night: int.parse(night.group(1)!),
      rank: part == null ? 5 : _ranks[part.group(1)]!,
      rakahs: part == null ? null : int.tryParse(part.group(2)!),
      isKhatm: false,
    );
  }
}
