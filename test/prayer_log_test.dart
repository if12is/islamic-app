import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/prayer_times/data/prayer_log_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  final today = DateTime(2026, 8, 24);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Recording a prayer', () {
    test('a fresh day has nothing recorded', () {
      final day = PrayerLogStore.read(prefs, today);
      expect(day.prayed, 0);
      expect(day.recordFor('fajr'), PrayerRecord.none);
    });

    test('what is set is what comes back', () async {
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.mosque);
      await PrayerLogStore.set(prefs, today, 'asr', PrayerRecord.alone);

      final day = PrayerLogStore.read(prefs, today);
      expect(day.recordFor('fajr'), PrayerRecord.mosque);
      expect(day.recordFor('asr'), PrayerRecord.alone);
      expect(day.recordFor('isha'), PrayerRecord.none);
      expect(day.prayed, 2);
    });

    test('clearing one leaves the others', () async {
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.mosque);
      await PrayerLogStore.set(prefs, today, 'asr', PrayerRecord.alone);
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.none);

      final day = PrayerLogStore.read(prefs, today);
      expect(day.recordFor('fajr'), PrayerRecord.none);
      expect(day.recordFor('asr'), PrayerRecord.alone);
    });

    test('days do not bleed into each other', () async {
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.mosque);
      final yesterday = today.subtract(const Duration(days: 1));

      expect(PrayerLogStore.read(prefs, yesterday).prayed, 0);
    });
  });

  group('A made-up prayer', () {
    // It is still a prayer. Scoring it as a failure would be both wrong and
    // discouraging, so it counts as prayed but not as on time.
    test('counts as prayed but not as on time', () async {
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.missed);
      final day = PrayerLogStore.read(prefs, today);

      expect(day.prayed, 1);
      expect(day.onTime, 0);
      expect(day.isComplete, isFalse);
    });
  });

  group('Congregation', () {
    test('the mosque and elsewhere both count as congregation', () async {
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.mosque);
      await PrayerLogStore.set(
        prefs,
        today,
        'dhuhr',
        PrayerRecord.congregation,
      );
      await PrayerLogStore.set(prefs, today, 'asr', PrayerRecord.alone);

      expect(PrayerLogStore.read(prefs, today).inCongregation, 2);
    });
  });

  group('Cycling with one tap', () {
    test('walks every option and returns to nothing', () {
      var record = PrayerRecord.none;
      final seen = <PrayerRecord>[];
      for (var i = 0; i < PrayerRecord.values.length; i++) {
        record = PrayerLogStore.next(record);
        seen.add(record);
      }
      expect(seen.toSet(), PrayerRecord.values.toSet());
      expect(record, PrayerRecord.none);
    });
  });

  group('The streak', () {
    Future<void> logFullDay(DateTime date) async {
      for (final id in PrayerLogStore.prayerIds) {
        await PrayerLogStore.set(prefs, date, id, PrayerRecord.alone);
      }
    }

    test('counts consecutive complete days', () async {
      for (var back = 1; back <= 3; back++) {
        await logFullDay(today.subtract(Duration(days: back)));
      }

      final summary = PrayerLogStore.summarise(prefs, days: 10, now: today);
      expect(summary.streak, 3, reason: 'today is still open');
    });

    test('an empty today does not break it', () async {
      await logFullDay(today.subtract(const Duration(days: 1)));

      // Nothing recorded today: the day is not over, and a streak that resets
      // at dawn would punish someone for waking up.
      expect(PrayerLogStore.summarise(prefs, days: 5, now: today).streak, 1);
    });

    test('a partly recorded today does break it', () async {
      await logFullDay(today.subtract(const Duration(days: 1)));
      await PrayerLogStore.set(prefs, today, 'fajr', PrayerRecord.alone);

      expect(PrayerLogStore.summarise(prefs, days: 5, now: today).streak, 0);
    });

    test('a gap ends it', () async {
      await logFullDay(today.subtract(const Duration(days: 1)));
      await logFullDay(today.subtract(const Duration(days: 3)));

      expect(PrayerLogStore.summarise(prefs, days: 10, now: today).streak, 1);
    });
  });

  group('The summary', () {
    test('reports shares over the window, not raw counts alone', () async {
      final yesterday = today.subtract(const Duration(days: 1));
      for (final id in PrayerLogStore.prayerIds) {
        await PrayerLogStore.set(prefs, yesterday, id, PrayerRecord.mosque);
      }

      final summary = PrayerLogStore.summarise(prefs, days: 2, now: today);
      expect(summary.possible, 10);
      expect(summary.onTime, 5);
      expect(summary.onTimeShare, closeTo(0.5, 1e-9));
      expect(summary.congregationShare, 1.0);
    });

    test('an empty log divides by nothing', () {
      final summary = PrayerLogStore.summarise(prefs, days: 7, now: today);
      expect(summary.onTimeShare, 0);
      expect(summary.congregationShare, 0);
    });
  });

  group('The stored form', () {
    test('survives a round trip', () {
      const records = {
        'fajr': PrayerRecord.mosque,
        'isha': PrayerRecord.missed,
      };
      expect(PrayerLogStore.decode(PrayerLogStore.encode(records)), records);
    });

    test('ignores anything it does not recognise', () {
      expect(PrayerLogStore.decode('nonsense'), isEmpty);
      expect(PrayerLogStore.decode('fajr:teleported'), isEmpty);
      expect(PrayerLogStore.decode('brunch:mosque'), isEmpty);
      expect(PrayerLogStore.decode('fajr:mosque,garbage'), {
        'fajr': PrayerRecord.mosque,
      });
    });
  });
}
