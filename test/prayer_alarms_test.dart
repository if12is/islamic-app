import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/models/adhan_sound.dart';
import 'package:islamic_app/core/models/notification_preferences.dart';
import 'package:islamic_app/core/services/notification_scheduler.dart';
import 'package:islamic_app/core/services/notification_service.dart';
import 'package:islamic_app/core/services/prayer_alarms.dart';
import 'package:islamic_app/core/services/prayer_calculation_service.dart';

void main() {
  group('An alert handed to the alarm engine', () {
    test('carries the channel that holds the adhan the user chose', () {
      final encoded = PrayerAlarms.encode(
        ScheduledNotification(
          id: 1001,
          kind: NotificationKind.prayer,
          time: DateTime(2026, 10, 12, 4, 30),
          title: 'الفجر',
          body: 'حان وقت صلاة الفجر',
          mode: PrayerAlertMode.adhan,
          payload: 'prayer:fajr',
          adhanSound: const AdhanSoundSelection(id: 'rifat'),
          actions: const [NotificationActionSpec(id: 'log', label: 'سجّلت')],
        ),
      );

      expect(encoded['id'], 1001);
      expect(
        encoded['at'],
        DateTime(2026, 10, 12, 4, 30).millisecondsSinceEpoch,
      );
      expect(
        encoded['channel'],
        NotificationService.adhanChannelFor(
          const AdhanSoundSelection(id: 'rifat'),
        ),
      );
      // An adhan is what someone is waiting on by the clock, so it goes out
      // as an alarm and may take the locked screen.
      expect(encoded['alarm'], isTrue);
      expect(encoded['fullScreen'], isTrue);
      expect(encoded['silent'], isFalse);
      expect(encoded['payload'], 'prayer:fajr');
      expect(encoded['actions'], [
        {'id': 'log', 'label': 'سجّلت'},
      ]);
    });

    test('a quiet reminder is neither an alarm nor a full screen', () {
      final encoded = PrayerAlarms.encode(
        ScheduledNotification(
          id: 4001,
          kind: NotificationKind.azkar,
          time: DateTime(2026, 10, 12, 7, 0),
          title: 'أذكار الصباح',
          body: '',
          mode: PrayerAlertMode.silent,
        ),
      );

      expect(encoded['alarm'], isFalse);
      expect(encoded['fullScreen'], isFalse);
      expect(encoded['silent'], isTrue);
      expect(encoded.containsKey('actions'), isFalse);
      expect(encoded.containsKey('payload'), isFalse);
    });

    test('the whole plan survives being written as one JSON document', () {
      final items = [
        for (var i = 0; i < 3; i++)
          ScheduledNotification(
            id: 1000 + i,
            kind: NotificationKind.prayer,
            time: DateTime(2026, 10, 12, 4 + i, 30),
            title: 'صلاة',
            body: 'نص «مزدوج» وفاصلة, وسطر\nجديد',
            mode: PrayerAlertMode.adhan,
          ),
      ];

      final decoded =
          jsonDecode(
                jsonEncode([
                  for (final item in items) PrayerAlarms.encode(item),
                ]),
              )
              as List;

      expect(decoded, hasLength(3));
      expect((decoded.first as Map)['body'], 'نص «مزدوج» وفاصلة, وسطر\nجديد');
    });
  });

  group('Six weeks of alerts', () {
    final days = PrayerCalculationService.computeRange(
      latitude: 30.0444,
      longitude: 31.2357,
      method: 5,
      from: DateTime(2026, 6, 15),
      days: NotificationPlanner.engineHorizonDays,
    );

    final plan = NotificationPlanner.build(
      prefs: NotificationPreferences.defaults.copyWith(
        masterEnabled: true,
        preAdhanMinutes: 15,
        iqamaMinutes: 15,
        dailyAyahEnabled: true,
      ),
      days: days,
      now: DateTime(2026, 6, 15, 0, 1),
      languageCode: 'ar',
      maxItems: NotificationPlanner.engineMaxItems,
    );

    test('reach past the month that used to run out', () {
      expect(NotificationPlanner.engineHorizonDays, 45);
      expect(days, hasLength(45));
      final last = plan
          .map((item) => item.time)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(last.difference(DateTime(2026, 6, 15)).inDays, greaterThan(40));
    });

    test('never give two alerts the same id', () {
      // The ids are a base per category plus the day, and the bases are a
      // hundred days apart at the closest. A horizon longer than that would
      // have one category writing over another, and the alert that lost the
      // race would silently never arrive.
      final ids = plan.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('fit inside what the engine will accept', () {
      expect(
        plan.length,
        lessThanOrEqualTo(NotificationPlanner.engineMaxItems),
      );
      expect(plan.length, greaterThan(NotificationPlanner.defaultMaxItems));
    });

    test('are in time order, since the engine arms the first two', () {
      for (var i = 1; i < plan.length; i++) {
        expect(
          plan[i].time.isBefore(plan[i - 1].time),
          isFalse,
          reason: 'item $i is earlier than the one before it',
        );
      }
    });
  });

  group('What the device admits about delivery', () {
    AlarmHealth healthWith(Map<String, Object?> extra) => AlarmHealth.fromMap({
      'planSize': 900,
      'armed': 2,
      'standbyBucket': 10,
      'manufacturer': 'HONOR',
      'sdkInt': 35,
      ...extra,
    });

    test('reads the delivery record and the misses', () {
      final due = DateTime(2026, 10, 10, 4, 30);
      final health = healthWith({
        'delivered': jsonEncode([
          {
            'id': 1001,
            'due': due.millisecondsSinceEpoch,
            'shown': due.add(const Duration(seconds: 3)).millisecondsSinceEpoch,
          },
        ]),
        'missed': jsonEncode([
          {'id': 1002, 'due': due.millisecondsSinceEpoch},
        ]),
      });

      expect(health.delivered.single.id, 1001);
      expect(health.delivered.single.late, isFalse);
      expect(health.missed.single.shown, isNull);
      expect(health.manufacturer, 'HONOR');
    });

    test('an alert shown long after its time counts as late', () {
      final due = DateTime(2026, 10, 10, 4, 30);
      final health = healthWith({
        'delivered': jsonEncode([
          {
            'id': 1001,
            'due': due.millisecondsSinceEpoch,
            'shown':
                due.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
          },
        ]),
      });

      expect(health.delivered.single.late, isTrue);
    });

    test('the restricted bucket is reported as throttled', () {
      expect(healthWith({'standbyBucket': 45}).throttled, isTrue);
      expect(healthWith({'standbyBucket': 40}).throttled, isTrue);
      expect(healthWith({'standbyBucket': 20}).throttled, isFalse);
    });

    test('only misses from the last week count against delivery', () {
      final old = DateTime.now().subtract(const Duration(days: 30));
      final recent = DateTime.now().subtract(const Duration(days: 2));

      final stale = healthWith({
        'missed': jsonEncode([
          {'id': 1, 'due': old.millisecondsSinceEpoch},
        ]),
      });
      final fresh = healthWith({
        'missed': jsonEncode([
          {'id': 1, 'due': recent.millisecondsSinceEpoch},
        ]),
      });

      expect(stale.missedRecently, isEmpty);
      expect(stale.atRisk, isFalse);
      expect(fresh.missedRecently, hasLength(1));
      expect(fresh.atRisk, isTrue);
    });

    test('anything that stops an adhan shows up as a risk', () {
      expect(healthWith({'canScheduleExact': false}).atRisk, isTrue);
      expect(healthWith({'backgroundRestricted': true}).atRisk, isTrue);
      expect(healthWith({'forceStopped': true}).atRisk, isTrue);
      expect(
        healthWith({
          'canScheduleExact': true,
          'backgroundRestricted': false,
          'forceStopped': false,
        }).atRisk,
        isFalse,
      );
    });

    test('unreadable history is empty rather than a crash', () {
      final health = healthWith({'delivered': 'not json', 'missed': '{}'});
      expect(health.delivered, isEmpty);
      expect(health.missed, isEmpty);
    });

    test('nothing is claimed where the engine does not run', () {
      const health = AlarmHealth();
      expect(health.available, isFalse);
      expect(health.planSize, 0);
      expect(health.atRisk, isFalse);
    });
  });
}
