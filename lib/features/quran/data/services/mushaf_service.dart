import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/riwaya.dart';

/// One verse of a mushaf that is not Hafs.
class MushafVerse {
  const MushafVerse({
    required this.number,
    required this.page,
    required this.text,
    required this.marker,
    required this.hafsNumbers,
  });

  /// The verse number **in this mushaf's own counting**.
  final int number;

  /// The page it falls on in this mushaf's printing, which is not the Hafs
  /// page: the Warsh mushaf has its own pagination and al-Baqarah ends on a
  /// different leaf.
  final int page;

  /// The rasm, as this reading writes it.
  final String text;

  /// The verse-end glyph the mushaf prints.
  final String marker;

  /// Which Hafs verse or verses this one corresponds to.
  ///
  /// The provider gives this, and it is the hinge the whole feature turns on.
  /// Warsh's opening verse of al-Fatiha is Hafs 1 and 2 together; al-Tawbah
  /// gains a verse and al-Baqarah loses one. Without the mapping there is no
  /// way to line up a bookmark, a last-read position, a page of the Hafs
  /// index, or a recording numbered the other way.
  final List<int> hafsNumbers;

  /// The single Hafs verse to treat this one as, when only one will do.
  int get primaryHafsNumber => hafsNumbers.isEmpty ? number : hafsNumbers.first;

  /// Whether this verse carries any part of Hafs verse [hafsNumber].
  bool coversHafs(int hafsNumber) =>
      hafsNumbers.isEmpty
          ? number == hafsNumber
          : hafsNumbers.contains(hafsNumber);

  Map<String, dynamic> toJson() => {
    'n': number,
    'p': page,
    't': text,
    'm': marker,
    'h': hafsNumbers,
  };

  static MushafVerse? fromJson(Map<String, dynamic> json) {
    final number = json['n'];
    final text = json['t'];
    if (number is! num || text is! String || text.isEmpty) {
      return null;
    }
    final page = json['p'];
    return MushafVerse(
      number: number.toInt(),
      page: page is num ? page.toInt() : 1,
      text: text,
      marker: json['m'] as String? ?? '',
      hafsNumbers: [
        for (final value in (json['h'] as List? ?? const []))
          if (value is num) value.toInt(),
      ],
    );
  }
}

/// The text of a mushaf the `quran` package does not carry.
///
/// That package bundles Hafs and only Hafs, which is the right default and the
/// wrong ceiling: a reader of Warsh or Qalun opening this app has been reading
/// someone else's text. Quranpedia publishes both mushafs — rasm, pagination,
/// verse markers — together with the one field that makes them usable next to
/// everything already built on Hafs: which Hafs verse each verse is.
///
/// Fetched a surah at a time and kept on disk, the way the reciter catalogue
/// is. A surah read once is readable offline afterwards; the alternative,
/// bundling the mushafs, would add to a package the reader has already
/// complained is slow to download.
class MushafService {
  MushafService._();

  static const String _host = 'https://api.quranpedia.net';

  /// Quranpedia's mushaf ids. Hafs is 1 and is never fetched — the app has it.
  ///
  /// Read from `/v1/mushafs`, where each entry names its rawi and its verse
  /// count tradition. Both of these say `المدني الأخير`, which is why one
  /// [VerseCounting] covers the pair.
  static const Map<MushafEdition, int> _mushafIds = {
    MushafEdition.warsh: 4,
    MushafEdition.qaloon: 7,
  };

  static const String _folder = 'mushaf';

  /// Surahs already read this session, so paging back and forth costs nothing.
  static final Map<String, List<MushafVerse>> _memory = {};

  static bool supports(MushafEdition edition) =>
      _mushafIds.containsKey(edition);

  /// Editions with a text of their own, for a settings list.
  static List<MushafEdition> get fetchable => _mushafIds.keys.toList();

  static String _keyFor(MushafEdition edition, int surahNumber) =>
      '${edition.id}:$surahNumber';

  /// The surah if it is already in memory, without waiting.
  ///
  /// For the places that draw a single ayah inside a build — a share card, a
  /// note, the ayah of the day — where an await is not available and showing
  /// Hafs for one frame is better than showing nothing.
  static List<MushafVerse>? inMemory(MushafEdition edition, int surahNumber) =>
      _memory[_keyFor(edition, surahNumber)];

