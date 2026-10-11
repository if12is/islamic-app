import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

/// One alert, as it was delivered or as it was missed.
class AlarmRecord {
  const AlarmRecord({required this.id, required this.due, this.shown});

  final int id;
  final DateTime due;

  /// When it actually reached the screen. Null for a missed one.
  final DateTime? shown;

  bool get late =>
      shown != null && shown!.difference(due) > const Duration(minutes: 2);

  static AlarmRecord? fromJson(Object? entry) {
    if (entry is! Map) {
      return null;
    }
    final id = entry['id'];
    final due = entry['due'];
    if (id is! int || due is! int || due <= 0) {
      return null;
    }
    final shown = entry['shown'];
    return AlarmRecord(
      id: id,
      due: DateTime.fromMillisecondsSinceEpoch(due),
      shown:
          shown is int && shown > 0
              ? DateTime.fromMillisecondsSinceEpoch(shown)
              : null,
    );
  }
}

/// What the device will admit about this app's ability to sound an adhan.
///
/// Scheduling an alert always succeeds. Delivering it depends on a handful of
/// system states that are invisible from inside the app unless they are read
/// back deliberately — which is what this is for. Everything here comes from
/// Android itself, not from a guess.
class AlarmHealth {
  const AlarmHealth({
    this.planSize = 0,
    this.planEndsAt,
    this.nextAt,
    this.armed = 0,
    this.lastFiredAt,
    this.lastRecovery = '',
    this.delivered = const [],
    this.missed = const [],
    this.canScheduleExact,
    this.ignoringBatteryOptimizations,
    this.powerSaveMode,
    this.backgroundRestricted,
    this.standbyBucket = -1,
    this.forceStopped,
    this.manufacturer = '',
    this.sdkInt = 0,
    this.available = false,
  });

  /// How many alerts are written down on the device, waiting their turn.
  final int planSize;
  final DateTime? planEndsAt;
  final DateTime? nextAt;

  /// How many are handed to the alarm manager right now. Two is normal: the
  /// engine arms the next pair and re-arms as each one fires.
  final int armed;

  final DateTime? lastFiredAt;

  /// Why the alarms were last re-armed: `boot`, `fired`, `plan`, `foreground`.
  final String lastRecovery;

  final List<AlarmRecord> delivered;
  final List<AlarmRecord> missed;

  final bool? canScheduleExact;
  final bool? ignoringBatteryOptimizations;
  final bool? powerSaveMode;

  /// The user, or the vendor, has put the app in the restricted state where
  /// nothing of its own may run in the background.
  final bool? backgroundRestricted;

  /// 10 active, 20 working set, 30 frequent, 40 rare, 45 restricted, -1 unknown.
  final int standbyBucket;

  /// Android 15 and up: the app was force-stopped, which cancels every alarm
  /// it was holding. The single most common reason an adhan never sounds.
  final bool? forceStopped;

  final String manufacturer;
  final int sdkInt;

  /// False on iOS and the web, where this engine does not run.
  final bool available;

  /// Android stops almost everything an app has queued in this bucket: one
  /// alarm a day, where five prayers need five.
  bool get throttled => standbyBucket >= 40;

  /// Alerts whose time passed with nothing shown, in the last week.
  List<AlarmRecord> get missedRecently {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return [
      for (final record in missed)
        if (record.due.isAfter(since)) record,
    ];
  }

  /// Something is in the way of the next adhan.
  bool get atRisk =>
      canScheduleExact == false ||
      backgroundRestricted == true ||
      throttled ||
      forceStopped == true ||
      missedRecently.isNotEmpty;

  static AlarmHealth fromMap(Map<Object?, Object?> map) {
    DateTime? at(String key) {
      final value = map[key];
      return value is int && value > 0
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : null;
    }

    List<AlarmRecord> records(String key) {
      final raw = map[key];
      if (raw is! String || raw.isEmpty) {
        return const [];
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          return const [];
        }
        return [
          for (final entry in decoded)
            if (AlarmRecord.fromJson(entry) case final record?) record,
        ];
      } catch (e) {
        AppLogger.warning('Could not read alarm history: $e');
        return const [];
      }
    }

