import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Offline-first Azkar data service.
///
/// Strategy:
/// 1) Load valid cached data if available.
/// 2) Otherwise fetch from free remote JSON source and cache it.
/// 3) Fallback to bundled asset JSON.
class AzkarDataService {
  AzkarDataService({Dio? dio}) : _dio = dio ?? Dio();

  static const String _boxName = 'azkar_cache';
  static const String _cacheEntryKey = 'azkar_payload';

  final Dio _dio;

  Future<Map<String, dynamic>> loadAzkarData() async {
    final cached = await _getCachedDataIfValid();
    if (cached != null) {
      return cached;
    }

    final remote = await _fetchRemoteAzkar();
    if (remote != null) {
      await _saveCache(remote);
      return remote;
    }

    final asset = await _loadBundledAzkar();
    await _saveCache(asset);
    return asset;
  }

  Future<Map<String, dynamic>> refreshAzkarData() async {
    final remote = await _fetchRemoteAzkar();
    if (remote != null) {
      await _saveCache(remote);
      return remote;
    }

    final cached = await _getLatestCachedData();
    if (cached != null) {
      return cached;
    }

    final asset = await _loadBundledAzkar();
    await _saveCache(asset);
    return asset;
  }

  Future<void> clearCache() async {
    final box = await _getBox();
    await box.delete(_cacheEntryKey);
  }

  Future<Box<Map>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<Map>(_boxName);
    }
    return Hive.box<Map>(_boxName);
  }

  Future<Map<String, dynamic>?> _getCachedDataIfValid() async {
    final box = await _getBox();
    final raw = box.get(_cacheEntryKey);
    if (raw == null) {
      return null;
    }

    final entry = Map<String, dynamic>.from(raw);
    final cachedAtRaw = entry['cachedAt'] as String?;
    final payloadRaw = entry['payload'];

    if (cachedAtRaw == null || payloadRaw is! Map) {
      return null;
    }

    final cachedAt = DateTime.tryParse(cachedAtRaw);
    if (cachedAt == null) {
      return null;
    }

    final age = DateTime.now().difference(cachedAt);
    if (age > AppConstants.azkarCacheDuration) {
      return null;
    }

    return Map<String, dynamic>.from(payloadRaw);
  }

  Future<Map<String, dynamic>?> _getLatestCachedData() async {
    final box = await _getBox();
    final raw = box.get(_cacheEntryKey);
    if (raw == null) {
      return null;
    }

    final entry = Map<String, dynamic>.from(raw);
    final payloadRaw = entry['payload'];
    if (payloadRaw is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(payloadRaw);
  }

  Future<void> _saveCache(Map<String, dynamic> payload) async {
    final box = await _getBox();
    await box.put(_cacheEntryKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  Future<Map<String, dynamic>?> _fetchRemoteAzkar() async {
    try {
      final response = await _dio.get(AppConstants.azkarJsonUrl);
      final data = response.data;

      if (data is Map && data['categories'] is List) {
        return Map<String, dynamic>.from(data);
      }

      if (data is List) {
        return _normalizeRemoteList(data);
      }

      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return _normalizeRemoteList(decoded);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadBundledAzkar() async {
    final jsonString = await rootBundle.loadString('assets/data/azkar.json');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Map<String, dynamic> _normalizeRemoteList(List<dynamic> list) {
    final categories = <Map<String, dynamic>>[];
    var categoryCounter = 0;

    for (final rawCategory in list) {
      if (rawCategory is! Map) {
        continue;
      }

      final categoryNameAr = (rawCategory['category']?.toString().trim().isNotEmpty == true)
          ? rawCategory['category'].toString().trim()
          : 'أذكار';
      final array = rawCategory['array'];

      if (array is! List || array.isEmpty) {
        continue;
      }

      final azkarItems = <Map<String, dynamic>>[];
      for (final item in array) {
        if (item is! Map) {
          continue;
        }

        final id = (item['id'] as num?)?.toInt() ?? azkarItems.length + 1;
        final textAr = item['text']?.toString() ?? '';
        final count = _parseInt(item['count']) ?? 0;

        azkarItems.add({
          'id': id,
          'textAr': textAr,
          'textEn': '',
          'count': count,
          'audio': item['audio'],
        });
      }

      if (azkarItems.isEmpty) {
        continue;
      }

      categoryCounter++;
      categories.add({
        'id': 'remote_category_$categoryCounter',
        'nameAr': categoryNameAr,
        'nameEn': categoryNameAr,
        'azkar': azkarItems,
      });
    }

    return {
      'categories': categories,
    };
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
