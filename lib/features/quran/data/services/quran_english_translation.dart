import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';

/// Saheeh International, one surah at a time, from alquran.cloud.
///
/// The Mushaf itself stays on the device. English is a translation, so it is
/// fetched the first time a surah is opened and then kept — later visits do
/// not need a connection.
class QuranEnglishTranslation {
  QuranEnglishTranslation({Dio? dio})
    : _dio =
          dio ??
          SecureHttpClient.create(baseUrl: AppConstants.alQuranCloudApiBaseUrl);

  static const String edition = 'en.sahih';

  final Dio _dio;
  static const String _boxName = 'quran_en_cache';

  /// Verse number → English text, from one alquran.cloud surah payload.
  static Map<int, String> parse(dynamic data) {
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
      if (number != null && text != null && text.trim().isNotEmpty) {
        verses[number] = text.trim();
      }
    }
    return verses;
  }

  Future<Map<int, String>> forSurah(int surahNumber) async {
    if (surahNumber < 1 || surahNumber > 114) {
      return const {};
    }
    final cached = await _read(surahNumber);
    if (cached != null) {
      return cached;
    }
    try {
      final response = await _dio.get('/surah/$surahNumber/$edition');
      final verses = parse(response.data);
      await _write(surahNumber, verses);
      return verses;
    } catch (e) {
      AppLogger.warning('English Quran fetch failed for $surahNumber: $e');
      return const {};
    }
  }

  Future<Box<Map>> _box() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<Map>(_boxName);
    }
    return Hive.openBox<Map>(_boxName);
  }

  Future<Map<int, String>?> _read(int surahNumber) async {
    try {
      final raw = (await _box()).get('$surahNumber');
      if (raw == null) {
        return null;
      }
      final payload = Map<String, dynamic>.from(raw)['verses'];
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
      AppLogger.warning('English Quran cache read failed: $e');
      return null;
    }
  }

  Future<void> _write(int surahNumber, Map<int, String> verses) async {
    if (verses.isEmpty) {
      return;
    }
    try {
      await (await _box()).put('$surahNumber', {
        'verses': {
          for (final entry in verses.entries) entry.key.toString(): entry.value,
        },
      });
    } catch (e) {
      AppLogger.warning('English Quran cache write failed: $e');
    }
  }
}