  /// The surah's verses in [edition]'s own text and counting.
  ///
  /// Returns empty when the text is not on the device and cannot be reached,
  /// so the reader can say so rather than quietly showing Hafs under a Warsh
  /// heading — which would be the same lie this change exists to end.
  static Future<List<MushafVerse>> surah(
    MushafEdition edition,
    int surahNumber, {
    Dio? client,
  }) async {
    final mushafId = _mushafIds[edition];
    if (mushafId == null) {
      return const [];
    }

    final key = _keyFor(edition, surahNumber);
    final remembered = _memory[key];
    if (remembered != null) {
      return remembered;
    }

    // One flight per surah. The reader, the audio queue and a warm-up can all
    // ask for the same surah in the same frame; without this they each open a
    // request and the provider's 120-per-minute budget goes on duplicates.
    final running = _inFlight[key];
    if (running != null) {
      return running;
    }

    final future = _resolve(edition, surahNumber, mushafId, client);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static final Map<String, Future<List<MushafVerse>>> _inFlight = {};

  static Future<List<MushafVerse>> _resolve(
    MushafEdition edition,
    int surahNumber,
    int mushafId,
    Dio? client,
  ) async {
    final key = _keyFor(edition, surahNumber);

    final cached = await _readCache(edition, surahNumber);
    if (cached.isNotEmpty) {
      return _memory[key] = cached;
    }

    final fetched = await _fetch(mushafId, surahNumber, client);
    if (fetched.isEmpty) {
      return const [];
    }

    await _writeCache(edition, surahNumber, fetched);
    return _memory[key] = fetched;
  }

  /// Whether this surah is already on the device.
  static Future<bool> isCached(MushafEdition edition, int surahNumber) async {
    if (_memory.containsKey(_keyFor(edition, surahNumber))) {
      return true;
    }
    final file = await _fileFor(edition, surahNumber);
    return file.exists();
  }

  /// How many of the 114 are on the device, for a progress line.
  static Future<int> cachedCount(MushafEdition edition) async {
    var total = 0;
    for (var surah = 1; surah <= 114; surah++) {
      if (await isCached(edition, surah)) {
        total++;
      }
    }
    return total;
  }

  static Future<void> clear(MushafEdition edition) async {
    _memory.removeWhere((key, _) => key.startsWith('${edition.id}:'));
    final directory = await _directoryFor(edition);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Put a surah in memory without a network or a disk.
  ///
  /// The sync readers — the page-turning view, the ayah of the day, a share
  /// card — only answer once a surah is in memory, so a test that cannot get
  /// one there can only ever exercise the Hafs fallback, which is the half
  /// that was already working.
  @visibleForTesting
  static void seedForTest(
    MushafEdition edition,
    int surahNumber,
    List<MushafVerse> verses,
  ) {
    _memory[_keyFor(edition, surahNumber)] = verses;
  }

  @visibleForTesting
  static void resetForTest() {
    _memory.clear();
    _inFlight.clear();
  }

  static Future<Directory> _directoryFor(MushafEdition edition) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/$_folder/${edition.id}');
  }

  static Future<File> _fileFor(MushafEdition edition, int surahNumber) async {
    final directory = await _directoryFor(edition);
    return File('${directory.path}/$surahNumber.json');
  }

  static Future<List<MushafVerse>> _readCache(
    MushafEdition edition,
    int surahNumber,
  ) async {
    try {
      final file = await _fileFor(edition, surahNumber);
      if (!await file.exists()) {
        return const [];
      }
      return parseCache(await file.readAsString());
    } catch (e) {
      AppLogger.warning('Mushaf cache unreadable for $surahNumber: $e');
      return const [];
    }
  }

  static Future<void> _writeCache(
    MushafEdition edition,
    int surahNumber,
    List<MushafVerse> verses,
  ) async {
    try {
      final file = await _fileFor(edition, surahNumber);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final verse in verses) verse.toJson()]),
      );
    } catch (e) {
      AppLogger.warning('Could not cache surah $surahNumber: $e');
    }
  }

  /// Read a cached payload. Separate so it can be tested without a disk.
  static List<MushafVerse> parseCache(String raw) {
    if (raw.isEmpty) {
      return const [];
    }
    final list = jsonDecode(raw);
    if (list is! List) {
      return const [];
    }
    return [
      for (final entry in list)
        if (entry is Map)
          if (MushafVerse.fromJson(Map<String, dynamic>.from(entry))
              case final verse?)
            verse,
    ];
  }

  static Future<List<MushafVerse>> _fetch(
    int mushafId,
    int surahNumber,
    Dio? client,
  ) async {
    try {
      final dio = client ?? SecureHttpClient.create();
      final response = await dio.get<dynamic>(
        '$_host/v1/mushafs/$mushafId/$surahNumber',
      );
      final body = response.data;
      final decoded = body is String ? jsonDecode(body) : body;
      return parseResponse(decoded);
    } catch (e) {
      AppLogger.warning('Could not fetch surah $surahNumber: $e');
      return const [];
    }
  }

  /// Read the API payload. Separate so it can be tested without a network.
  ///
  /// The response carries a great deal this app has no use for — tafsir
  /// availability, i`rab, asbab al-nuzul — so only the five fields that make a
  /// page are kept. Al-Baqarah arrives as 377 KB and is stored as a fifth of
  /// that.
  static List<MushafVerse> parseResponse(Object? decoded) {
    if (decoded is! List) {
      return const [];
    }

    final verses = <MushafVerse>[];
    for (final raw in decoded) {
      if (raw is! Map) {
        continue;
      }
      final entry = Map<String, dynamic>.from(raw);
      final number = entry['number'];
      final text = (entry['text'] as String? ?? '').trim();
      if (number is! num || text.isEmpty) {
        continue;
      }

      final page = entry['page_number'];
      final hafs = entry['number_in_hafs'];

      verses.add(
        MushafVerse(
          number: number.toInt(),
          page: page is num ? page.toInt() : 1,
          text: text,
          marker: (entry['marker'] as String? ?? '').trim(),
          hafsNumbers: switch (hafs) {
            final List list => [
              for (final value in list)
                if (value is num) value.toInt(),
            ],
            final num single => [single.toInt()],
            _ => const [],
          },
        ),
      );
    }

    // The mapping is the feature. Without it a verse falls back to its own
    // number, which is the identity mapping — correct in the surahs where the
    // counts happen to agree and quietly wrong in the ones where they do not,
    // with nothing on screen to show which. The provider has never omitted it;
    // if that ever changes, the reader should say the mushaf is unavailable
    // rather than show it mis-aligned.
    for (final verse in verses) {
      if (verse.hafsNumbers.isEmpty) {
        AppLogger.warning(
          'Verse ${verse.number} arrived with no Hafs mapping; '
          'treating the surah as unavailable',
        );
        return const [];
      }
    }

    verses.sort((a, b) => a.number.compareTo(b.number));
    return verses;
  }
}
