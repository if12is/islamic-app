import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/riwaya.dart';

/// Where one ayah begins and ends inside a whole-surah recording.
class AyahTiming {
  const AyahTiming({required this.ayah, required this.start, this.end});

  /// The verse number **in the recording's own reading**.
  ///
  /// Measured, not assumed: the provider returns 285 entries for al-Baqarah
  /// and 130 for al-Tawbah on its Qalun and Warsh recordings, which is the
  /// Madani count — the same one the mushaf on screen is printed in. A Hafs
  /// recording returns 286 and 129. So the number here lines up with the verse
  /// the reader is looking at, provided the reading matches, which is the only
  /// combination the picker ever offers.
  final int ayah;

  final Duration start;

  /// Where to stop. Null on the last verse, where the file simply runs out.
  final Duration? end;

  Map<String, dynamic> toJson() => {
    'a': ayah,
    's': start.inMilliseconds,
    if (end != null) 'e': end!.inMilliseconds,
  };

  static AyahTiming? fromJson(Map<String, dynamic> json) {
    final ayah = json['a'];
    final start = json['s'];
    if (ayah is! num || start is! num) {
      return null;
    }
    final end = json['e'];
    return AyahTiming(
      ayah: ayah.toInt(),
      start: Duration(milliseconds: start.toInt()),
      end: end is num ? Duration(milliseconds: end.toInt()) : null,
    );
  }
}

/// Per-ayah playback for readings that have no per-ayah recordings.
///
/// The per-ayah host carries one corpus, indexed for Hafs, plus three Warsh
/// folders. For Qalun it carries nothing at all — so «استماع» on a single ayah,
/// the memorisation loop and the repeat control would simply be absent for a
/// reader of Qalun, and absent is how a feature looks when it was never built.
///
/// mp3quran publishes, for many of its recordings, the millisecond at which
/// each verse starts. A whole-surah file plus those marks is a per-ayah
/// recitation: the player is handed a clipped region rather than a separate
/// file. It is the same source the whole-surah list already comes from, which
/// is what the reader asked for — one list, not three — and it works for every
/// riwayah the provider carries rather than the two that happen to have folders.
///
/// Not every recording has marks. The ones that do not are hidden, in keeping
/// with the rule the rest of this feature follows: a row that cannot play does
/// not appear.
class AyahTimingService {
  AyahTimingService._();

  /// The `www` is load-bearing: the bare domain answers 301 and
  /// [SecureHttpClient] follows no redirects and allowlists only this host.
  static const String endpoint = 'https://www.mp3quran.net/api/v3/ayat_timing';

  static const String _folder = 'ayah_timings';

  /// At-Tawbah, which settles both questions in one request.
  ///
  /// It has 129 verses in the Kufan count and 130 in the Madani one, so the
  /// last mark's number says outright which scheme a recording was marked in —
  /// and an empty answer says it has no marks at all. A shorter surah would be
  /// a cheaper request and a useless one: al-Ikhlas has four verses in every
  /// reading, and would let a recording through with its numbering unknown.
  static const int probeSurah = 9;

  /// At-Tawbah's verse count in the Kufan scheme, which the bundled index is.
  static const int _probeHafsCount = 129;

  static const String _verdictKey = 'ayah_timing_verdict_v2';

  static final Map<String, List<AyahTiming>> _memory = {};
  static final Map<String, Future<List<AyahTiming>>> _inFlight = {};

  /// What is known about each recording: how it numbers verses, or null when
  /// it carries no marks and cannot be cut at all.
  static Map<int, VerseCounting?>? _verdicts;

  static String _keyFor(int moshafId, int surahNumber) =>
      '$moshafId:$surahNumber';

