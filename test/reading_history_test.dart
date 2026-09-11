import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/reading_history_store.dart';
import 'package:islamic_app/features/quran/presentation/providers/bookmarks_provider.dart';
import 'package:islamic_app/features/quran/presentation/providers/reading_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final monday = DateTime(2026, 9, 7, 20);

  (List<ReadingMark>, String) record(
    List<ReadingMark> marks, {
    String? session,
    required int surah,
    required int verse,
    required int page,
    DateTime? at,
  }) => ReadingHistoryStore.record(
    marks,
    sessionId: session,
    surah: surah,
    verse: verse,
    page: page,
    now: at ?? monday,
  );

  group('The reading history', () {
    test('a looked-up verse does not move the khatmah', () {
      // The reported case: ten pages into al-Baqarah, a search for a verse to
      // read its tafsir, and the khatmah position was gone.
      var (marks, khatmah) = record(const [], surah: 2, verse: 1, page: 2);
      (marks, _) = record(
        marks,
        session: khatmah,
        surah: 2,
        verse: 75,
        page: 11,
      );

      // A new session opened from a search, one page further on.
      final (after, lookup) = record(marks, surah: 2, verse: 80, page: 12);

      expect(lookup, isNot(khatmah));
      expect(after, hasLength(2));
      final kept = after.firstWhere((mark) => mark.id == khatmah);
      expect(kept.verse, 75, reason: 'the khatmah is still where it stopped');
      expect(after.first.id, lookup, reason: 'newest first');
    });

    test('continuing a line moves it forward instead of adding a new one', () {
      var (marks, id) = record(const [], surah: 2, verse: 1, page: 2);
      (marks, id) = record(marks, session: id, surah: 2, verse: 75, page: 11);

      // The next day, "continue" opens the reader with that line's id.
      final (next, same) = record(
        marks,
        session: id,
        surah: 2,
        verse: 100,
        page: 15,
        at: monday.add(const Duration(days: 1)),
      );

      expect(same, id);
      expect(next, hasLength(1));
      expect(next.single.startPage, 2);
      expect(next.single.page, 15);
    });

    test('a new session on the very page a line stopped at picks it up', () {
      var (marks, id) = record(const [], surah: 18, verse: 10, page: 294);
      final (next, same) = record(marks, surah: 18, verse: 11, page: 294);

      expect(same, id);
      expect(next, hasLength(1));
    });

    test('two lines that meet on one page become one, keeping the pin', () {
      var (marks, wird) = record(const [], surah: 3, verse: 1, page: 50);
      marks = ReadingHistoryStore.pin(marks, wird, pinned: true);
      var (withLookup, lookup) = record(marks, surah: 3, verse: 40, page: 55);
      (withLookup, lookup) = record(
        withLookup,
        session: lookup,
        surah: 3,
        verse: 30,
        page: 50,
      );

      expect(withLookup, hasLength(1));
      expect(withLookup.single.pinned, isTrue);
    });

    test('only one line is the wird', () {
      var (marks, first) = record(const [], surah: 1, verse: 1, page: 1);
      final (both, second) = record(marks, surah: 2, verse: 1, page: 2);
      marks = ReadingHistoryStore.pin(both, first, pinned: true);
      marks = ReadingHistoryStore.pin(marks, second, pinned: true);

      expect(marks.where((mark) => mark.pinned).map((mark) => mark.id), [
        second,
      ]);
    });

    test('old lines fall off the end, but never the pinned one', () {
      var (marks, wird) = record(const [], surah: 2, verse: 1, page: 2);
      marks = ReadingHistoryStore.pin(marks, wird, pinned: true);
      for (var page = 100; page < 100 + ReadingHistoryStore.limit + 5; page++) {
        (marks, _) = record(
          marks,
          surah: 10,
          verse: 1,
          page: page,
          at: monday.add(Duration(minutes: page)),
        );
      }

      expect(marks.where((mark) => !mark.pinned), hasLength(20));
      expect(marks.any((mark) => mark.id == wird), isTrue);
    });

    test('survives being written and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var (marks, id) = record(const [], surah: 36, verse: 12, page: 441);
      marks = ReadingHistoryStore.pin(marks, id, pinned: true);
      await ReadingHistoryStore.write(prefs, marks);

      final back = ReadingHistoryStore.read(prefs);
      expect(back.single.surah, 36);
      expect(back.single.verse, 12);
      expect(back.single.pinned, isTrue);
    });

    test('a corrupt or out-of-range entry is dropped, not trusted', () async {
      SharedPreferences.setMockInitialValues({
        ReadingHistoryStore.key:
            '[{"id":"a","s":2,"v":5,"p":3},{"id":"b","s":999,"v":1,"p":1}]',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(ReadingHistoryStore.read(prefs).map((mark) => mark.id), ['a']);
    });
  });

  group('Where "continue" and the wird open', () {
    test('the wird resumes the pinned line, not the last verse looked up', () {
      var (marks, wird) = record(const [], surah: 2, verse: 75, page: 11);
      marks = ReadingHistoryStore.pin(marks, wird, pinned: true);
      (marks, _) = record(marks, surah: 3, verse: 190, page: 75);
      const last = LastReadPosition(surahNumber: 3, verseNumber: 190);

      final resume = resumeForWird(last, marks)!;
      expect(resume.surah, 2);
      expect(resume.verse, 75);
      expect(resume.historyId, wird);

      final lastRead = resumeForLastRead(last, marks)!;
      expect(lastRead.surah, 3);
      expect(lastRead.historyId, isNotNull);
    });

    test('with nothing pinned, the wird is the last place read', () {
      final (marks, id) = record(const [], surah: 67, verse: 5, page: 562);
      const last = LastReadPosition(surahNumber: 67, verseNumber: 5);

      final resume = resumeForWird(last, marks)!;
      expect(resume.surah, 67);
      expect(resume.historyId, id);
    });
  });
}
