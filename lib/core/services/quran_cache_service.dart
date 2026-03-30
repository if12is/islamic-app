import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Offline-first cache service for Quran chapters and verses.
class QuranCacheService {
  static const String _boxName = 'quran_cache';
  static const String _chaptersKey = 'chapters';

  Future<List<Map<String, dynamic>>> getChapters({
    required Dio dio,
    bool forceRefresh = false,
  }) async {
    final cache = await _readEntry(_chaptersKey);
    if (!forceRefresh && cache != null && _isFresh(cache)) {
      return _readList(cache['payload'], 'chapters');
    }

    try {
      final response = await dio.get('/chapters', queryParameters: {'language': 'en'});
      final payload = response.data;
      await _writeEntry(_chaptersKey, payload);
      return _readList(payload, 'chapters');
    } catch (_) {
      if (cache != null) {
        return _readList(cache['payload'], 'chapters');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getVerses({
    required Dio dio,
    required int chapterId,
    bool forceRefresh = false,
  }) async {
    final key = 'verses_$chapterId';
    final cache = await _readEntry(key);
    if (!forceRefresh && cache != null && _isFresh(cache)) {
      return _readList(cache['payload'], 'verses');
    }

    try {
      final response = await dio.get(
        '/verses/by_chapter/$chapterId',
        queryParameters: {
          'language': 'en',
          'words': false,
          'translations': 131,
          'fields': 'text_uthmani,verse_key',
          'per_page': 300,
          'page': 1,
        },
      );
      final payload = response.data;
      await _writeEntry(key, payload);
      return _readList(payload, 'verses');
    } catch (_) {
      if (cache != null) {
        return _readList(cache['payload'], 'verses');
      }
      rethrow;
    }
  }

  Future<void> clearChaptersCache() async {
    final box = await _getBox();
    await box.delete(_chaptersKey);
  }

  Future<void> clearVersesCache(int chapterId) async {
    final box = await _getBox();
    await box.delete('verses_$chapterId');
  }

  Future<Box<Map>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<Map>(_boxName);
    }
    return Hive.box<Map>(_boxName);
  }

  Future<Map<String, dynamic>?> _readEntry(String key) async {
    final box = await _getBox();
    final raw = box.get(key);
    if (raw == null) {
      return null;
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<void> _writeEntry(String key, dynamic payload) async {
    final box = await _getBox();
    await box.put(key, {
      'cachedAt': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  bool _isFresh(Map<String, dynamic> entry) {
    final raw = entry['cachedAt'] as String?;
    if (raw == null) {
      return false;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return false;
    }

    return DateTime.now().difference(parsed) <= AppConstants.quranCacheDuration;
  }

  List<Map<String, dynamic>> _readList(dynamic payload, String key) {
    if (payload is Map) {
      final values = payload[key];
      if (values is List) {
        return values
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return [];
  }
}
