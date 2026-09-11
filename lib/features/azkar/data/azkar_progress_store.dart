import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Moves whenever a count is written, so anything showing a count — the
  /// daily wird, the misbaha — can read it again instead of going stale.
  ///
  /// Debounced: a run of taps is one change, not thirty-three, because every
  /// listener re-reads the stores and the dashboard is always listening.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static Timer? _pendingNotify;

  static void notifyChanged() {
    _pendingNotify?.cancel();
    _pendingNotify = Timer(const Duration(milliseconds: 350), () {
      revision.value++;
    });
  }

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

  /// Today's count for every dhikr in a category, keyed by dhikr id.
  static Map<int, int> countsToday(
    SharedPreferences prefs,
    String categoryId, {
    DateTime? now,
  }) {
    final saved = prefs.getString('azkar_session_$categoryId');
    return sameSession(saved, now)
        ? _countsFor(prefs, categoryId)
        : <int, int>{};
  }

  /// Write a category's counts for today.
  ///
  /// Both writes are started before either is awaited. The store updates its
  /// cache when a write starts, so this way the new counts are readable at
  /// once — awaiting the session first left a gap in which a second quick tap
  /// read the old counts and one of the two was lost.
  static Future<void> saveCounts(
    SharedPreferences prefs,
    String categoryId,
    Map<int, int> counts, {
    DateTime? now,
  }) async {
    final session = prefs.setString(
      'azkar_session_$categoryId',
      sessionKey(now),
    );
    final values = prefs.setString(
      'azkar_counts_$categoryId',
      json.encode(counts.map((key, value) => MapEntry('$key', value))),
    );
    notifyChanged();
    await Future.wait([session, values]);
  }

  /// Add one to a single dhikr, stopping at [cap], and hand back its count.
  ///
  /// Used when the count comes from somewhere other than the chapter's own
  /// screen — the misbaha counting a phrase the wird also asks for.
  static Future<int> addOne(
    SharedPreferences prefs,
    String categoryId,
    int zekrId, {
    required int cap,
    DateTime? now,
  }) async {
    final counts = countsToday(prefs, categoryId, now: now);
    final current = counts[zekrId] ?? 0;
    if (current >= cap) {
      return current;
    }
    counts[zekrId] = current + 1;
    await saveCounts(prefs, categoryId, counts, now: now);
    return current + 1;
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
