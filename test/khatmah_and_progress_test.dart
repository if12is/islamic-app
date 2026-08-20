import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/reading_progress_store.dart';
import 'package:islamic_app/features/quran/domain/entities/khatmah_plan.dart';

void main() {
  group('KhatmahPlan', () {
    final start = DateTime(2026, 8, 1);

    test('splits the Mushaf across the chosen days', () {
      const totalPages = KhatmahPlan.totalPages;
      expect(KhatmahPlan(startDate: start, days: 30).pagesPerDay, 21);
      expect(KhatmahPlan(startDate: start, days: 604).pagesPerDay, 1);
      expect(KhatmahPlan(startDate: start, days: 1).pagesPerDay, totalPages);
    });

    test('counts days from one', () {
      final plan = KhatmahPlan(startDate: start, days: 30);
      expect(plan.dayNumber(start), 1);
      expect(plan.dayNumber(DateTime(2026, 8, 10)), 10);
      expect(plan.daysRemaining(DateTime(2026, 8, 10)), 21);
      expect(plan.daysRemaining(DateTime(2026, 9, 20)), 0);
      expect(plan.endDate, DateTime(2026, 8, 30));
    });

    test('spreads what is left over the days that remain', () {
      final plan = KhatmahPlan(startDate: start, days: 30);

      // On day one, nothing read yet: the plain daily portion.
      expect(plan.todayTarget(start, 0), 21);

      // Ten days in with nothing read, the rest is re-spread — bigger, but
      // never the whole remainder until the last day.
      final behind = plan.todayTarget(DateTime(2026, 8, 10), 0);
      expect(behind, greaterThan(21));
      expect(behind, lessThan(KhatmahPlan.totalPages));

      // Ahead of schedule, today asks for less.
      expect(plan.todayTarget(DateTime(2026, 8, 10), 400), lessThan(21));

      // The last day carries everything that is left.
      expect(plan.todayTarget(DateTime(2026, 8, 30), 600), 4);
    });

    test('reports how far ahead or behind the reader is', () {
      final plan = KhatmahPlan(startDate: start, days: 30);
      final tenth = DateTime(2026, 8, 10);

      expect(plan.expectedPages(tenth), 210);
      expect(plan.pagesAhead(tenth, 250), 40);
      expect(plan.pagesAhead(tenth, 100), -110);
    });

    test('progress is clamped to the Mushaf', () {
      final plan = KhatmahPlan(startDate: start, days: 30);
      expect(plan.progress(0), 0);
      expect(plan.progress(302), closeTo(0.5, 0.01));
      expect(plan.progress(700), 1);
    });

    test('survives an encode/decode round trip', () {
      final plan = KhatmahPlan(
        startDate: start,
        days: 45,
        completedAt: DateTime(2026, 9, 1),
      );
      final restored = KhatmahPlan.decode(plan.encode())!;

      expect(restored.days, 45);
      expect(restored.startDate, start);
      expect(restored.isComplete, isTrue);
      expect(KhatmahPlan.decode('not json'), isNull);
      expect(KhatmahPlan.decode(null), isNull);
    });
  });

  group('Reading streaks', () {
    ReadingDay day(int year, int month, int dayOfMonth) => ReadingDay(
      date: DateTime(year, month, dayOfMonth),
      pages: const {1},
      minutes: 5,
    );

    test('counts consecutive days ending today', () {
      final today = DateTime(2026, 8, 20);
      final days = [day(2026, 8, 18), day(2026, 8, 19), day(2026, 8, 20)];

      expect(ReadingProgressStore.currentStreakOf(days, now: today), 3);
    });

    test('keeps the streak alive until today is over', () {
      final today = DateTime(2026, 8, 20);
      final days = [day(2026, 8, 18), day(2026, 8, 19)];

      expect(ReadingProgressStore.currentStreakOf(days, now: today), 2);
    });

    test('breaks after a missed day', () {
      final today = DateTime(2026, 8, 20);
      final days = [day(2026, 8, 15), day(2026, 8, 16)];

      expect(ReadingProgressStore.currentStreakOf(days, now: today), 0);
    });

    test('finds the longest run in the log', () {
      final days = [
        day(2026, 8, 1),
        day(2026, 8, 2),
        day(2026, 8, 3),
        day(2026, 8, 10),
        day(2026, 8, 11),
      ];

      expect(ReadingProgressStore.longestStreakOf(days), 3);
      expect(ReadingProgressStore.longestStreakOf(const []), 0);
    });

    test('keys days without ambiguity', () {
      expect(ReadingProgressStore.keyFor(DateTime(2026, 1, 5)), '2026-01-05');
      expect(ReadingProgressStore.keyFor(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('Bundled azkar dataset', () {
    late Map<String, dynamic> data;

    setUpAll(() {
      data =
          jsonDecode(File('assets/data/azkar.json').readAsStringSync())
              as Map<String, dynamic>;
    });

    test('ships the full Hisn al-Muslim', () {
      final categories = data['categories'] as List;
      expect(categories.length, greaterThanOrEqualTo(130));

      final items = categories.fold<int>(
        0,
        (total, category) =>
            total + ((category as Map)['azkar'] as List).length,
      );
      expect(items, greaterThanOrEqualTo(340));
    });

    test('keeps morning and evening as separate chapters', () {
      final categories = (data['categories'] as List).cast<Map>();
      final ids = categories.map((category) => category['id']).toSet();

      expect(ids, containsAll(<String>['morning', 'evening', 'tasbeeh']));

      final morning = categories.firstWhere(
        (category) => category['id'] == 'morning',
      );
      final evening = categories.firstWhere(
        (category) => category['id'] == 'evening',
      );
      expect((morning['azkar'] as List).length, greaterThan(20));
      expect((evening['azkar'] as List).length, greaterThan(20));
      expect(morning['nameAr'], isNot(evening['nameAr']));
    });

    test('every dhikr has text and a repeat count of at least one', () {
      final categories = (data['categories'] as List).cast<Map>();
      var total = 0;

      for (final category in categories) {
        for (final item in (category['azkar'] as List).cast<Map>()) {
          total++;
          expect((item['textAr'] as String).trim(), isNotEmpty);
          expect(item['count'], isA<int>());
          expect(item['count'] as int, greaterThanOrEqualTo(1));
        }
      }

      expect(total, greaterThanOrEqualTo(340));
    });

    test('the daily chapters carry their references', () {
      // The source records a reference for about a third of the dataset, and
      // for most of the morning and evening azkar — the ones read every day.
      final morning = (data['categories'] as List).cast<Map>().firstWhere(
        (category) => category['id'] == 'morning',
      );
      final items = (morning['azkar'] as List).cast<Map>();
      final withReference =
          items
              .where((item) => (item['reference'] as String? ?? '').isNotEmpty)
              .length;

      expect(withReference / items.length, greaterThan(0.6));
    });
  });
}
