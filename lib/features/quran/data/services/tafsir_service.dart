import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';

/// A tafsir the reader can switch between.
class TafsirEdition {
  const TafsirEdition({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;
}

/// Verse-level tafsir, fetched a whole surah at a time and cached for good.
///
/// Tafsir text never changes, so the first time a surah is opened online it is
/// stored permanently — every later visit, online or not, is instant.
class TafsirService {
  TafsirService({Dio? dio})
    : _dio =
          dio ??
          SecureHttpClient.create(baseUrl: AppConstants.alQuranCloudApiBaseUrl);

  final Dio _dio;

  static const String _boxName = 'tafsir_cache';

  /// Editions verified against the alquran.cloud tafsir list.
  static const List<TafsirEdition> editions = [
    TafsirEdition(
      id: 'ar.muyassar',
      nameAr: 'التفسير الميسّر',
      nameEn: 'Al-Muyassar',
    ),
    TafsirEdition(
      id: 'ar.jalalayn',
      nameAr: 'تفسير الجلالين',
      nameEn: 'Al-Jalalayn',
    ),
    TafsirEdition(
      id: 'ar.waseet',
      nameAr: 'التفسير الوسيط',
      nameEn: 'Al-Waseet',
    ),
    TafsirEdition(
      id: 'ar.baghawi',
      nameAr: 'تفسير البغوي',
      nameEn: 'Al-Baghawi',
    ),
    TafsirEdition(
      id: 'ar.qurtubi',
      nameAr: 'تفسير القرطبي',
      nameEn: 'Al-Qurtubi',
    ),
  ];

  static TafsirEdition editionById(String id) {
    return editions.firstWhere(
      (edition) => edition.id == id,
      orElse: () => editions.first,
    );
  }

  static bool isKnownEdition(String id) =>
      editions.any((edition) => edition.id == id);

  Future<Box<Map>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<Map>(_boxName);
    }
    return Hive.openBox<Map>(_boxName);
  }

  /// Tafsir for one verse, or null when it is neither cached nor reachable.
  Future<String?> forVerse({
    required String editionId,
    required int surahNumber,
    required int verseNumber,
  }) async {
    final surah = await forSurah(
      editionId: editionId,
      surahNumber: surahNumber,
    );
    return surah[verseNumber];
  }

  /// Whole-surah tafsir keyed by verse number.
  Future<Map<int, String>> forSurah({
    required String editionId,
    required int surahNumber,
  }) async {
    if (!isKnownEdition(editionId) || surahNumber < 1 || surahNumber > 114) {
      return const {};
    }

    final cacheKey = '$editionId:$surahNumber';
    final cached = await _readCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _dio.get('/surah/$surahNumber/$editionId');
      final data = response.data;
      if (data is! Map || data['data'] is! Map) {
        return const {};
      }

      final ayahs = (data['data'] as Map)['ayahs'];
      if (ayahs is! List) {
        return const {};
      }

      final verses = <int, String>{};
      for (final ayah in ayahs) {
        if (ayah is! Map) {
          continue;
        }
        final number = (ayah['numberInSurah'] as num?)?.toInt();
        final text = ayah['text'] as String?;
        if (number != null && text != null && text.isNotEmpty) {
          verses[number] = text;
        }
      }

      await _writeCache(cacheKey, verses);
      return verses;
    } catch (e) {
      AppLogger.warning('Tafsir fetch failed for $cacheKey: $e');
      return const {};
    }
  }

  /// True when the surah is already available offline.
  Future<bool> isCached({
    required String editionId,
    required int surahNumber,
  }) async {
    return await _readCache('$editionId:$surahNumber') != null;
  }

  Future<Map<int, String>?> _readCache(String key) async {
    try {
      final box = await _openBox();
      final raw = box.get(key);
      if (raw == null) {
        return null;
      }

      final wrapper = Map<String, dynamic>.from(raw);
      final payload = wrapper['verses'];
      if (payload is! Map) {
        return null;
      }

      final verses = <int, String>{};
      for (final entry in payload.entries) {
        final number = int.tryParse(entry.key.toString());
        if (number != null && entry.value is String) {
          verses[number] = entry.value as String;
        }
      }
      return verses.isEmpty ? null : verses;
    } catch (e) {
      AppLogger.warning('Tafsir cache read failed: $e');
      return null;
    }
  }

  Future<void> _writeCache(String key, Map<int, String> verses) async {
    if (verses.isEmpty) {
      return;
    }
    try {
      final box = await _openBox();
      await box.put(key, {
        'cachedAt': DateTime.now().toIso8601String(),
        'verses': {
          for (final entry in verses.entries) entry.key.toString(): entry.value,
        },
      });
    } catch (e) {
      AppLogger.warning('Tafsir cache write failed: $e');
    }
  }
}
