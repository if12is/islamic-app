import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../data/reading_history_store.dart';
import 'bookmarks_provider.dart';

/// Every place the reader has read from, newest first, with the pinned wird
/// kept whatever its age.
class ReadingHistoryNotifier extends Notifier<List<ReadingMark>> {
  @override
  List<ReadingMark> build() => ReadingHistoryStore.read(appPreferences);

  /// Called by the reader as it saves its position. Returns the id the
  /// session should pass next time, so one sitting stays one line.
  ///
  /// The list changes synchronously and the disk catches up after: two saves
  /// arriving together — the scroll debounce and the app going to the
  /// background — must see each other's id, or one sitting becomes two lines.
  String record({
    required String? sessionId,
    required int surah,
    required int verse,
    required int page,
  }) {
    final (next, id) = ReadingHistoryStore.record(
      state,
      sessionId: sessionId,
      surah: surah,
      verse: verse,
      page: page,
      now: DateTime.now(),
    );
    state = next;
    unawaited(ReadingHistoryStore.write(appPreferences, next));
    return id;
  }

  Future<void> setPinned(String id, {required bool pinned}) async {
    state = ReadingHistoryStore.pin(state, id, pinned: pinned);
    await ReadingHistoryStore.write(appPreferences, state);
  }

  Future<void> remove(String id) async {
    state = ReadingHistoryStore.remove(state, id);
    await ReadingHistoryStore.write(appPreferences, state);
  }
}

final readingHistoryProvider =
    NotifierProvider<ReadingHistoryNotifier, List<ReadingMark>>(
      ReadingHistoryNotifier.new,
    );

/// Where "continue" should open, and which history line it continues.
class ReadingResume {
  const ReadingResume({
    required this.surah,
    required this.verse,
    this.historyId,
  });

  final int surah;
  final int verse;
  final String? historyId;
}

/// Where the daily wird's Quran line should open: the pinned wird if there is
/// one, otherwise the last place read.
ReadingResume? resumeForWird(LastReadPosition? last, List<ReadingMark> marks) {
  final pinned = ReadingHistoryStore.pinnedOf(marks);
  if (pinned != null) {
    return ReadingResume(
      surah: pinned.surah,
      verse: pinned.verse,
      historyId: pinned.id,
    );
  }
  return resumeForLastRead(last, marks);
}

/// The last place read, tied to its history line when the two agree — so
/// "continue" moves that line forward rather than starting a twin of it.
ReadingResume? resumeForLastRead(
  LastReadPosition? last,
  List<ReadingMark> marks,
) {
  if (last == null) {
    return null;
  }
  final newest = marks.isEmpty ? null : marks.first;
  final matches =
      newest != null &&
      newest.surah == last.surahNumber &&
      newest.verse == last.verseNumber;
  return ReadingResume(
    surah: last.surahNumber,
    verse: last.verseNumber,
    historyId: matches ? newest.id : null,
  );
}
