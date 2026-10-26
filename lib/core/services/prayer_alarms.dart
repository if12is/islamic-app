import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

/// One alert, as it was delivered or as it was missed.
class AlarmRecord {
  const AlarmRecord({
    required this.id,
    required this.due,
    this.shown,
    this.blocked = false,
  });

  final int id;
  final DateTime due;

  /// When it actually reached the screen. Null for a missed one.
  final DateTime? shown;

  /// Its alarm fired, but notifications were switched off and the system
  /// dropped it — not the app being stopped.
  final bool blocked;

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
      blocked: entry['reason'] == 'blocked',
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
    this.raw = const {},
  });

  /// Everything the engine reported, as it came, for [logText].
  final Map<Object?, Object?> raw;

  /// How many alerts are written down on the device, waiting their turn.
  final int planSize;
  final DateTime? planEndsAt;
  final DateTime? nextAt;

  /// How many are handed to the alarm manager right now: the next day's worth,
  /// up to twelve, re-armed as each one fires.
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
      raw: Map.unmodifiable(map),
    );
  }

  /// Android's names for why a process ended (ApplicationExitInfo.REASON_*).
  static const Map<int, String> _exitReasons = {
    0: 'unknown',
    1: 'exit self',
    2: 'signaled',
    3: 'low memory',
    4: 'crash',
    5: 'native crash',
    6: 'not responding',
    7: 'failed to start',
    8: 'permission change',
    9: 'excessive resource use',
    10: 'FORCE-STOPPED',
    11: 'user stopped',
    12: 'dependency died',
    13: 'other',
    14: 'frozen',
    15: 'package state change',
    16: 'package updated',
  };

  /// A plain-text account of the engine's state and recent history, for a
  /// person to copy out of the app and send.
  ///
  /// It is the only window onto what a vendor's battery manager does to the
  /// alarms on a phone nobody here holds: whether alarms were armed, whether
  /// they fired and how late, and whether Android itself says the app was
  /// force-stopped in between. In English and with Latin digits, because it
  /// is read by whoever fixes the engine, not by the person sending it.
  String get logText {
    String stamp(int millis) {
      final t = DateTime.fromMillisecondsSinceEpoch(millis);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    }

    List<Map<Object?, Object?>> entries(String key) {
      final value = raw[key];
      if (value is! String || value.isEmpty) {
        return const [];
      }
      try {
        final decoded = jsonDecode(value);
        return decoded is List
            ? [
              for (final entry in decoded)
                if (entry is Map) entry.cast<Object?, Object?>(),
            ]
            : const [];
      } catch (_) {
        return const [];
      }
    }

    int? millis(Object? value) => value is int && value > 0 ? value : null;

    final out =
        StringBuffer()
          ..writeln(
            'Fajr alarm log, ${stamp(DateTime.now().millisecondsSinceEpoch)}',
          )
          ..writeln(
            'device: ${raw['brand'] ?? manufacturer} ${raw['model'] ?? ''}, '
            'Android SDK $sdkInt, ${raw['display'] ?? ''}',
          )
          ..writeln(
            'exact=$canScheduleExact battery-exempt=$ignoringBatteryOptimizations '
            'power-save=$powerSaveMode restricted=$backgroundRestricted '
            'bucket=$standbyBucket force-stopped=$forceStopped '
            'notifications=${raw['notificationsEnabled']}',
          )
          ..writeln(
            'plan: $planSize to come, armed ${raw['armed']}, '
            'next ${millis(raw['nextAt']) == null ? '-' : stamp(raw['nextAt']! as int)}, '
            'last shown ${millis(raw['lastFiredAt']) == null ? '-' : stamp(raw['lastFiredAt']! as int)}, '
            'last armed by "$lastRecovery"'
            '${millis(raw['lastRecoveryAt']) == null ? '' : ' at ${stamp(raw['lastRecoveryAt']! as int)}'}',
          );
    if (millis(raw['bootedAt']) case final booted?) {
      out.writeln('phone started: ${stamp(booted)}');
    }

    out.writeln('\nprocess exits (newest first):');
    for (final exit in entries('exits')) {
      final at = millis(exit['t']);
      final reason = exit['r'] as int? ?? -1;
      out.writeln(
        '  ${at == null ? '?' : stamp(at)} '
        '${_exitReasons[reason] ?? 'reason $reason'} '
        '(importance ${exit['i']})'
        '${(exit['d'] as String? ?? '').isEmpty ? '' : ' ${exit['d']}'}',
      );
    }

    out.writeln('\nengine events (oldest first):');
    for (final event in entries('events')) {
      final at = millis(event['t']);
      out.writeln(
        '  ${at == null ? '?' : stamp(at)} ${event['k']}'
        '${event['d'] == null ? '' : ' ${event['d']}'}',
      );
    }

    out.writeln('\nmissed: ${missed.length}');
    for (final record in missed.reversed.take(30)) {
      out.writeln(
        '  ${record.id} due ${stamp(record.due.millisecondsSinceEpoch)}'
        '${record.blocked ? ' (blocked)' : ''}',
      );
    }
    out.writeln('\nshown: ${delivered.length}');
    for (final record in delivered.reversed.take(30)) {
      final shown = record.shown;
      out.writeln(
        '  ${record.id} due ${stamp(record.due.millisecondsSinceEpoch)}'
        '${shown == null ? '' : ', shown ${stamp(shown.millisecondsSinceEpoch)}'}',
      );
    }
    return out.toString();
  }
}

