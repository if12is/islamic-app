import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/surah_virtues.dart';

void main() {
  group('Every entry', () {
    test('names a real surah and a source', () {
      for (final virtue in SurahVirtues.all) {
        expect(virtue.surahNumber, inInclusiveRange(1, 114), reason: virtue.id);
        expect(virtue.nameAr, isNotEmpty, reason: virtue.id);
        expect(virtue.virtueAr, isNotEmpty, reason: virtue.id);
        expect(
          virtue.sourceAr,
          isNotEmpty,
          reason: 'a virtue without a source is a rumour: ${virtue.id}',
        );
      }
    });

    test('has a unique id', () {
      final ids = SurahVirtues.all.map((virtue) => virtue.id).toSet();
      expect(ids.length, SurahVirtues.all.length);
    });

    test('states a partial reading as a real range', () {
      for (final virtue in SurahVirtues.all.where((v) => v.isPartial)) {
        expect(virtue.toAyah, isNotNull, reason: virtue.id);
        expect(virtue.toAyah! >= virtue.fromAyah!, isTrue, reason: virtue.id);
      }
    });
  });

  group('Grading', () {
    // The point of the grade is to keep the popular from being served as the
    // established. If nothing is ever graded weak, the field is decorative.
    test('separates the established from the merely popular', () {
      expect(SurahVirtues.established, isNotEmpty);
      expect(
        SurahVirtues.all.any((v) => v.grade == NarrationGrade.weak),
        isTrue,
        reason: 'al-Waqiah and Yaseen are widely read on weak narrations',
      );
      expect(
        SurahVirtues.established.every((v) => v.grade != NarrationGrade.weak),
        isTrue,
      );
    });

    test('al-Waqiah is not presented as established', () {
      expect(SurahVirtues.byId('waqiah')!.isEstablished, isFalse);
    });

    test('the two Sahihs outrank everything else', () {
      expect(SurahVirtues.byId('baqarah_end')!.grade, NarrationGrade.agreed);
      expect(SurahVirtues.byId('baqarah_end')!.isEstablished, isTrue);
    });

    test('every grade has a word for it, in Arabic', () {
      for (final grade in NarrationGrade.values) {
        final sample = SurahVirtue(
          id: 'x',
          surahNumber: 1,
          nameAr: 'الفاتحة',
          time: ReadingTime.morning,
          virtueAr: 'نص',
          sourceAr: 'مصدر',
          grade: grade,
        );
        expect(sample.gradeAr, isNotEmpty, reason: grade.name);
      }
    });

    test('the grade travels with the text wherever it is quoted', () {
      // The whole point: a weak narration shown bare reads as a sound one.
      final waqiah = SurahVirtues.byId('waqiah')!;
      expect(waqiah.virtueWithGradeAr, contains('ضعيف'));
      expect(waqiah.virtueWithGradeAr, contains(waqiah.sourceAr));

      final kahf = SurahVirtues.byId('kahf')!;
      expect(kahf.virtueWithGradeAr, contains('صحيح'));
    });
  });

  group("The day's suggestion", () {
    test('is always al-Kahf on Friday', () {
      // 2026-08-21 is a Friday.
      final friday = DateTime(2026, 8, 21);
      expect(friday.weekday, DateTime.friday);
      expect(SurahVirtues.suggestionFor(friday).id, 'kahf');
    });

    test('never suggests something on a weak narration', () {
      for (var day = 0; day < 400; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        expect(
          SurahVirtues.suggestionFor(date).isEstablished,
          isTrue,
          reason: 'on $date',
        );
      }
    });

    test('rotates rather than repeating the same surah', () {
      final seen = <String>{};
      for (var day = 0; day < 14; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        seen.add(SurahVirtues.suggestionFor(date).id);
      }
      expect(seen.length, greaterThan(3));
    });
  });
}
