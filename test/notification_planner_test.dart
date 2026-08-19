import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/models/notification_preferences.dart';
import 'package:islamic_app/core/services/notification_scheduler.dart';
import 'package:islamic_app/core/services/notification_service.dart';
import 'package:islamic_app/core/services/prayer_calculation_service.dart';

void main() {
  const latitude = 30.0444;
  const longitude = 31.2357;

  List<ComputedPrayerDay> daysFrom(DateTime start, {int days = 7}) {
    return PrayerCalculationService.computeRange(
      latitude: latitude,
      longitude: longitude,
      method: 5,
      from: start,
      days: days,
    );
  }

  // Midnight, so every prayer of every day is still in the future.
  final start = DateTime(2026, 6, 15);
  final now = DateTime(2026, 6, 15, 0, 1);

  group('NotificationPlanner', () {
    test('schedules nothing while the master switch is off', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults,
        days: daysFrom(start),
        now: now,
        languageCode: 'ar',
      );

      expect(plan, isEmpty);
    });

    test('schedules five prayers a day for a full week', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
        ),
        days: daysFrom(start),
        now: now,
        languageCode: 'ar',
      );

      expect(plan, hasLength(35));
      expect(
        plan.every((item) => item.kind == NotificationKind.prayer),
        isTrue,
      );
    });

    test('adds pre-adhan and iqama reminders around each prayer', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 15,
          iqamaMinutes: 10,
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final prayers = plan.where(
        (item) => item.kind == NotificationKind.prayer,
      );
      final pre = plan.where((item) => item.kind == NotificationKind.preAdhan);
      final iqama = plan.where((item) => item.kind == NotificationKind.iqama);

      expect(prayers, hasLength(5));
      expect(pre, hasLength(5));
      expect(iqama, hasLength(5));

      final fajr = prayers.firstWhere((item) => item.prayerId == PrayerIds.fajr);
      final fajrPre = pre.firstWhere((item) => item.prayerId == PrayerIds.fajr);
      final fajrIqama = iqama.firstWhere(
        (item) => item.prayerId == PrayerIds.fajr,
      );

      expect(fajr.time.difference(fajrPre.time), const Duration(minutes: 15));
      expect(fajrIqama.time.difference(fajr.time), const Duration(minutes: 10));
    });

    test('skips prayers set to off', () {
      final prefs = NotificationPreferences.defaults.copyWith(
        masterEnabled: true,
        preAdhanMinutes: 0,
        prayerModes: {
          PrayerIds.fajr: PrayerAlertMode.off,
          PrayerIds.dhuhr: PrayerAlertMode.adhan,
          PrayerIds.asr: PrayerAlertMode.silent,
          PrayerIds.maghrib: PrayerAlertMode.off,
          PrayerIds.isha: PrayerAlertMode.vibrate,
        },
      );

      final plan = NotificationPlanner.build(
        prefs: prefs,
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      expect(plan.map((item) => item.prayerId).toSet(), {
        PrayerIds.dhuhr,
        PrayerIds.asr,
        PrayerIds.isha,
      });
      expect(
        plan.firstWhere((item) => item.prayerId == PrayerIds.isha).mode,
        PrayerAlertMode.vibrate,
      );
    });

    test('anchors azkar reminders to Fajr and Asr, not the clock', () {
      final days = daysFrom(start, days: 1);
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          morningAzkarEnabled: true,
          morningAzkarOffsetMinutes: 30,
          eveningAzkarEnabled: true,
          eveningAzkarOffsetMinutes: 45,
        ),
        days: days,
        now: now,
        languageCode: 'ar',
      );

      final azkar = plan
          .where((item) => item.kind == NotificationKind.azkar)
          .toList();
      expect(azkar, hasLength(2));

      expect(
        azkar.first.time,
        days.first.timeOf(PrayerIds.fajr)!.add(const Duration(minutes: 30)),
      );
      expect(
        azkar.last.time,
        days.first.timeOf(PrayerIds.asr)!.add(const Duration(minutes: 45)),
      );
    });

    test('quiet hours mute optional reminders but never the prayer alert', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          dailyAyahEnabled: true,
          dailyAyahHour: 23,
          quietHoursEnabled: true,
          quietStartHour: 22,
          quietEndHour: 6,
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final ayah = plan.firstWhere(
        (item) => item.kind == NotificationKind.dailyAyah,
      );
      final fajr = plan.firstWhere(
        (item) => item.prayerId == PrayerIds.fajr,
      );

      expect(ayah.mode, PrayerAlertMode.silent);
      expect(fajr.mode, PrayerAlertMode.adhan);
    });

    test('never schedules a time that has already passed', () {
      final afternoon = DateTime(2026, 6, 15, 15, 0);
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(masterEnabled: true),
        days: daysFrom(start, days: 1),
        now: afternoon,
        languageCode: 'ar',
      );

      expect(plan.every((item) => item.time.isAfter(afternoon)), isTrue);
    });

    test('returns a sorted plan with unique notification ids', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 10,
          iqamaMinutes: 10,
          morningAzkarEnabled: true,
          eveningAzkarEnabled: true,
          dailyAyahEnabled: true,
          wirdEnabled: true,
        ),
        days: daysFrom(start),
        now: now,
        languageCode: 'ar',
      );

      final ids = plan.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));

      for (var i = 1; i < plan.length; i++) {
        expect(
          plan[i].time.isBefore(plan[i - 1].time),
          isFalse,
          reason: 'the plan must be chronological',
        );
      }
    });

    test('writes localized copy with the prayer name filled in', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final fajr = plan.firstWhere((item) => item.prayerId == PrayerIds.fajr);
      expect(fajr.title, contains('الفجر'));
      expect(fajr.title, isNot(contains('{prayer}')));
      expect(fajr.body, isNot(contains('{time}')));
      expect(fajr.payload, 'prayer:fajr');
    });

    test('gives prayer alerts an action and carries the chosen adhan', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          adhanSoundId: 'makkah',
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final fajr = plan.firstWhere((item) => item.prayerId == PrayerIds.fajr);
      expect(fajr.adhanSoundId, 'makkah');
      expect(fajr.actions.single.id, 'open_prayer');
    });

    test('points the verse of the day at that exact verse', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          dailyAyahEnabled: true,
          dailyAyahHour: 9,
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
        dailyAyahBody: (_) => 'نص الآية',
        dailyAyahReference: (_) => '2:255',
      );

      final ayah = plan.firstWhere(
        (item) => item.kind == NotificationKind.dailyAyah,
      );
      expect(ayah.payload, 'quran:verse:2:255');
      expect(ayah.body, 'نص الآية');
      expect(
        ayah.actions.map((action) => action.id),
        containsAll(<String>['open_ayah', 'listen_ayah']),
      );
    });

    test('falls back to a generic payload without a verse reference', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          dailyAyahEnabled: true,
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final ayah = plan.firstWhere(
        (item) => item.kind == NotificationKind.dailyAyah,
      );
      expect(ayah.payload, 'quran:ayah_of_the_day');
      expect(ayah.actions.map((action) => action.id), ['open_ayah']);
    });

    test('formats the clock in Arabic digits for Arabic', () {
      final time = DateTime(2026, 6, 15, 13, 5);

      expect(NotificationPlanner.formatClock(time, 'ar'), contains('١:٠٥'));
      expect(NotificationPlanner.formatClock(time, 'en'), contains('1:05'));
    });
  });

  group('NotificationPreferences', () {
    test('migrates the legacy boolean map', () {
      final prefs = NotificationPreferences.decode(
        '{"fajr":true,"dhuhr":false,"asr":true,"maghrib":true,"isha":false}',
        legacyMaster: true,
      );

      expect(prefs.masterEnabled, isTrue);
      expect(prefs.modeFor(PrayerIds.fajr), PrayerAlertMode.adhan);
      expect(prefs.modeFor(PrayerIds.dhuhr), PrayerAlertMode.off);
      expect(prefs.modeFor(PrayerIds.isha), PrayerAlertMode.off);
    });

    test('survives an encode/decode round trip', () {
      final original = NotificationPreferences.defaults.copyWith(
        masterEnabled: true,
        preAdhanMinutes: 20,
        iqamaMinutes: 5,
        eveningAzkarEnabled: true,
        wirdEnabled: true,
        wirdHour: 21,
        wirdMinute: 30,
        quietHoursEnabled: true,
      );

      final restored = NotificationPreferences.decode(original.encode());

      expect(restored.masterEnabled, isTrue);
      expect(restored.preAdhanMinutes, 20);
      expect(restored.iqamaMinutes, 5);
      expect(restored.eveningAzkarEnabled, isTrue);
      expect(restored.wirdHour, 21);
      expect(restored.wirdMinute, 30);
      expect(restored.quietHoursEnabled, isTrue);
      expect(restored.modeFor(PrayerIds.maghrib), PrayerAlertMode.adhan);
    });

    test('keeps the chosen adhan sound across a round trip', () {
      final restored = NotificationPreferences.decode(
        NotificationPreferences.defaults
            .copyWith(masterEnabled: true, adhanSoundId: 'madinah')
            .encode(),
      );
      expect(restored.adhanSoundId, 'madinah');
    });

    test('quiet hours wrap past midnight', () {
      const prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietStartHour: 23,
        quietEndHour: 6,
      );

      expect(prefs.isQuietHour(23), isTrue);
      expect(prefs.isQuietHour(2), isTrue);
      expect(prefs.isQuietHour(6), isFalse);
      expect(prefs.isQuietHour(14), isFalse);
    });

    test('falls back to defaults on corrupt storage', () {
      final prefs = NotificationPreferences.decode('not json at all');
      expect(prefs.modeFor(PrayerIds.fajr), PrayerAlertMode.adhan);
      expect(prefs.masterEnabled, isFalse);
    });
  });
}