    return AlarmHealth(
      available: true,
      planSize: map['planSize'] as int? ?? 0,
      planEndsAt: at('planEndsAt'),
      nextAt: at('nextAt'),
      armed: map['armed'] as int? ?? 0,
      lastFiredAt: at('lastFiredAt'),
      lastRecovery: map['lastRecovery'] as String? ?? '',
      delivered: records('delivered'),
      missed: records('missed'),
      canScheduleExact: map['canScheduleExact'] as bool?,
      ignoringBatteryOptimizations:
          map['ignoringBatteryOptimizations'] as bool?,
      powerSaveMode: map['powerSaveMode'] as bool?,
      backgroundRestricted: map['backgroundRestricted'] as bool?,
      standbyBucket: map['standbyBucket'] as int? ?? -1,
      forceStopped: map['forceStopped'] as bool?,
      manufacturer: map['manufacturer'] as String? ?? '',
      sdkInt: map['sdkInt'] as int? ?? 0,
    );
  }
}

/// The app's own alarm engine, on the Android side of the method channel.
///
/// Why the app does not simply hand the week to the notification plugin, as it
/// used to: the plugin arms every alert at once and keeps nothing it can
/// rebuild from. Android cancels all of an app's alarms when the system — or
/// one of the vendor battery managers on Xiaomi, Oppo, Vivo, Honor or Samsung
/// — stops the app, and from Android 15 that is written into the platform:
/// a stopped app loses every pending alarm it holds. Nothing then brought
/// them back until somebody opened the app, which is exactly the complaint:
/// miss a day and the adhan stops.
///
/// So the plan is written to the device as data, and the engine arms only the
/// next two alarms. Each one that fires arms the next, and a reboot, an app
/// update, a clock change or the app being opened arms them all again. The
/// plan reaches six weeks ahead, so a phone nobody touches keeps calling to
/// prayer.
class PrayerAlarms {
  PrayerAlarms._();

  static const MethodChannel _channel = MethodChannel('islamic_app/alarms');

  /// Android only. Elsewhere the notification plugin keeps the schedule.
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hand over the whole plan. Returns how many alerts were accepted.
  static Future<int> setPlan(List<ScheduledNotification> items) async {
    if (!available) {
      return 0;
    }
    final payload = jsonEncode([for (final item in items) encode(item)]);
    try {
      return await _channel.invokeMethod<int>('setPlan', {'items': payload}) ??
          0;
    } catch (e, stack) {
      AppLogger.error(
        'Could not hand the prayer plan to the alarm engine',
        e,
        stack,
      );
      return 0;
    }
  }

  /// One alert as the engine reads it. Pure, for tests.
  static Map<String, Object?> encode(ScheduledNotification item) {
    final adhan = item.mode == PrayerAlertMode.adhan;
    return {
      'id': item.id,
      'at': item.time.millisecondsSinceEpoch,
      'title': item.title,
      'body': item.body,
      'channel': NotificationService.channelIdFor(
        kind: item.kind,
        mode: item.mode,
        adhanSound: item.adhanSound,
      ),
      if (item.payload != null) 'payload': item.payload,
      'alarm': adhan,
      'fullScreen': adhan && item.kind == NotificationKind.prayer,
      'silent': item.mode == PrayerAlertMode.silent,
      if (item.actions.isNotEmpty)
        'actions': [
          for (final action in item.actions)
            {'id': action.id, 'label': action.label},
        ],
    };
  }

  static Future<void> cancel(Iterable<int> ids) async {
    if (!available || ids.isEmpty) {
      return;
    }
    await _invoke('cancel', {'ids': ids.toList()});
  }

  static Future<void> clear() => _invoke('clear');

  /// Arm the next alarms again, after anything that may have lost them.
  static Future<void> arm([String reason = 'app']) =>
      _invoke('arm', {'reason': reason});

  static Future<void> clearHistory() => _invoke('clearHistory');

  static Future<AlarmHealth> health() async {
    if (!available) {
      return const AlarmHealth();
    }
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'diagnostics',
      );
      return map == null ? const AlarmHealth() : AlarmHealth.fromMap(map);
    } catch (e) {
      AppLogger.warning('Could not read the alarm engine state: $e');
      return const AlarmHealth();
    }
  }

  /// What the user tapped to open the app, when it was one of these alerts.
  static Future<({String? payload, String? actionId})?> takeLaunch() async {
    if (!available) {
      return null;
    }
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('takeLaunch');
      if (map == null) {
        return null;
      }
      return (
        payload: map['payload'] as String?,
        actionId: map['action'] as String?,
      );
    } catch (e) {
      AppLogger.warning('Could not read the notification that opened us: $e');
      return null;
    }
  }

  static Future<void> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!available) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      AppLogger.warning('Alarm engine call "$method" failed: $e');
    }
  }
}
