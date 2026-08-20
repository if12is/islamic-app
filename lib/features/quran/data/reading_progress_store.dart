import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/app_logger.dart';

/// One day of reading.
class ReadingDay {
  const ReadingDay({
    required this.date,
    required this.pages,
    required this.minutes,
  });

  final DateTime date;

  /// Distinct Mushaf pages opened that day.
  final Set<int> pages;

  /// Minutes spent in the reader.
  final int minutes;

  int get pageCount => pages.length;

  bool get isEmpty => pages.isEmpty && minutes == 0;

  static ReadingDay empty(DateTime date) =>
      ReadingDay(date: date, pages: const {}, minutes: 0);
}

/// Totals across the whole log.
class ReadingTotals {
  const ReadingTotals({
    required this.days,
    required this.pages,
    required this.minutes,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int days;
  final int pages;
  final int minutes;
  final int currentStreak;
  final int longestStreak;

  static const ReadingTotals empty = ReadingTotals(
    days: 0,
    pages: 0,
    minutes: 0,
    currentStreak: 0,
    longestStreak: 0,
  );
}

/// The reading log: which pages were read on which day, and for how long.
///
/// Pages are stored as a set, so re-reading the same page does not inflate the
/// count — the number a user sees is how much of the Mushaf they actually
/// covered that day.
class ReadingProgressStore {
  static const String _boxName = 'reading_progress';

  Future<Box<Map>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<Map>(_boxName);
    }
    return Hive.openBox<Map>(_boxName);
  }

  static String keyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime? _dateFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  /// Record that a Mushaf page was open. Safe to call repeatedly.
  Future<void> recordPage(int page, {DateTime? when}) async {
    if (page < 1 || page > 604) {
      return;
    }

    final date = when ?? DateTime.now();
    try {
      final box = await _openBox();
      final key = keyFor(date);
      final entry = box.get(key);

      final pages = <int>{
        ...?(entry?['pages'] as List?)?.whereType<num>().map(
          (value) => value.toInt(),
        ),
        page,
      };

      await box.put(key, {
        'pages': pages.toList()..sort(),
        'minutes': (entry?['minutes'] as num?)?.toInt() ?? 0,
      });
    } catch (e, stack) {
      AppLogger.error('Failed to record page $page', e, stack);
    }
  }

  /// Add reading time to a day.
  Future<void> addMinutes(int minutes, {DateTime? when}) async {
    if (minutes <= 0) {
      return;
    }

    final date = when ?? DateTime.now();
    try {
      final box = await _openBox();
      final key = keyFor(date);
      final entry = box.get(key);

      await box.put(key, {
        'pages': (entry?['pages'] as List?) ?? const <int>[],
        'minutes': ((entry?['minutes'] as num?)?.toInt() ?? 0) + minutes,
      });
    } catch (e, stack) {
      AppLogger.error('Failed to record reading minutes', e, stack);
    }
  }

  Future<ReadingDay> day(DateTime date) async {
    final box = await _openBox();
    return _read(box, keyFor(date)) ?? ReadingDay.empty(date);
  }

  /// Every recorded day, oldest first.
  Future<List<ReadingDay>> all() async {
    try {
      final box = await _openBox();
      final days = <ReadingDay>[];
      for (final key in box.keys) {
        if (key is! String) {
          continue;
        }
        final entry = _read(box, key);
        if (entry != null && !entry.isEmpty) {
          days.add(entry);
        }
      }
      days.sort((a, b) => a.date.compareTo(b.date));
      return days;
    } catch (e, stack) {
      AppLogger.error('Failed to read the reading log', e, stack);
      return const [];
    }
  }

  /// Days recorded on or after [from], oldest first.
  Future<List<ReadingDay>> since(DateTime from) async {
    final start = DateTime(from.year, from.month, from.day);
    final days = await all();
    return days.where((day) => !day.date.isBefore(start)).toList();
  }

  /// Distinct pages covered since [from] — the khatmah progress.
  Future<int> pagesSince(DateTime from) async {
    final days = await since(from);
    final pages = <int>{};
    for (final day in days) {
      pages.addAll(day.pages);
    }
    return pages.length;
  }

  Future<ReadingTotals> totals() async {
    final days = await all();
    if (days.isEmpty) {
      return ReadingTotals.empty;
    }

    var pages = 0;
    var minutes = 0;
    for (final day in days) {
      pages += day.pageCount;
      minutes += day.minutes;
    }

    return ReadingTotals(
      days: days.length,
      pages: pages,
      minutes: minutes,
      currentStreak: currentStreakOf(days),
      longestStreak: longestStreakOf(days),
    );
  }

  /// Consecutive days ending today (or yesterday, so an unread today does not
  /// wipe a streak before the day is over).
  static int currentStreakOf(List<ReadingDay> days, {DateTime? now}) {
    if (days.isEmpty) {
      return 0;
    }

    final today = _dateOnly(now ?? DateTime.now());
    final recorded = days.map((day) => _dateOnly(day.date)).toSet();

    var cursor = today;
    if (!recorded.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!recorded.contains(cursor)) {
        return 0;
      }
    }

    var streak = 0;
    while (recorded.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int longestStreakOf(List<ReadingDay> days) {
    if (days.isEmpty) {
      return 0;
    }

    final sorted =
        days.map((day) => _dateOnly(day.date)).toSet().toList()..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      run = gap == 1 ? run + 1 : 1;
      if (run > longest) {
        longest = run;
      }
    }
    return longest;
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.clear();
  }

  ReadingDay? _read(Box<Map> box, String key) {
    final raw = box.get(key);
    final date = _dateFromKey(key);
    if (raw == null || date == null) {
      return null;
    }

    final pages =
        (raw['pages'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toSet() ??
        <int>{};

    return ReadingDay(
      date: date,
      pages: pages,
      minutes: (raw['minutes'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
