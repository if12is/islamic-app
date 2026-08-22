import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_logger.dart';
import 'quran_local_service.dart';

/// One recording of the whole Mushaf by one reciter.
///
/// A reciter may have several — murattal, mujawwad, a different riwayah — and
/// they are separate recordings with separate servers, so each is its own
/// entry rather than a variant hidden behind a name.
class ReciterVoice {
  const ReciterVoice({
    required this.id,
    required this.nameAr,
    required this.styleAr,
    required this.server,
    required this.surahs,
  });

  /// `mp3quran:1:1` — reciter id and moshaf id, so a saved choice survives the
  /// list being re-fetched in a different order.
  final String id;

  final String nameAr;

  /// "حفص عن عاصم - مرتل".
  final String styleAr;

  /// Directory the numbered files sit in, with a trailing slash.
  final String server;

  /// Which surahs this recording actually contains. Most have all 114, but
  /// some are partial, and offering a surah that 404s is worse than hiding it.
  final Set<int> surahs;

  bool has(int surahNumber) => surahs.contains(surahNumber);

  String? urlFor(int surahNumber) {
    if (!has(surahNumber)) {
      return null;
    }
    final base = server.endsWith('/') ? server : '$server/';
    return '$base${surahNumber.toString().padLeft(3, '0')}.mp3';
  }

  /// Name and style together, for a list where several rows share a name.
  String get label => styleAr.isEmpty ? nameAr : '$nameAr — $styleAr';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': nameAr,
    'style': styleAr,
    'server': server,
    'surahs': surahs.toList()..sort(),
  };

  static ReciterVoice? fromJson(Map<String, dynamic> json) {
    final server = json['server'] as String? ?? '';
    if (server.isEmpty) {
      return null;
    }
    return ReciterVoice(
      id: json['id'] as String? ?? '',
      nameAr: json['name'] as String? ?? '',
      styleAr: json['style'] as String? ?? '',
      server: server,
      surahs: {
        for (final value in (json['surahs'] as List? ?? const []))
          if (value is num) value.toInt(),
      },
    );
  }
}

/// Every reciter mp3quran.net publishes, not just the handful hard-coded here.
///
/// The bundled list was seven voices, which is seven more than nothing but far
/// short of what exists. This fetches the full catalogue — two hundred and
/// forty-odd recordings — and keeps it on the device, so it is fetched once
/// and then works offline like everything else in the app.
class ReciterCatalogue {
  ReciterCatalogue._();

  static const String _endpoint =
      'https://mp3quran.net/api/v3/reciters?language=ar';

  static const String cacheKey = 'reciter_catalogue_v1';
  static const String cachedAtKey = 'reciter_catalogue_fetched_at';

  /// Re-fetch at most this often; new reciters are not urgent news.
  static const Duration refreshAfter = Duration(days: 14);

  static List<ReciterVoice>? _memory;

  /// The voices that ship with the app, so the picker is never empty and the
  /// first launch needs no network.
  static List<ReciterVoice> get bundled => [
    for (final entry in QuranLocalService.surahAudioHosts.entries)
      ReciterVoice(
        id: entry.key,
        nameAr: _bundledNames[entry.key] ?? entry.key,
        styleAr: '',
        server: entry.value,
        surahs: {for (var i = 1; i <= 114; i++) i},
      ),
  ];

  static const Map<String, String> _bundledNames = {
    'ar.alafasy': 'مشاري العفاسي',
    'ar.mahermuaiqly': 'ماهر المعيقلي',
    'ar.husary': 'محمود الحصري',
    'ar.minshawi': 'محمد المنشاوي',
    'ar.abdurrahmaansudais': 'عبدالرحمن السديس',
    'ar.shaatree': 'أبو بكر الشاطري',
    'ar.ahmedajamy': 'أحمد العجمي',
  };

