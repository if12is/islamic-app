import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One place the reader has been reading from, and how far it got.
///
/// A mark is a thread, not a snapshot: a khatmah read ten pages a day stays
/// one mark that moves forward every day, rather than becoming a new line in
/// the list each morning.
class ReadingMark {
  const ReadingMark({
    required this.id,
    required this.surah,
    required this.verse,
    required this.page,
    required this.startPage,
    required this.startedAt,
    required this.updatedAt,
    this.pinned = false,
  });

  final String id;

  /// Where the thread has got to.
  final int surah;
  final int verse;
  final int page;

  /// Where it began, so a list of marks can say "pages 2 to 11".
  final int startPage;

  final DateTime startedAt;
  final DateTime updatedAt;

  /// The reader's own wird: kept at the top and never pushed out of the list.
  final bool pinned;

  ReadingMark copyWith({
    int? surah,
    int? verse,
    int? page,
    int? startPage,
    DateTime? updatedAt,
    bool? pinned,
  }) {
    return ReadingMark(
      id: id,
      surah: surah ?? this.surah,
      verse: verse ?? this.verse,
      page: page ?? this.page,
      startPage: startPage ?? this.startPage,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    's': surah,
    'v': verse,
    'p': page,
    'sp': startPage,
    'at': startedAt.millisecondsSinceEpoch,
    'up': updatedAt.millisecondsSinceEpoch,
    if (pinned) 'pin': true,
  };

  static ReadingMark? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final surah = (raw['s'] as num?)?.toInt();
    final verse = (raw['v'] as num?)?.toInt();
    final page = (raw['p'] as num?)?.toInt();
    final id = raw['id']?.toString();
    if (id == null ||
        surah == null ||
        verse == null ||
        page == null ||
        surah < 1 ||
        surah > 114 ||
        verse < 1 ||
        page < 1 ||
        page > 604) {
      return null;
    }
    DateTime time(Object? value) => DateTime.fromMillisecondsSinceEpoch(
      (value as num?)?.toInt() ?? 0,
    );
    return ReadingMark(
      id: id,
      surah: surah,
      verse: verse,
      page: page,
      startPage: ((raw['sp'] as num?)?.toInt() ?? page).clamp(1, 604),
      startedAt: time(raw['at']),
      updatedAt: time(raw['up']),
      pinned: raw['pin'] == true,
    );
  }
}

/// Every place the reader has read from, newest first.
///
/// The single "last read" position answers one question — where was I a
/// moment ago — and it answers it by forgetting everything before. Someone
/// ten pages into a khatmah who opens a verse from a search to read its
/// tafsir comes back to find their khatmah position gone, replaced by the
/// verse they looked up. That is the right answer to "where was I a moment
/// ago", and the wrong one to "where is my wird". This keeps both.
///
/// Pure where it can be: [record] and [pin] take a list and return a list, so
/// the rules are tested without a device.
class ReadingHistoryStore {
  ReadingHistoryStore._();

  static const String key = 'reading_history_v1';

  /// Unpinned marks kept. Pinned ones are kept regardless.
  static const int limit = 20;

  static List<ReadingMark> read(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(ReadingMark.fromJson)
          .whereType<ReadingMark>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(
    SharedPreferences prefs,
    List<ReadingMark> marks,
  ) => prefs.setString(
    key,
    jsonEncode([for (final mark in marks) mark.toJson()]),
  );

  /// Move a reading session's mark to where it now is.
  ///
  /// [sessionId] is the mark this reader session continues: the one it was
  /// opened from ("continue", a line in the history), or the one its first
  /// save created. With none, a first save on the very page an old mark
  /// stopped at picks that thread up again rather than starting a twin of it.
  /// Anywhere else is a new thread — opening a searched verse one page past
  /// the khatmah must not drag the khatmah forward with it.
  ///
  /// Returns the new list and the id the session should hold on to.
  static (List<ReadingMark>, String) record(
    List<ReadingMark> marks, {
    required String? sessionId,
    required int surah,
    required int verse,
    required int page,
    required DateTime now,
  }) {
    final list = List<ReadingMark>.of(marks);

    var index =
        sessionId == null ? -1 : list.indexWhere((m) => m.id == sessionId);
    if (index < 0 && sessionId == null) {
      // The pinned thread first, if it is the one on this page.
      index = list.indexWhere((mark) => mark.page == page && mark.pinned);
      if (index < 0) {
        index = list.indexWhere((mark) => mark.page == page);
      }
    }

    ReadingMark current;
    if (index >= 0) {
      final previous = list.removeAt(index);
      current = previous.copyWith(
        surah: surah,
        verse: verse,
        page: page,
        // Read backwards past where it began, and it begins there instead.
        startPage: page < previous.startPage ? page : previous.startPage,
        updatedAt: now,
      );
    } else {
      current = ReadingMark(
        id: sessionId ?? _freshId(marks, now),
        surah: surah,
        verse: verse,
        page: page,
        startPage: page,
        startedAt: now,
        updatedAt: now,
      );
    }

    // A thread that walks onto another's page has become the same place. Keep
    // one, and keep the pin if either had it.
    final overlapping = list.where((mark) => mark.page == page).toList();
    if (overlapping.isNotEmpty) {
      list.removeWhere((mark) => mark.page == page);
      final earliestStart = overlapping
          .map((mark) => mark.startPage)
          .fold(current.startPage, (a, b) => a < b ? a : b);
      current = current.copyWith(
        pinned: current.pinned || overlapping.any((mark) => mark.pinned),
        startPage: earliestStart,
      );
    }

    return (_trim([current, ...list]), current.id);
  }

  /// Pin or unpin a mark. Only one mark is the wird at a time.
  static List<ReadingMark> pin(
    List<ReadingMark> marks,
    String id, {
    required bool pinned,
  }) {
    return [
      for (final mark in marks)
        if (mark.id == id)
          mark.copyWith(pinned: pinned)
        else if (pinned && mark.pinned)
          mark.copyWith(pinned: false)
        else
          mark,
    ];
  }

  static List<ReadingMark> remove(List<ReadingMark> marks, String id) =>
      marks.where((mark) => mark.id != id).toList();

  /// The time, nudged until no other line has it.
  static String _freshId(List<ReadingMark> marks, DateTime now) {
    final taken = {for (final mark in marks) mark.id};
    var stamp = now.microsecondsSinceEpoch;
    while (taken.contains('$stamp')) {
      stamp++;
    }
    return '$stamp';
  }

  /// Newest first, with everything past [limit] dropped — except a pin.
  static List<ReadingMark> _trim(List<ReadingMark> newestFirst) {
    var unpinned = 0;
    return [
      for (final mark in newestFirst)
        if (mark.pinned || unpinned++ < limit) mark,
    ];
  }

  /// The pinned mark, the one the wird resumes from.
  static ReadingMark? pinnedOf(List<ReadingMark> marks) {
    for (final mark in marks) {
      if (mark.pinned) {
        return mark;
      }
    }
    return null;
  }
}
