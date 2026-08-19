import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/app_logger.dart';

/// Why a verse was saved. Tags drive both the colour and the filters on the
/// bookmarks screen.
enum BookmarkTag { favorite, memorize, reflect, review }

/// A saved verse, optionally with the reader's own note.
class QuranBookmark {
  const QuranBookmark({
    required this.surahNumber,
    required this.verseNumber,
    required this.surahName,
    required this.createdAt,
    this.tag = BookmarkTag.favorite,
    this.note = '',
    this.preview = '',
  });

  final int surahNumber;
  final int verseNumber;
  final String surahName;
  final DateTime createdAt;
  final BookmarkTag tag;
  final String note;

  /// First words of the verse, so the list is readable without loading text.
  final String preview;

  String get key => '$surahNumber:$verseNumber';

  QuranBookmark copyWith({BookmarkTag? tag, String? note}) {
    return QuranBookmark(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      surahName: surahName,
      createdAt: createdAt,
      tag: tag ?? this.tag,
      note: note ?? this.note,
      preview: preview,
    );
  }

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'verseNumber': verseNumber,
    'surahName': surahName,
    'createdAt': createdAt.toIso8601String(),
    'tag': tag.name,
    'note': note,
    'preview': preview,
  };

  factory QuranBookmark.fromJson(Map<dynamic, dynamic> json) {
    return QuranBookmark(
      surahNumber: (json['surahNumber'] as num?)?.toInt() ?? 1,
      verseNumber: (json['verseNumber'] as num?)?.toInt() ?? 1,
      surahName: json['surahName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      tag: BookmarkTag.values.firstWhere(
        (tag) => tag.name == json['tag'],
        orElse: () => BookmarkTag.favorite,
      ),
      note: json['note'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
    );
  }
}

/// Persistent store for saved verses and notes.
///
/// Replaces the single `last_read_verse_num` preference: a reader can now keep
/// as many marks as they like, each with its own tag and note, and tapping a
/// verse no longer overwrites the one saved before it.
class BookmarkStore {
  static const String _boxName = 'quran_bookmarks';

  Future<Box<Map>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<Map>(_boxName);
    }
    return Hive.openBox<Map>(_boxName);
  }

  Future<List<QuranBookmark>> all() async {
    try {
      final box = await _openBox();
      final items =
          box.values
              .map((raw) => QuranBookmark.fromJson(Map<dynamic, dynamic>.from(raw)))
              .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e, stack) {
      AppLogger.error('Failed to read bookmarks', e, stack);
      return const [];
    }
  }

  Future<QuranBookmark?> find(int surahNumber, int verseNumber) async {
    final box = await _openBox();
    final raw = box.get('$surahNumber:$verseNumber');
    if (raw == null) {
      return null;
    }
    return QuranBookmark.fromJson(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> save(QuranBookmark bookmark) async {
    final box = await _openBox();
    await box.put(bookmark.key, bookmark.toJson());
  }

  Future<void> remove(int surahNumber, int verseNumber) async {
    final box = await _openBox();
    await box.delete('$surahNumber:$verseNumber');
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.clear();
  }
}