/// The app's own alarm engine, on the Android side of the method channel.
///
/// Why the app does not simply hand the week to the notification plugin, as it
/// used to: the plugin armed one week at once, and nothing extended it but
/// opening the app — so a week without opening it was a week of silence.
///
/// So the plan is written to the device as data, six weeks of it, and the
/// engine arms only the next day of alarms. Each one that fires arms the next,
/// and a reboot, an app update, a clock change or the app being opened arms
/// them all again. A phone nobody touches keeps calling to prayer.
///
/// What no app can survive from inside is being force-stopped — by the user,
/// or by a vendor battery manager on Honor, Xiaomi, Oppo, Vivo or Samsung that
/// does the same. Android then cancels every alarm the app holds and sends it
/// nothing, boot included, until it is opened. The engine cannot undo that;
/// it can only notice — the missed alerts, and on Android 15 the force-stop
/// itself — so the notification centre can say so and send the user to the
/// phone's auto-start setting, which is what prevents it.
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
      // Android 7 has no channels, so there the alert carries these itself.
      if (soundFor(item) case final sound?) 'sound': sound,
      'vibrate':
          item.mode == PrayerAlertMode.adhan ||
          item.mode == PrayerAlertMode.notification ||
          item.mode == PrayerAlertMode.vibrate,
      if (item.actions.isNotEmpty)
        'actions': [
          for (final action in item.actions)
            {'id': action.id, 'label': action.label},
        ],
    };
  }

  /// The sound an alert plays on Android 7, where no channel decides it:
  /// `raw:<name>` for a bundled adhan, a `content://` URI for one the user
  /// brought or downloaded, `default` for the phone's own tone, or null.
  /// Pure, for tests.
  static String? soundFor(ScheduledNotification item) {
    switch (item.mode) {
      case PrayerAlertMode.silent:
      case PrayerAlertMode.off:
      case PrayerAlertMode.vibrate:
        return null;
      case PrayerAlertMode.notification:
        return 'default';
      case PrayerAlertMode.adhan:
        if (item.kind != NotificationKind.prayer) {
          return 'default';
        }
        final sound = item.adhanSound.sanitized;
        if (sound.isCustom) {
          return sound.uri;
        }
        final raw = NotificationService.adhanSoundById(sound.id).rawResource;
        return raw == null ? 'default' : 'raw:$raw';
    }
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

  /// Show or remove the next prayer in the status bar. [prayers] are written
  /// to the device so the countdown moves on by itself, app closed or not.
  static Future<void> setNextPrayer({
    required bool enabled,
    required String label,
    required String channelName,
    required List<({DateTime at, String title})> prayers,
  }) {
    return _invoke('setNextPrayer', {
      'config': jsonEncode({
        'enabled': enabled,
        'label': label,
        'channelName': channelName,
        'entries': [
          for (final prayer in prayers)
            {'at': prayer.at.millisecondsSinceEpoch, 'title': prayer.title},
        ],
      }),
    });
  }

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
