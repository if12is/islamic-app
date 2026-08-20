import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Azkar data, straight from the app bundle.
///
/// The full Hisn al-Muslim (136 chapters, 352 supplications with their
/// virtues and references) ships with the app, so there is nothing to
/// download and nothing to lose when offline. Hive caches the parsed payload
/// only to skip re-reading the asset on every launch.
class AzkarDataService {
  AzkarDataService();

  static const String _boxName = 'azkar_cache';
  static const String _cacheEntryKey = 'azkar_payload';

  Future<Map<String, dynamic>> loadAzkarData() async {
    final cached = await _getCachedDataIfValid();
    if (cached != null) {
      return cached;
    }

    return refreshAzkarData();
  }

  Future<Map<String, dynamic>> refreshAzkarData() async {
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

  Future<void> _saveCache(Map<String, dynamic> payload) async {
    final box = await _getBox();
    await box.put(_cacheEntryKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'payload': payload,
    });
  }

  Future<Map<String, dynamic>> _loadBundledAzkar() async {
    final jsonString = await rootBundle.loadString('assets/data/azkar.json');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
}
