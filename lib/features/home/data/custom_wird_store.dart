import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/custom_wird.dart';

/// Reads and writes the reader's own wird.
class CustomWirdStore {
  CustomWirdStore._();

  static const String itemsKey = 'custom_wird_items';

  /// Today's counts, stored under the day they belong to.
  ///
  /// One key holding both the date and the counts, rather than a date key and
  /// a counts key that can fall out of step and leave yesterday's progress
  /// looking like today's.
  static const String progressKey = 'custom_wird_progress';

  static CustomWird read(SharedPreferences prefs, {DateTime? now}) {
    return CustomWird(
      items: _readItems(prefs),
      doneToday: _readProgress(prefs, now ?? DateTime.now()),
    );
  }

  static List<CustomWirdItem> _readItems(SharedPreferences prefs) {
    final raw = prefs.getString(itemsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return [
        for (final entry in decoded)
          if (entry is Map)
            if (CustomWirdItem.fromJson(entry) case final item?) item,
      ];
    } catch (e) {
      AppLogger.warning('Custom wird unreadable: $e');
      return const [];
    }
  }

  /// Yesterday's counts are not today's, so a stored day that is not today
  /// reads as an empty slate rather than being carried over.
  static Map<String, int> _readProgress(SharedPreferences prefs, DateTime now) {
    final raw = prefs.getString(progressKey);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['day'] != dayKey(now)) {
        return const {};
      }
      final counts = decoded['counts'];
      if (counts is! Map) {
        return const {};
      }
      return {
        for (final entry in counts.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toInt(),
      };
    } catch (e) {
      AppLogger.warning('Custom wird progress unreadable: $e');
      return const {};
    }
  }

  /// `2026-08-27`. Local, because a wird belongs to the reader's day, not to
  /// UTC's.
  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static Future<void> writeItems(
    SharedPreferences prefs,
    List<CustomWirdItem> items,
  ) => prefs.setString(
    itemsKey,
    jsonEncode([for (final item in items) item.toJson()]),
  );

  static Future<void> writeProgress(
    SharedPreferences prefs,
    Map<String, int> counts, {
    DateTime? now,
  }) => prefs.setString(
    progressKey,
    jsonEncode({'day': dayKey(now ?? DateTime.now()), 'counts': counts}),
  );

  /// Add a line, or replace the one already there for the same thing.
  ///
  /// Adding the same surah twice is a slip, not an intention to read it twice,
  /// so the id carries what the line points at and a second add updates rather
  /// than duplicating.
  static List<CustomWirdItem> withItem(
    List<CustomWirdItem> items,
    CustomWirdItem item,
  ) {
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index < 0) {
      return [...items, item];
    }
    final copy = [...items];
    copy[index] = item;
    return copy;
  }

  static List<CustomWirdItem> withoutId(
    List<CustomWirdItem> items,
    String id,
  ) => [
    for (final item in items)
      if (item.id != id) item,
  ];

  /// Move a line, for a reader ordering their wird the way they pray it.
  static List<CustomWirdItem> reordered(
    List<CustomWirdItem> items,
    int from,
    int to,
  ) {
    if (from < 0 || from >= items.length || to < 0 || to >= items.length) {
      return items;
    }
    final copy = [...items];
    copy.insert(to, copy.removeAt(from));
    return copy;
  }
}
