import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/data_saver.dart';
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

  /// The item's own file list is what is kept, not the tracks made from it:
  /// a third of the size, and a parser fixed in a later release reads the
  /// list already on the device instead of waiting a month to refetch it.
  static const String _cachePrefix = 'recording_files_v2:';
  static const String _cachedAtPrefix = 'recording_files_at_v2:';

  /// What the first release kept — every finished track, address and all.
  static const List<String> _retiredPrefixes = [
    'recording_tracks_v1:',
    'recording_tracks_at_v1:',
  ];

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
      // One file is the uploader reading his own credit, 21 seconds long.
      minLength: Duration(minutes: 1),
    ),
    RecordingCollection(
      id: 'archive:Tasjilat-Mojawada_Kharijia_Mustapha_Ismail_uP_bY_mUSLEm',
      titleAr: 'الحفلات المجودة والتسجيلات الخارجية',
      reciterAr: 'مصطفى إسماعيل',
      category: RecordingCategory.rare,
      source: RecordingSource.archive,
      identifier: 'Tasjilat-Mojawada_Kharijia_Mustapha_Ismail_uP_bY_mUSLEm',
      layout: TrackLayout.titled,
      minLength: Duration(minutes: 1),
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
      // Forty-five of its files are clips under a minute cut for a video
      // site's shorts, each a verse or two under a clickbait caption. The
      // recitations are the long files.
      minLength: Duration(minutes: 1),
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
    await _retire(prefs, collection.id);
    final cached = parseArchive(
      collection,
      expandFiles(prefs.getString('$_cachePrefix${collection.id}')),
    );
    // Data saver keeps a list already on the device however old it is: an
    // archive item whose files were written once does not need re-reading
    // on someone's allowance. Pulling the list down still refreshes it.
    if (cached.isNotEmpty &&
        !refresh &&
        (!_isStale(prefs, collection.id) ||
            !DataSaver.allowsBackgroundRefresh)) {
      return _memory[collection.id] = cached;
    }

    final files = await _fetchFiles(collection, client);
    final fetched =
        files == null
            ? const <RecordingTrack>[]
            : parseArchive(collection, expandFiles(files));
    if (fetched.isNotEmpty) {
      await _writeCache(prefs, collection.id, files!);
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

  /// The item's file list as [compactFiles] writes it, or null when the
  /// host cannot be reached.
  static Future<String?> _fetchFiles(
    RecordingCollection collection,
    Dio? client,
  ) async {
    try {
      final dio = client ?? SecureHttpClient.create();
      final response = await dio.get<dynamic>(
        '$metadataEndpoint${collection.identifier}',
      );
      final body = response.data;
      return compactFiles(body is String ? jsonDecode(body) : body);
    } catch (e) {
      AppLogger.warning('Could not list ${collection.identifier}: $e');
      return null;
    }
  }

  /// The part of an item's metadata the parser reads, and only that: the
  /// original mp3 files, each as `[name, title, length]`. Pure, for tests.
  ///
  /// The full metadata of one item runs to half a megabyte of checksums,
  /// derivative formats and spectrogram images.
  static String compactFiles(Object? decoded) {
    final files = decoded is Map ? decoded['files'] : null;
    return jsonEncode([
      if (files is List)
        for (final raw in files)
          if (raw is Map &&
              raw['source'] == 'original' &&
              raw['name'] is String &&
              (raw['name'] as String).toLowerCase().endsWith('.mp3'))
            [
              raw['name'],
              raw['title'] is String ? raw['title'] : '',
              raw['length'],
            ],
    ]);
  }

  /// [compactFiles] read back into the shape [parseArchive] takes. Anything
  /// unreadable reads as no files. Pure, for tests.
  static Map<String, Object?> expandFiles(String? compact) {
    if (compact == null || compact.isEmpty) {
      return const {'files': []};
    }
    try {
      final list = jsonDecode(compact);
      return {
        'files': [
          if (list is List)
            for (final entry in list)
              if (entry is List && entry.isNotEmpty && entry.first is String)
                {
                  'name': entry.first,
                  'title': entry.length > 1 ? entry[1] : null,
                  'length': entry.length > 2 ? entry[2] : null,
                  'source': 'original',
                },
        ],
      };
    } catch (e) {
      AppLogger.warning('Recording file list unreadable: $e');
      return const {'files': []};
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
      final duration = parseLength(raw['length']);
      final shortest = collection.minLength;
      if (shortest != null && duration != null && duration < shortest) {
        continue;
      }
      final title = raw['title'];
      kept.add(
        _ArchiveFile(
          name: name,
          title: title is String ? repairArabic(title) : '',
          duration: duration,
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

  /// Arabic that was saved as Windows-1256 and read back as Latin-1, put
  /// right: `ÌäæÈ ÇÝÑíÞíÇ - 1966` → `جنوب افريقيا - 1966`.
  ///
  /// Old Arabic MP3 tags were written in the Windows code page, and the
  /// archive read 38 of the Abdul Basit titles as Latin-1 — each byte one
  /// accented letter. Every byte survives that, so mapping each back through
  /// the code page recovers the title exactly. Only a title with no Arabic
  /// in it and a run of those letters is touched; one that is already right
  /// comes back as it was.
  static String repairArabic(String text) {
    if (RegExp(r'[؀-ۿ]').hasMatch(text) ||
        !RegExp(r'[À-ÿ]{2,}').hasMatch(text)) {
      return text;
    }
    return String.fromCharCodes([
      for (final unit in text.codeUnits)
        unit >= 0x80 && unit <= 0xFF ? _windows1256[unit - 0x80] : unit,
    ]);
  }

  /// Windows-1256 from 0x80 to 0xFF, as Unicode.
  static const List<int> _windows1256 = [
    // 0x80
    0x20AC, 0x067E, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688,
    // 0x90
    0x06AF, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x06A9, 0x2122, 0x0691, 0x203A, 0x0153, 0x200C, 0x200D, 0x06BA,
    // 0xA0
    0x00A0, 0x060C, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7,
    0x00A8, 0x00A9, 0x06BE, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
    // 0xB0
    0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7,
    0x00B8, 0x00B9, 0x061B, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x061F,
    // 0xC0
    0x06C1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627,
    0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F,
    // 0xD0
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00D7,
    0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643,
    // 0xE0
    0x00E0, 0x0644, 0x00E2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00E7,
    0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0649, 0x064A, 0x00EE, 0x00EF,
    // 0xF0
    0x064B, 0x064C, 0x064D, 0x064E, 0x00F4, 0x064F, 0x0650, 0x00F7,
    0x0651, 0x00F9, 0x0652, 0x00FB, 0x00FC, 0x200E, 0x200F, 0x06D2,
  ];

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
  /// holds, so they are the title. A file without them keeps its words, with
  /// the decoration taken off by [untaggedTitle].
  static List<_Titled> _surahTaggedTracks(List<_ArchiveFile> files) {
    final sorted = [...files]..sort(_byLeadingNumber);
    return [
      for (final file in sorted)
        () {
          final surahs = surahsTagged(file.name);
          if (surahs.isEmpty) {
            return _Titled(file, untaggedTitle(file.name));
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

  /// The Arabic words of a file name written for a video site, and nothing
  /// else: `101 s ابتهال نادر للشيخ محمد صديق المنشاوي.mp3` → `ابتهال نادر
  /// للشيخ محمد صديق المنشاوي`.
  ///
  /// Off come the running number and its `s`, hashtags, «shorts», the
  /// `(128 kbps)` a converter appended, emoji, hearts and runs of
  /// exclamation marks. The Persian `چ` a caption uses to look different is
  /// read as the `ج` it stands for. A name with no Arabic left is only its
  /// number.
  static String untaggedTitle(String name) {
    var text = name.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^[\d\s]+(?:s(?=[\s\-_]|$))?'), '');
    text = text.replaceAll(RegExp(r'\(\s*\d*\s*kbps\s*\)|\(\d+\)'), ' ');
    text = text.replaceAll(RegExp('shorts', caseSensitive: false), ' ');
    text = text.replaceAll('چ', 'ج');
    // Arabic letters with their marks, digits and spaces are all that stay.
    text = text.replaceAll(RegExp(r'[^ء-ْٰ-ۓ٠-٩0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(r'[ء-ي]').hasMatch(text)) {
      return text;
    }
    final number = leadingNumber(name);
    return number == null ? 'تلاوة' : 'تلاوة $number';
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

  static Future<void> _writeCache(
    SharedPreferences prefs,
    String id,
    String files,
  ) async {
    try {
      await prefs.setString('$_cachePrefix$id', files);
      await prefs.setInt(
        '$_cachedAtPrefix$id',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning('Could not cache recordings for $id: $e');
    }
  }

  /// Drop what the first release kept for [id], once, as it is next opened.
  static Future<void> _retire(SharedPreferences prefs, String id) async {
    for (final prefix in _retiredPrefixes) {
      if (prefs.containsKey('$prefix$id')) {
        await prefs.remove('$prefix$id');
      }
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