  /// The marks for one surah of one recording, or empty when it has none.
  static Future<List<AyahTiming>> forSurah(
    int moshafId,
    int surahNumber, {
    Dio? client,
  }) async {
    final key = _keyFor(moshafId, surahNumber);
    final remembered = _memory[key];
    if (remembered != null) {
      return remembered;
    }
    final running = _inFlight[key];
    if (running != null) {
      return running;
    }

    final future = _resolve(moshafId, surahNumber, client);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<List<AyahTiming>> _resolve(
    int moshafId,
    int surahNumber,
    Dio? client,
  ) async {
    final key = _keyFor(moshafId, surahNumber);

    final cached = await _readCache(moshafId, surahNumber);
    if (cached.isNotEmpty) {
      return _memory[key] = cached;
    }

    final fetched = await _fetch(moshafId, surahNumber, client);
    if (fetched == null || fetched.isEmpty) {
      return const [];
    }
    await _writeCache(moshafId, surahNumber, fetched);
    return _memory[key] = fetched;
  }

  /// How this recording numbers its verses, or null when it has no marks.
  ///
  /// Measured, never inferred from the riwayah. Of the five Warsh recordings
  /// that carry marks, four are numbered the way the Warsh mushaf is printed
  /// and one — Muhammad Sayed's — is numbered in Hafs. Assuming the reading's
  /// own scheme would have played him one ayah out for the length of
  /// al-Baqarah, without an error anywhere, which is the same trap the
  /// per-ayah folders set and the reason this is asked rather than assumed.
  ///
  /// Remembered on the device in every direction, so each recording is asked
  /// about once.
  static Future<VerseCounting?> countingOf(int moshafId, {Dio? client}) async {
    await _loadVerdicts();
    if (_verdicts!.containsKey(moshafId)) {
      return _verdicts![moshafId];
    }

    final marks = await _probe(moshafId, client);
    if (marks == null) {
      // The question was never answered — no signal, a timeout, a bad
      // gateway. Writing "no marks" here would hide the recording for good on
      // the strength of one moment offline, and nothing in the picker offers
      // a way to ask again. Left unknown, so the next open asks.
      return null;
    }
    final verdict = countingFrom(marks);
    _verdicts![moshafId] = verdict;
    await _saveVerdicts();
    return verdict;
  }

  /// The probe surah's marks, or null when the request itself failed.
  ///
  /// The distinction is the whole point: an empty list is the provider saying
  /// this recording has no marks, which is an answer. A failed request is not.
  static Future<List<AyahTiming>?> _probe(int moshafId, Dio? client) async {
    final key = _keyFor(moshafId, probeSurah);
    final remembered = _memory[key];
    if (remembered != null) {
      return remembered;
    }
    final cached = await _readCache(moshafId, probeSurah);
    if (cached.isNotEmpty) {
      return _memory[key] = cached;
    }

    final fetched = await _fetch(moshafId, probeSurah, client);
    if (fetched == null) {
      return null;
    }
    if (fetched.isNotEmpty) {
      await _writeCache(moshafId, probeSurah, fetched);
      _memory[key] = fetched;
    }
    return fetched;
  }

  /// Read the probe's marks. Separate so it can be tested without a network.
  ///
  /// Anything that matches neither count is refused rather than guessed at: a
  /// partial or truncated set of marks would otherwise be filed under one
  /// scheme and play the wrong ayah under it.
  static VerseCounting? countingFrom(List<AyahTiming> marks) {
    if (marks.isEmpty) {
      return null;
    }
    final last = marks.last.ayah;
    if (last == _probeHafsCount) {
      return VerseCounting.hafs;
    }
    if (last == _probeHafsCount + 1) {
      return VerseCounting.madaniAkhir;
    }
    return null;
  }

  /// What is already known, without asking the network.
  ///
  /// A picker builds synchronously; it shows what is known to work, and asks
  /// about the rest in the background.
  static VerseCounting? knownCounting(int moshafId) => _verdicts?[moshafId];

  /// Whether an answer has been recorded for this recording yet.
  static bool isKnown(int moshafId) =>
      _verdicts?.containsKey(moshafId) ?? false;

  /// True, false, or null when it has not been asked about yet.
  static bool? knownSupport(int moshafId) =>
      isKnown(moshafId) ? knownCounting(moshafId) != null : null;

  /// How many probes may be in flight at once.
  ///
  /// Not one — sixteen requests end to end is a sheet that sits blank for
  /// several seconds. Not all of them either: the provider's rate limit is
  /// generous but this is a question about which rows to draw, and firing a
  /// dozen requests at once to answer it is not proportionate.
  static const int probeConcurrency = 4;

  /// Fill in what is known about a list of recordings, a few at a time.
  static Future<void> warmSupport(
    Iterable<int> moshafIds, {
    Dio? client,
  }) async {
    await _loadVerdicts();
    final pending = [
      for (final id in moshafIds)
        if (!isKnown(id)) id,
    ];

    for (var start = 0; start < pending.length; start += probeConcurrency) {
      final batch = pending.skip(start).take(probeConcurrency);
      await Future.wait([
        for (final id in batch) countingOf(id, client: client),
      ]);
    }
  }

  static Future<void> _loadVerdicts() async {
    if (_verdicts != null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _verdicts = readVerdicts(prefs.getString(_verdictKey));
    } catch (e) {
      AppLogger.warning('Could not read ayah timing verdicts: $e');
      _verdicts ??= <int, VerseCounting?>{};
    }
  }

  /// `{"134":"hafs","120":"madaniAkhir","178":null}` — null means "no marks".
  ///
  /// Stored by name rather than by index so that adding a counting scheme
  /// later does not silently re-read every stored verdict as a different one.
  @visibleForTesting
  static Map<int, VerseCounting?> readVerdicts(String? raw) {
    final verdicts = <int, VerseCounting?>{};
    if (raw == null || raw.isEmpty) {
      return verdicts;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return verdicts;
      }
      decoded.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id == null) {
          return;
        }
        verdicts[id] = switch (value) {
          'hafs' => VerseCounting.hafs,
          'madaniAkhir' => VerseCounting.madaniAkhir,
          _ => null,
        };
      });
    } catch (e) {
      AppLogger.warning('Ayah timing verdicts unreadable: $e');
    }
    return verdicts;
  }

  @visibleForTesting
  static String writeVerdicts(Map<int, VerseCounting?> verdicts) => jsonEncode({
    for (final entry in verdicts.entries) '${entry.key}': entry.value?.name,
  });

  static Future<void> _saveVerdicts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _verdictKey,
        writeVerdicts(_verdicts ?? const <int, VerseCounting?>{}),
      );
    } catch (e) {
      AppLogger.warning('Could not store ayah timing verdicts: $e');
    }
  }

  static Future<File> _fileFor(int moshafId, int surahNumber) async {
    final root = await getApplicationDocumentsDirectory();
    return File('${root.path}/$_folder/$moshafId/$surahNumber.json');
  }

  static Future<List<AyahTiming>> _readCache(
    int moshafId,
    int surahNumber,
  ) async {
    try {
      final file = await _fileFor(moshafId, surahNumber);
      if (!await file.exists()) {
        return const [];
      }
      return parseCache(await file.readAsString());
    } catch (e) {
      AppLogger.warning('Ayah timing cache unreadable: $e');
      return const [];
    }
  }

  static Future<void> _writeCache(
    int moshafId,
    int surahNumber,
    List<AyahTiming> marks,
  ) async {
    try {
      final file = await _fileFor(moshafId, surahNumber);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([for (final mark in marks) mark.toJson()]),
      );
    } catch (e) {
      AppLogger.warning('Could not cache ayah timings: $e');
    }
  }

  static List<AyahTiming> parseCache(String raw) {
    if (raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final entry in decoded)
        if (entry is Map)
          if (AyahTiming.fromJson(Map<String, dynamic>.from(entry))
              case final mark?)
            mark,
    ];
  }

  /// Null when the request failed, as opposed to answering "no marks".
  static Future<List<AyahTiming>?> _fetch(
    int moshafId,
    int surahNumber,
    Dio? client,
  ) async {
    try {
      final dio = client ?? SecureHttpClient.create();
      final response = await dio.get<dynamic>(
        '$endpoint?surah=$surahNumber&read=$moshafId',
      );
      final body = response.data;
      final decoded = body is String ? jsonDecode(body) : body;
      // A payload that is not a list is not an answer either — that is what a
      // gateway error page looks like once it has been decoded.
      return decoded is List ? parse(decoded) : null;
    } catch (e) {
      AppLogger.warning('Could not fetch ayah timings for $moshafId: $e');
      return null;
    }
  }

  /// Read the API payload. Separate so it can be tested without a network.
  ///
  /// Entry zero is the basmala and the isti`adha before the surah proper, not
  /// a verse; it is dropped so that asking for ayah 1 does not return the
  /// introduction. A recording without marks answers `[]`, which is how the
  /// picker learns to hide it.
  static List<AyahTiming> parse(Object? decoded) {
    if (decoded is! List) {
      return const [];
    }

    final marks = <AyahTiming>[];
    for (final raw in decoded) {
      if (raw is! Map) {
        continue;
      }
      final entry = Map<String, dynamic>.from(raw);
      final ayah = entry['ayah'];
      final start = entry['start_time'];
      if (ayah is! num || start is! num || ayah.toInt() < 1) {
        continue;
      }
      final end = entry['end_time'];
      final startAt = Duration(milliseconds: start.toInt());
      final endAt = end is num ? Duration(milliseconds: end.toInt()) : null;
      marks.add(
        AyahTiming(
          ayah: ayah.toInt(),
          start: startAt,
          // A zero or backwards end is the provider saying "to the end of the
          // file". Passing it on as a clip would play nothing at all.
          end: endAt != null && endAt > startAt ? endAt : null,
        ),
      );
    }

    marks.sort((a, b) => a.ayah.compareTo(b.ayah));
    return marks;
  }

  /// The mark for one verse, or null when the recording skips it.
  static AyahTiming? find(List<AyahTiming> marks, int ayah) {
    for (final mark in marks) {
      if (mark.ayah == ayah) {
        return mark;
      }
    }
    return null;
  }

  /// Forget everything, for a test or a storage reset.
  @visibleForTesting
  static void resetForTest() {
    _memory.clear();
    _inFlight.clear();
    _verdicts = null;
  }

  /// Record a verdict without a network, for a test.
  @visibleForTesting
  static void seedVerdictForTest(int moshafId, VerseCounting? counting) {
    (_verdicts ??= <int, VerseCounting?>{})[moshafId] = counting;
  }
}
