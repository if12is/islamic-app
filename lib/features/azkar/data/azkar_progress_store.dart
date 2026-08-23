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

  /// Azkar reset at midnight, not at Dhuhr. Morning recited before noon
  /// must still be there after the adhan.
  static String sessionKey([DateTime? now]) {
    final moment = now ?? DateTime.now();
    return '${moment.year}-${moment.month}-${moment.day}';
  }

  /// Whether [saved] is still today's session.
  ///
  /// Older builds stored `yyyy-m-d_AM` / `_PM`. Both halves of today count
  /// as the same day so opening after Dhuhr does not wipe the morning set.
  static bool sameSession(String? saved, [DateTime? now]) {
    if (saved == null || saved.isEmpty) {
      return false;
    }
    final today = sessionKey(now);
    return saved == today || saved == '${today}_AM' || saved == '${today}_PM';
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
        sameSession(savedSession, now)
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

    return progressFor(category);
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
