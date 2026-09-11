import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/models/adhan_sound.dart';
import 'package:islamic_app/core/models/notification_preferences.dart';
import 'package:islamic_app/core/services/hijri_service.dart';
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
          prayerLogRemindersEnabled: false,
          kahfRemindersEnabled: false,
          fridaySalawatEnabled: false,
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

      final fajr = prayers.firstWhere(
        (item) => item.prayerId == PrayerIds.fajr,
      );
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
        prayerLogRemindersEnabled: false,
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

      final azkar =
          plan.where((item) => item.kind == NotificationKind.azkar).toList();
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
      final fajr = plan.firstWhere((item) => item.prayerId == PrayerIds.fajr);

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
          adhanSound: const AdhanSoundSelection(id: 'rifat'),
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      final fajr = plan.firstWhere((item) => item.prayerId == PrayerIds.fajr);
      expect(fajr.adhanSound.id, 'rifat');
      expect(fajr.actions.single.id, 'open_prayer');
    });

    test('uses the Fajr-only adhan when one is set', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          adhanSound: const AdhanSoundSelection(id: 'rifat'),
          fajrAdhanSound: const AdhanSoundSelection(id: 'fajr_abu_rahiq'),
        ),
        days: daysFrom(start, days: 1),
        now: now,
        languageCode: 'ar',
      );

      expect(
        plan
            .firstWhere((item) => item.prayerId == PrayerIds.fajr)
            .adhanSound
            .id,
        'fajr_abu_rahiq',
      );
      expect(
        plan
            .firstWhere((item) => item.prayerId == PrayerIds.maghrib)
            .adhanSound
            .id,
        'rifat',
      );
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

    test('asks about Surah Al-Kahf through Friday, and only on Friday', () {
      // 2026-08-21 is a Friday.
      final friday = DateTime(2026, 8, 21);
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          prayerLogRemindersEnabled: false,
          fridaySalawatEnabled: false,
          prayerModes: {
            for (final id in PrayerIds.obligatory) id: PrayerAlertMode.off,
          },
        ),
        days: daysFrom(friday, days: 7),
        now: DateTime(2026, 8, 21, 0, 1),
        languageCode: 'ar',
      );

      final kahf =
          plan.where((item) => item.payload == 'quran:surah:18').toList();
      expect(kahf, hasLength(5));
      for (final item in kahf) {
        expect(item.time.weekday, DateTime.friday);
        expect(item.kind, NotificationKind.friday);
        expect(
          NotificationPlanner.kahfIds(friday),
          contains(item.id),
          reason: 'the app cancels the series by these ids once it is read',
        );
      }
      // Before Maghrib, all of them: the last one says so.
      final maghrib = daysFrom(friday, days: 1).first.timeOf(PrayerIds.maghrib)!;
      expect(kahf.every((item) => item.time.isBefore(maghrib)), isTrue);
      expect(
        kahf.first.actions.map((action) => action.id),
        containsAll(<String>['open_kahf', 'kahf_done']),
      );
    });

    test('says nothing more about Al-Kahf once it has been read', () {
      final friday = DateTime(2026, 8, 21);
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(masterEnabled: true),
        days: daysFrom(friday, days: 1),
        now: DateTime(2026, 8, 21, 0, 1),
        languageCode: 'ar',
        isKahfRead: (date) => true,
      );

      expect(plan.where((item) => item.payload == 'quran:surah:18'), isEmpty);
    });

    test('asks for salawat through Friday until the count is reached', () {
      final friday = DateTime(2026, 8, 21);
      List<ScheduledNotification> planFor({required bool done}) =>
          NotificationPlanner.build(
            prefs: NotificationPreferences.defaults.copyWith(
              masterEnabled: true,
            ),
            days: daysFrom(friday, days: 1),
            now: DateTime(2026, 8, 21, 0, 1),
            languageCode: 'en',
            isSalawatDone: (date) => done,
          ).where((item) => item.payload == 'salawat').toList();

      final salawat = planFor(done: false);
      expect(salawat, hasLength(4));
      expect(salawat.first.title, contains('Prophet'));
      expect(
        salawat.map((item) => item.id).toSet(),
        everyElement(isIn(NotificationPlanner.fridaySalawatIds(friday))),
      );
      expect(planFor(done: true), isEmpty);
    });

    test('reminds the night before a fasting day', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
          prayerModes: {
            for (final id in PrayerIds.obligatory) id: PrayerAlertMode.off,
          },
          fastingRemindersEnabled: true,
        ),
        days: daysFrom(DateTime(2026, 8, 20), days: 7),
        now: DateTime(2026, 8, 20, 0, 1),
        languageCode: 'ar',
      );

      final fasting =
          plan.where((item) => item.kind == NotificationKind.event).toList();
      expect(fasting, isNotEmpty);

      // Every reminder lands at 21:00 the evening before an actual fasting day.
      for (final item in fasting) {
        expect(item.time.hour, 21);

        final tomorrow = item.time.add(const Duration(days: 1));
        final hijri = HijriService.fromGregorian(tomorrow);
        final isWhiteDay = hijri.hDay >= 13 && hijri.hDay <= 15;

        expect(
          HijriService.isRecommendedFastingWeekday(tomorrow) || isWhiteDay,
          isTrue,
          reason: 'reminder on ${item.time} points at a non-fasting day',
        );
      }
    });

    test('stays silent about occasions when the switch is off', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 0,
        ),
        days: daysFrom(start),
        now: now,
        languageCode: 'ar',
      );

      expect(
        plan.where((item) => item.kind == NotificationKind.event),
        isEmpty,
      );
    });

    group('asks how each prayer was prayed', () {
      NotificationPreferences logOnly({int followUps = 2, int delay = 30}) =>
          NotificationPreferences.defaults.copyWith(
            masterEnabled: true,
            preAdhanMinutes: 0,
            kahfRemindersEnabled: false,
            fridaySalawatEnabled: false,
            prayerLogDelayMinutes: delay,
            prayerLogFollowUps: followUps,
          );

      List<ScheduledNotification> asksAbout(
        List<ScheduledNotification> plan,
        String prayerId,
      ) =>
          plan
              .where(
                (item) =>
                    item.kind == NotificationKind.prayerLog &&
                    item.prayerId == prayerId,
              )
              .toList();

      test('first once there has been time to pray, then every two hours', () {
        final day = daysFrom(start, days: 1).first;
        final plan = NotificationPlanner.build(
          prefs: logOnly(),
          days: [day],
          now: now,
          languageCode: 'ar',
        );

        final fajr = asksAbout(plan, PrayerIds.fajr);
        final adhan = day.timeOf(PrayerIds.fajr)!;
        expect(fajr, hasLength(3), reason: 'the first ask and two more');
        expect(fajr[0].time, adhan.add(const Duration(minutes: 30)));
        expect(fajr[1].time, fajr[0].time.add(NotificationPlanner.prayerLogGap));
        expect(fajr[2].time, fajr[1].time.add(NotificationPlanner.prayerLogGap));
        expect(fajr.first.title, contains('الفجر'));
        expect(fajr.first.payload, 'log:fajr:2026-06-15');
        expect(
          fajr.first.actions.map((action) => action.id),
          ['log_mosque', 'log_alone', 'log_missed'],
        );
        expect(
          fajr.map((item) => item.id),
          everyElement(
            isIn(NotificationPlanner.prayerLogIds(day.date, PrayerIds.fajr)),
          ),
          reason: 'logging Fajr cancels exactly these',
        );
      });

      test('asks even when the adhan itself is off', () {
        final plan = NotificationPlanner.build(
          prefs: logOnly().copyWith(
            prayerModes: {
              for (final id in PrayerIds.obligatory) id: PrayerAlertMode.off,
            },
          ),
          days: daysFrom(start, days: 1),
          now: now,
          languageCode: 'ar',
        );

        expect(plan.where((item) => item.kind == NotificationKind.prayer), isEmpty);
        expect(asksAbout(plan, PrayerIds.dhuhr), isNotEmpty);
      });

      test('never asks after midnight', () {
        final plan = NotificationPlanner.build(
          prefs: logOnly(followUps: 4),
          days: daysFrom(start, days: 1),
          now: now,
          languageCode: 'ar',
        );

        final isha = asksAbout(plan, PrayerIds.isha);
        expect(isha, isNotEmpty);
        for (final item in isha) {
          expect(item.time.day, start.day, reason: '${item.time}');
        }
        expect(isha.length, lessThan(5));
      });

      test('stops asking about a prayer already logged', () {
        final plan = NotificationPlanner.build(
          prefs: logOnly(),
          days: daysFrom(start, days: 2),
          now: now,
          languageCode: 'ar',
          isPrayerLogged:
              (date, prayerId) =>
                  date.day == start.day && prayerId == PrayerIds.fajr,
        );

        final fajr = asksAbout(plan, PrayerIds.fajr);
        expect(
          fajr.every((item) => item.time.day != start.day),
          isTrue,
          reason: "today's Fajr is logged; tomorrow's is not",
        );
        expect(fajr, isNotEmpty);
      });

      test('only for the next three days, not the whole week', () {
        // Every alarm makes the plugin rewrite its whole stored schedule, so
        // a week of asks nearly tripled each pass. The window slides forward
        // on every launch and every return to the app on a new day.
        final plan = NotificationPlanner.build(
          prefs: logOnly(),
          days: daysFrom(start),
          now: now,
          languageCode: 'ar',
        );

        final days =
            plan
                .where((item) => item.kind == NotificationKind.prayerLog)
                .map((item) => item.time.day)
                .toSet();
        expect(days, {15, 16, 17});
        expect(
          plan.where((item) => item.kind == NotificationKind.prayer).length,
          35,
          reason: 'the adhan still covers the whole week',
        );
      });

      test('can be switched off', () {
        final plan = NotificationPlanner.build(
          prefs: logOnly().copyWith(prayerLogRemindersEnabled: false),
          days: daysFrom(start),
          now: now,
          languageCode: 'ar',
        );
        expect(
          plan.where((item) => item.kind == NotificationKind.prayerLog),
          isEmpty,
        );
      });
    });

    test('every day in the horizon gets its own id slot', () {
      // Across a month end, where day-of-month arithmetic would collide.
      final slots = {
        for (var i = 0; i < NotificationPlanner.horizonDays + 1; i++)
          NotificationPlanner.daySlot(DateTime(2027, 2, 25 + i)),
      };
      expect(slots, hasLength(NotificationPlanner.horizonDays + 1));
    });

    test('a week with everything on fits the plan and keeps ids unique', () {
      final plan = NotificationPlanner.build(
        prefs: NotificationPreferences.defaults.copyWith(
          masterEnabled: true,
          preAdhanMinutes: 10,
          iqamaMinutes: 10,
          morningAzkarEnabled: true,
          eveningAzkarEnabled: true,
          dailyAyahEnabled: true,
          wirdEnabled: true,
          surahRemindersEnabled: true,
          fastingRemindersEnabled: true,
          islamicEventsEnabled: true,
          prayerLogFollowUps: 3,
        ),
        days: daysFrom(DateTime(2026, 8, 17)),
        now: DateTime(2026, 8, 17, 0, 1),
        languageCode: 'ar',
      );

      expect(plan.length, lessThan(NotificationPlanner.defaultMaxItems));
      final ids = plan.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      // The last day is still there: nothing was cut off the end.
      expect(plan.last.time.day, 23);
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

    test('keeps bundled and custom adhan choices across a round trip', () {
      final restored = NotificationPreferences.decode(
        NotificationPreferences.defaults
            .copyWith(
              masterEnabled: true,
              adhanSound: const AdhanSoundSelection(id: 'mustafa_ismail'),
              fajrAdhanSound: const AdhanSoundSelection(
                id: AdhanSoundSelection.customId,
                uri: 'content://media/external/audio/media/42',
                title: 'أذاني',
              ),
            )
            .encode(),
      );

      expect(restored.adhanSound.id, 'mustafa_ismail');
      expect(restored.fajrAdhanSound?.isCustom, isTrue);
      expect(restored.fajrAdhanSound?.title, 'أذاني');
      expect(
        restored.soundForPrayer(PrayerIds.fajr).uri,
        'content://media/external/audio/media/42',
      );
      expect(restored.soundForPrayer(PrayerIds.isha).id, 'mustafa_ismail');
    });

    test('a custom sound without a URI falls back to the default', () {
      const broken = AdhanSoundSelection(id: AdhanSoundSelection.customId);
      expect(broken.sanitized.id, AdhanSoundSelection.systemId);
    });

    test('migrates an adhan sound stored as a bare id', () {
      final restored = NotificationPreferences.fromJson({
        'masterEnabled': true,
        'adhanSound': 'rifat',
      });
      expect(restored.adhanSound.id, 'rifat');
    });

    test('the follow-up reminders are on for files written before them', () {
      final restored = NotificationPreferences.fromJson({
        'masterEnabled': true,
        'fridayRemindersEnabled': false,
      });
      expect(restored.prayerLogRemindersEnabled, isTrue);
      expect(restored.kahfRemindersEnabled, isTrue);
      expect(restored.fridaySalawatEnabled, isTrue);
      expect(restored.prayerLogDelayMinutes, 30);
      expect(restored.prayerLogFollowUps, 2);
    });

    test('keeps the follow-up choices across a round trip', () {
      final restored = NotificationPreferences.decode(
        NotificationPreferences.defaults
            .copyWith(
              masterEnabled: true,
              prayerLogRemindersEnabled: false,
              prayerLogDelayMinutes: 45,
              prayerLogFollowUps: 3,
              kahfRemindersEnabled: false,
            )
            .encode(),
      );
      expect(restored.prayerLogRemindersEnabled, isFalse);
      expect(restored.prayerLogDelayMinutes, 45);
      expect(restored.prayerLogFollowUps, 3);
      expect(restored.kahfRemindersEnabled, isFalse);
      expect(restored.fridaySalawatEnabled, isTrue);
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
