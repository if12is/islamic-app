import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'models/azkar_models.dart';

class AzkarProgressSnapshot {
  final AzkarCategory category;
  final int completedCount;
  final int totalCount;

  const AzkarProgressSnapshot({
    required this.category,
    required this.completedCount,
    required this.totalCount,
  });

  bool get isComplete => totalCount > 0 && completedCount >= totalCount;
}

class AzkarProgressStore {
  AzkarProgressStore._();

  /// Azkar reset twice a day: the morning set in the morning, the evening set
  /// after noon. The key encodes both the day and the half.
  static String sessionKey([DateTime? now]) {
    final moment = now ?? DateTime.now();
    final half = moment.hour < 12 ? 'AM' : 'PM';
    return '${moment.year}-${moment.month}-${moment.day}_$half';
  }

  /// How many of a category's azkar are finished in the current session.
  static Future<AzkarProgressSnapshot> progressFor(
    AzkarCategory category, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = prefs.getString('azkar_session_${category.id}');

    // A stale session means the category starts over.
    final counts =
        savedSession == sessionKey(now)
            ? _countsFor(prefs, category.id)
            : const <int, int>{};

    var completed = 0;
    for (final zekr in category.azkar) {
      if ((counts[zekr.id] ?? 0) >= zekr.targetCount) {
        completed++;
      }
    }

    return AzkarProgressSnapshot(
      category: category,
      completedCount: completed,
      totalCount: category.azkar.length,
    );
  }

  static Future<void> markOpened(String categoryId) async {
    if (categoryId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastAzkarCategoryIdKey, categoryId);
  }

  static Future<AzkarProgressSnapshot?> lastOpened({
    required List<AzkarCategory> categories,
  }) async {
    if (categories.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(AppConstants.lastAzkarCategoryIdKey);
    if (lastId == null || lastId.isEmpty) {
      return null;
    }

    AzkarCategory? category;
    for (final item in categories) {
      if (item.id == lastId) {
        category = item;
        break;
      }
    }
    if (category == null) {
      return null;
    }

    final counts = _countsFor(prefs, category.id);
    var completed = 0;
    for (final zekr in category.azkar) {
      if ((counts[zekr.id] ?? 0) >= zekr.targetCount) {
        completed++;
      }
    }

    return AzkarProgressSnapshot(
      category: category,
      completedCount: completed,
      totalCount: category.azkar.length,
    );
  }

  static Map<int, int> _countsFor(SharedPreferences prefs, String categoryId) {
    final savedCountsStr = prefs.getString('azkar_counts_$categoryId');
    if (savedCountsStr == null) {
      return {};
    }

    try {
      final decoded = json.decode(savedCountsStr) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }
}
