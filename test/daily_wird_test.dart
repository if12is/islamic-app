import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/data/azkar_progress_store.dart';
import 'package:islamic_app/features/home/presentation/providers/daily_wird_provider.dart';

void main() {
  group('A portion that is not due yet', () {
    // The bug: after noon the morning azkar were reported as done: totalCount,
    // so the card read 31/31 while the chapter itself held two or three ticks.
    test('is not counted as finished', () {
      const task = WirdTask(
        id: 'morning',
        titleKey: 'wird_morning_azkar',
        done: 3,
        target: 31,
        dueNow: false,
      );

      expect(task.isComplete, isFalse);
      expect(task.done, 3, reason: 'the real count, not the target');
    });

    test('is left out of the day ring rather than counted against it', () {
      const wird = DailyWird(
        tasks: [
          WirdTask(id: 'quran', titleKey: 'q', done: 4, target: 4),
          WirdTask(
            id: 'morning',
            titleKey: 'm',
            done: 31,
            target: 31,
            dueNow: true,
          ),
          WirdTask(
            id: 'evening',
            titleKey: 'e',
            done: 0,
            target: 30,
            dueNow: false,
          ),
        ],
      );

      expect(wird.total, 2, reason: 'the evening portion is not due');
      expect(wird.completed, 2);
      expect(wird.isComplete, isTrue);
      expect(wird.progress, 1.0);
    });

    test('a half-done due portion still shows as unfinished', () {
      const wird = DailyWird(
        tasks: [
          WirdTask(id: 'quran', titleKey: 'q', done: 1, target: 4),
          WirdTask(
            id: 'morning',
            titleKey: 'm',
            done: 3,
            target: 31,
            dueNow: true,
          ),
        ],
      );

      expect(wird.isComplete, isFalse);
      expect(wird.progress, lessThan(0.3));
    });
  });

  group('Azkar sessions', () {
    test('Dhuhr does not start a new session', () {
      expect(
        AzkarProgressStore.sessionKey(DateTime(2026, 8, 22, 7, 30)),
        AzkarProgressStore.sessionKey(DateTime(2026, 8, 22, 13, 0)),
      );
    });

    test('a new day starts a new session', () {
      expect(
        AzkarProgressStore.sessionKey(DateTime(2026, 8, 22, 7, 30)),
        isNot(AzkarProgressStore.sessionKey(DateTime(2026, 8, 23, 7, 30))),
      );
    });

    test('the same calendar day is one session', () {
      expect(
        AzkarProgressStore.sessionKey(DateTime(2026, 8, 22, 6, 0)),
        AzkarProgressStore.sessionKey(DateTime(2026, 8, 22, 23, 59)),
      );
    });

    test('an old AM or PM key still counts as today', () {
      final noon = DateTime(2026, 8, 22, 13, 5);
      expect(AzkarProgressStore.sameSession('2026-8-22_AM', noon), isTrue);
      expect(AzkarProgressStore.sameSession('2026-8-22_PM', noon), isTrue);
      expect(AzkarProgressStore.sameSession('2026-8-22', noon), isTrue);
      expect(AzkarProgressStore.sameSession('2026-8-21_AM', noon), isFalse);
    });
  });
}
