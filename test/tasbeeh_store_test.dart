import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/data/tasbeeh_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The endless counter is the one number in this app someone could spend years
/// building. These tests exist because "it resets sometimes" would make it
/// worthless.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('starts at zero and in rounds mode', () {
    expect(TasbeehStore.total(prefs), 0);
    expect(TasbeehStore.mode(prefs), TasbeehMode.rounds);
  });

  test('counts up and keeps the total', () async {
    for (var i = 0; i < 5; i++) {
      await TasbeehStore.increment(prefs);
    }

    expect(TasbeehStore.total(prefs), 5);

    // A fresh handle onto the same store: what a restart looks like.
    final reopened = await SharedPreferences.getInstance();
    expect(TasbeehStore.total(reopened), 5);
  });

  test('today resets with the date, the lifetime total does not', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    await TasbeehStore.increment(prefs, now: yesterday);
    await TasbeehStore.increment(prefs, now: yesterday);
    expect(TasbeehStore.today(prefs, now: yesterday), 2);

    // A new day.
    expect(TasbeehStore.today(prefs), 0);
    expect(TasbeehStore.total(prefs), 2);

    await TasbeehStore.increment(prefs);
    expect(TasbeehStore.today(prefs), 1);
    expect(TasbeehStore.total(prefs), 3);
  });

  test('changing the phrase does not touch the total', () async {
    await TasbeehStore.increment(prefs);
    await TasbeehStore.increment(prefs);

    await TasbeehStore.setPhraseIndex(prefs, 3);

    expect(TasbeehStore.phraseIndex(prefs), 3);
    expect(TasbeehStore.total(prefs), 2);
  });

  test('the mode is remembered', () async {
    await TasbeehStore.setMode(prefs, TasbeehMode.endless);
    expect(TasbeehStore.mode(prefs), TasbeehMode.endless);

    final reopened = await SharedPreferences.getInstance();
    expect(TasbeehStore.mode(reopened), TasbeehMode.endless);
  });

  test('only an explicit clear empties it', () async {
    for (var i = 0; i < 120; i++) {
      await TasbeehStore.increment(prefs);
    }
    expect(TasbeehStore.total(prefs), 120);

    await TasbeehStore.clearTotal(prefs);

    expect(TasbeehStore.total(prefs), 0);
    expect(TasbeehStore.today(prefs), 0);
    // The chosen phrase survives a clear; it is not part of the count.
    expect(TasbeehStore.phraseIndex(prefs), 0);
  });
}
