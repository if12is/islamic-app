import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/entities/hifz_item.dart';

/// Persistent store for memorisation passages and their review schedule.
class HifzStore {
  static const String _boxName = 'hifz_items';

  Future<Box<Map>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<Map>(_boxName);
    }
    return Hive.openBox<Map>(_boxName);
  }

  /// Everything being memorised, due passages first.
  Future<List<HifzItem>> all() async {
    try {
      final box = await _openBox();
      final items =
          box.values
              .map((raw) => HifzItem.fromJson(Map<dynamic, dynamic>.from(raw)))
              .toList();

      items.sort((a, b) {
        final byDue = a.dueDate.compareTo(b.dueDate);
        if (byDue != 0) {
          return byDue;
        }
        final bySurah = a.surahNumber.compareTo(b.surahNumber);
        return bySurah != 0 ? bySurah : a.fromAyah.compareTo(b.fromAyah);
      });
      return items;
    } catch (e, stack) {
      AppLogger.error('Failed to read hifz items', e, stack);
      return const [];
    }
  }

  Future<void> save(HifzItem item) async {
    final box = await _openBox();
    await box.put(item.key, item.toJson());
  }

  Future<void> remove(String key) async {
    final box = await _openBox();
    await box.delete(key);
  }

  Future<bool> contains(String key) async {
    final box = await _openBox();
    return box.containsKey(key);
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.clear();
  }
}
