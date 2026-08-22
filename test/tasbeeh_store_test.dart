import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/data/tasbeeh_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Endless counting', () {
    test('starts at zero and in rounds mode', () {
      expect(TasbeehStore.mode(prefs), TasbeehMode.rounds);
      expect(TasbeehStore.total(prefs), 0);
      expect(TasbeehStore.totalFor(prefs, 0), 0);
    });

    test('each phrase keeps its own total', () async {
      for (var i = 0; i < 5; i++) {
        await TasbeehStore.increment(prefs, phraseIndex: 0);
      }
      for (var i = 0; i < 3; i++) {
        await TasbeehStore.increment(prefs, phraseIndex: 1);
      }

      expect(TasbeehStore.totalFor(prefs, 0), 5);
      expect(TasbeehStore.totalFor(prefs, 1), 3);
      expect(TasbeehStore.totalFor(prefs, 2), 0);
    });

    test('the grand total is every phrase added together', () async {
      await TasbeehStore.increment(prefs, phraseIndex: 0);
      await TasbeehStore.increment(prefs, phraseIndex: 3);
      await TasbeehStore.increment(prefs, phraseIndex: 3);

      expect(TasbeehStore.total(prefs), 3);
    });

    test('it never resets itself, however many days pass', () async {
      await TasbeehStore.increment(
        prefs,
        phraseIndex: 0,
        now: DateTime(2026, 1, 1),
      );
      expect(
        TasbeehStore.totalFor(prefs, 0),
        1,
        reason: 'a year later it is still there',
      );
      expect(TasbeehStore.today(prefs, now: DateTime(2027, 1, 1)), 0);
    });

    test('clearing one phrase leaves the others alone', () async {
      await TasbeehStore.increment(prefs, phraseIndex: 0);
      await TasbeehStore.increment(prefs, phraseIndex: 1);

      await TasbeehStore.clearTotal(prefs, phraseIndex: 0);

      expect(TasbeehStore.totalFor(prefs, 0), 0);
      expect(TasbeehStore.totalFor(prefs, 1), 1);
      expect(TasbeehStore.total(prefs), 1);
    });
  });

  group('Rounds', () {
    // The bug: the round lived only in widget state, so stepping to the next
    // phrase and back lost it, and the daily wird never saw it at all.
    test('survive stepping between phrases', () async {
      for (var i = 0; i < 10; i++) {
        await TasbeehStore.incrementRound(prefs, 0);
      }
      await TasbeehStore.incrementRound(prefs, 1);

      expect(TasbeehStore.roundCount(prefs, 0), 10);
      expect(TasbeehStore.roundCount(prefs, 1), 1);
    });

    test('stop at thirty-three however many times it is tapped', () async {
      for (var i = 0; i < 50; i++) {
        await TasbeehStore.incrementRound(prefs, 0);
      }
      expect(TasbeehStore.roundCount(prefs, 0), TasbeehStore.roundTarget);
    });

    test('a new day starts them over', () async {
      final today = DateTime(2026, 8, 22, 10);
      final tomorrow = DateTime(2026, 8, 23, 10);

      for (var i = 0; i < 33; i++) {
        await TasbeehStore.incrementRound(prefs, 0, now: today);
      }
      expect(TasbeehStore.roundCount(prefs, 0, now: today), 33);
      expect(TasbeehStore.roundCount(prefs, 0, now: tomorrow), 0);

      await TasbeehStore.incrementRound(prefs, 0, now: tomorrow);
      expect(TasbeehStore.roundCount(prefs, 0, now: tomorrow), 1);
    });

    test('completed rounds are what the daily wird counts', () async {
      for (var i = 0; i < 33; i++) {
        await TasbeehStore.incrementRound(prefs, 0);
        await TasbeehStore.incrementRound(prefs, 1);
      }
      await TasbeehStore.incrementRound(prefs, 2);

      expect(TasbeehStore.roundsCompleted(prefs, 6), 2);
    });

    test('a manual reset clears one phrase only', () async {
      await TasbeehStore.incrementRound(prefs, 0);
      await TasbeehStore.incrementRound(prefs, 1);

      await TasbeehStore.resetRounds(prefs, phraseIndex: 0);

      expect(TasbeehStore.roundCount(prefs, 0), 0);
      expect(TasbeehStore.roundCount(prefs, 1), 1);
    });
  });

  group('Settings', () {
    test('the mode is remembered', () async {
      await TasbeehStore.setMode(prefs, TasbeehMode.endless);
      expect(TasbeehStore.mode(prefs), TasbeehMode.endless);
    });

    test('the phrase is remembered', () async {
      await TasbeehStore.setPhraseIndex(prefs, 4);
      expect(TasbeehStore.phraseIndex(prefs), 4);
    });
  });
}
