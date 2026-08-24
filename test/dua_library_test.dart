import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/domain/dua_library.dart';
import 'package:islamic_app/features/azkar/domain/ruqyah_passages.dart';

void main() {
  group('Shelving the chapters', () {
    test('every chapter of the book lands on a shelf', () {
      for (var chapter = 1; chapter <= DuaLibrary.chapterCount; chapter++) {
        expect(
          () => DuaLibrary.themeOfChapter(chapter),
          returnsNormally,
          reason: 'chapter $chapter',
        );
      }
    });

    test('no shelf is empty — an empty row is a dead end', () {
      for (final theme in DuaTheme.values) {
        expect(
          DuaLibrary.chaptersOf(theme),
          isNotEmpty,
          reason: '${theme.name} has nothing on it',
        );
      }
    });

    test('the shelves partition the book, with no chapter on two', () {
      final seen = <int>{};
      for (final theme in DuaTheme.values) {
        for (final chapter in DuaLibrary.chaptersOf(theme)) {
          expect(seen.add(chapter), isTrue, reason: 'chapter $chapter twice');
        }
      }
      expect(seen.length, DuaLibrary.chapterCount);
    });
  });

  group('Finding the chapter behind a category id', () {
    test('the numbered ids read straight off', () {
      expect(DuaLibrary.chapterOf('hisn_94'), 94);
      expect(DuaLibrary.chapterOf('hisn_1'), 1);
      expect(DuaLibrary.chapterOf('hisn_136'), 136);
    });

    test('the named ids sit at their real chapter numbers', () {
      // These were given words for ids because other screens link to them, but
      // they are the same chapters in the same positions.
      expect(DuaLibrary.chapterOf('morning'), 1);
      expect(DuaLibrary.chapterOf('adhan'), 16);
      expect(DuaLibrary.chapterOf('sujood'), 20);
      expect(DuaLibrary.chapterOf('sleep'), 28);
      expect(DuaLibrary.chapterOf('tasbeeh'), 136);
    });

    test('something that is not a chapter says so', () {
      expect(DuaLibrary.chapterOf('nonsense'), isNull);
      expect(DuaLibrary.chapterOf('hisn_0'), isNull);
      expect(DuaLibrary.chapterOf('hisn_999'), isNull);
      expect(DuaLibrary.chapterOf('hisn_x'), isNull);
    });

    test('an unknown id still gets a shelf rather than vanishing', () {
      expect(DuaLibrary.themeOf('nonsense'), DuaTheme.remembrance);
    });
  });

  group('The shelving matches the data that ships', () {
    test('every category in azkar.json is placed', () {
      final raw = File('assets/data/azkar.json').readAsStringSync();
      final categories =
          (jsonDecode(raw) as Map<String, dynamic>)['categories'] as List;

      expect(categories.length, DuaLibrary.chapterCount);

      final unplaced = <String>[];
      for (final entry in categories) {
        final id = (entry as Map)['id'] as String;
        if (DuaLibrary.chapterOf(id) == null) {
          unplaced.add(id);
        }
      }

      expect(
        unplaced,
        isEmpty,
        reason:
            'These categories have no chapter number, so they would all pile '
            'onto one shelf: ${unplaced.join(', ')}',
      );
    });

    test('the morning and travel chapters land where a person would look', () {
      expect(DuaLibrary.themeOf('morning'), DuaTheme.day);
      expect(DuaLibrary.themeOf('evening'), DuaTheme.day);
      expect(DuaLibrary.themeOf('sleep'), DuaTheme.day);
      expect(DuaLibrary.themeOf('hisn_95'), DuaTheme.travel);
      expect(DuaLibrary.themeOf('after_prayer'), DuaTheme.prayer);
      expect(DuaLibrary.themeOf('worry'), DuaTheme.distress);
      expect(DuaLibrary.themeOf('hisn_132'), DuaTheme.ruqyah);
      expect(DuaLibrary.themeOf('hisn_133'), DuaTheme.ruqyah);
    });
  });

  group('The ruqyah', () {
    test('the narrated set is exactly what hadith names for it', () {
      // Al-Fatihah, Ayat al-Kursi, the closing verses of al-Baqarah, and the
      // three Muʿawwidhat. Anything else on this list would be a claim the
      // sources do not make.
      final references = [
        for (final passage in RuqyahPassages.narrated)
          '${passage.surahNumber}:${passage.fromVerse}-${passage.toVerse}',
      ];

      expect(references, [
        '1:1-7',
        '2:255-255',
        '2:285-286',
        '112:1-4',
        '113:1-5',
        '114:1-6',
      ]);
    });

    test('every narrated passage says where it comes from', () {
      for (final passage in RuqyahPassages.narrated) {
        expect(
          passage.noteAr,
          isNotEmpty,
          reason: 'surah ${passage.surahNumber} has no source',
        );
        expect(passage.basis, RuqyahBasis.narrated);
      }
    });

    test('the longer set is marked as chosen, never as narrated', () {
      for (final passage in RuqyahPassages.chosen) {
        expect(passage.basis, RuqyahBasis.chosen);
      }
    });

    test('every passage is a real range inside its surah', () {
      for (final passage in RuqyahPassages.all) {
        expect(passage.fromVerse, greaterThanOrEqualTo(1));
        expect(passage.toVerse, greaterThanOrEqualTo(passage.fromVerse));
        expect(passage.verseCount, passage.verses.length);
        for (final verse in passage.verses) {
          expect(verse.text.trim(), isNotEmpty);
        }
      }
    });

    test('the queue is the passages flattened, in order', () {
      final verses = RuqyahPassages.versesOf(RuqyahPassages.narrated);
      expect(
        verses.length,
        RuqyahPassages.verseCountOf(RuqyahPassages.narrated),
      );
      expect(verses.first.surahNumber, 1);
      expect(verses.last.surahNumber, 114);
      expect(verses.last.numberInSurah, 6);
    });
  });
}
