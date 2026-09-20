import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/bookmark_store.dart';
import '../../data/services/quran_local_service.dart';

final bookmarkStoreProvider = Provider<BookmarkStore>((ref) => BookmarkStore());

/// Where the reader left off: surah, verse, and scroll offset.
class LastReadPosition {
  const LastReadPosition({
    required this.surahNumber,
    required this.verseNumber,
    this.scrollOffset = 0,
  });

  final int surahNumber;
  final int verseNumber;
  final double scrollOffset;
}

/// Every saved verse, newest first.
class BookmarksNotifier extends AsyncNotifier<List<QuranBookmark>> {
  BookmarkStore get _store => ref.read(bookmarkStoreProvider);

  @override
  Future<List<QuranBookmark>> build() => _store.all();

  Future<void> refresh() async {
    state = AsyncData(await _store.all());
  }

  /// Save a verse, or update its tag/note if it is already saved.
  Future<void> save({
    required QuranVerse verse,
    BookmarkTag tag = BookmarkTag.favorite,
    String note = '',
  }) async {
    // Keyed in Hafs, shown in whatever reading is open.
    //
    // A bookmark saved while reading Warsh and keyed by the Warsh number would
    // point at a different ayah the moment the reader switched to Hafs — and
    // at every ayah after it too, since the readings drift apart within a
    // surah rather than by a constant.
    final existing = await _store.find(
      verse.surahNumber,
      verse.hafsVerseNumber,
    );
    final bookmark = QuranBookmark(
      surahNumber: verse.surahNumber,
      verseNumber: verse.hafsVerseNumber,
      surahName: verse.surahNameAr,
      createdAt: existing?.createdAt ?? DateTime.now(),
      tag: tag,
      note: note,
      preview: _preview(verse.text),
    );

    await _store.save(bookmark);
    await refresh();
  }

  Future<void> remove(int surahNumber, int verseNumber) async {
    await _store.remove(surahNumber, verseNumber);
    await refresh();
  }

  /// Toggle a plain bookmark on a verse.
  ///
  /// By its Hafs address, like [save]. Addressed by the number on the page, a
  /// toggle in Warsh would fail to find the bookmark it had just written and
  /// save a second one beside it.
  Future<bool> toggle(QuranVerse verse) async {
    final existing = await _store.find(
      verse.surahNumber,
      verse.hafsVerseNumber,
    );
    if (existing != null) {
      await remove(verse.surahNumber, verse.hafsVerseNumber);
      return false;
    }
    await save(verse: verse);
    return true;
  }

  /// Whether a **Hafs**-addressed verse is bookmarked.
  bool contains(int surahNumber, int verseNumber) {
    final items = state.value;
    if (items == null) {
      return false;
    }
    return items.any(
      (bookmark) =>
          bookmark.surahNumber == surahNumber &&
          bookmark.verseNumber == verseNumber,
    );
  }

  static String _preview(String text) {
    final words = text.split(' ');
    if (words.length <= 8) {
      return text;
    }
    return '${words.take(8).join(' ')}…';
  }
}

final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, List<QuranBookmark>>(
      BookmarksNotifier.new,
    );

/// The automatic "continue reading" position, kept in the same preference keys
/// the Quran index screen already reads.
class LastReadNotifier extends Notifier<LastReadPosition?> {
  static const String _surahKey = 'last_read_surah_id';
  static const String _verseKey = 'last_read_verse_num';
  static const String _offsetKey = 'last_read_scroll_offset';
  static const String _nameKey = 'last_read_surah_nameAr';

  @override
  LastReadPosition? build() {
    final surah = appPreferences.getInt(_surahKey);
    if (surah == null) {
      return null;
    }
    return LastReadPosition(
      surahNumber: surah,
      verseNumber: appPreferences.getInt(_verseKey) ?? 1,
      scrollOffset: appPreferences.getDouble(_offsetKey) ?? 0,
    );
  }

  Future<void> update({
    required int surahNumber,
    required int verseNumber,
    double scrollOffset = 0,
  }) async {
    state = LastReadPosition(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
      scrollOffset: scrollOffset,
    );

    await appPreferences.setInt(_surahKey, surahNumber);
    await appPreferences.setInt(_verseKey, verseNumber);
    await appPreferences.setDouble(_offsetKey, scrollOffset);
    await appPreferences.setString(
      _nameKey,
      QuranLocalService.surahInfo(surahNumber).nameAr,
    );
  }
}

final lastReadProvider = NotifierProvider<LastReadNotifier, LastReadPosition?>(
  LastReadNotifier.new,
);