  /// What the picker should show: the cache if there is one, else the bundled
  /// seven. Never returns empty.
  static Future<List<ReciterVoice>> load({bool refresh = false}) async {
    if (_memory != null && !refresh) {
      return _memory!;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);

    if (cached.isNotEmpty && !refresh && !_isStale(prefs)) {
      _register(cached);
      return _memory = cached;
    }

    final fetched = await _fetch();
    if (fetched.isNotEmpty) {
      await _writeCache(prefs, fetched);
      _register(fetched);
      return _memory = fetched;
    }

    // Offline, or the service is down: whatever is on hand still works.
    final fallback = cached.isNotEmpty ? cached : bundled;
    _register(fallback);
    return _memory = fallback;
  }

  /// Teach the URL builder about every voice, so a choice from the catalogue
  /// resolves exactly like one of the bundled seven.
  static void _register(List<ReciterVoice> voices) {
    for (final voice in voices) {
      QuranLocalService.registerSurahHost(voice.id, voice.server);
    }
  }

  static ReciterVoice? byId(String id, List<ReciterVoice> voices) {
    for (final voice in voices) {
      if (voice.id == id) {
        return voice;
      }
    }
    return null;
  }

  static bool _isStale(SharedPreferences prefs) {
    final at = prefs.getInt(cachedAtKey);
    if (at == null) {
      return true;
    }
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) >=
        refreshAfter;
  }

  static List<ReciterVoice> _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>)
            if (ReciterVoice.fromJson(entry) case final voice?) voice,
      ];
    } catch (e) {
      AppLogger.warning('Reciter cache unreadable: $e');
      return const [];
    }
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    List<ReciterVoice> voices,
  ) async {
    await prefs.setString(
      cacheKey,
      jsonEncode([for (final voice in voices) voice.toJson()]),
    );
    await prefs.setInt(cachedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<ReciterVoice>> _fetch() async {
    try {
      final response = await Dio().get<dynamic>(
        _endpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          followRedirects: true,
        ),
      );
      final body = response.data;
      final json =
          body is String
              ? jsonDecode(body) as Map<String, dynamic>
              : Map<String, dynamic>.from(body as Map);
      return parse(json);
    } catch (e) {
      AppLogger.warning('Could not fetch the reciter list: $e');
      return const [];
    }
  }

  /// Read the API payload. Separate so it can be tested without a network.
  static List<ReciterVoice> parse(Map<String, dynamic> json) {
    final reciters = json['reciters'];
    if (reciters is! List) {
      return const [];
    }

    final voices = <ReciterVoice>[];
    final seen = <String>{};
    for (final raw in reciters) {
      if (raw is! Map) {
        continue;
      }
      final reciter = Map<String, dynamic>.from(raw);
      final name = (reciter['name'] as String? ?? '').trim();
      final reciterId = reciter['id'];
      final moshafs = reciter['moshaf'];
      if (name.isEmpty || moshafs is! List) {
        continue;
      }

      for (final rawMoshaf in moshafs) {
        if (rawMoshaf is! Map) {
          continue;
        }
        final moshaf = Map<String, dynamic>.from(rawMoshaf);
        final server = (moshaf['server'] as String? ?? '').trim();
        if (!server.startsWith('https://')) {
          // http:// would be blocked by the network security config, and
          // silently listing a voice that cannot play is worse than omitting it.
          continue;
        }

        final surahs = _surahList(moshaf['surah_list']);
        if (surahs.isEmpty) {
          continue;
        }

        final id = 'mp3quran:$reciterId:${moshaf['id']}';
        if (!seen.add(id)) {
          continue;
        }

        voices.add(
          ReciterVoice(
            id: id,
            nameAr: name,
            styleAr: (moshaf['name'] as String? ?? '').trim(),
            server: server,
            surahs: surahs,
          ),
        );
      }
    }

    voices.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return voices;
  }

  static Set<int> _surahList(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return const {};
    }
    return {
      for (final part in raw.split(','))
        if (int.tryParse(part.trim()) case final number?)
          if (number >= 1 && number <= 114) number,
    };
  }
}
