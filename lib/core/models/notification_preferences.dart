import 'dart:convert';

import '../services/prayer_calculation_service.dart';
import '../utils/input_validators.dart';

/// How a single prayer announces itself.
enum PrayerAlertMode {
  /// No notification at all for this prayer.
  off,

  /// Shows up in the shade, makes no sound and does not vibrate.
  silent,

  /// Vibration only.
  vibrate,

  /// Standard notification sound.
  notification,

  /// Full adhan: maximum importance, long vibration, adhan sound when the
  /// `res/raw/adhan` sound file is bundled.
  adhan,
}

extension PrayerAlertModeX on PrayerAlertMode {
  String get storageId => name;

  bool get isEnabled => this != PrayerAlertMode.off;

  bool get playsSound =>
      this == PrayerAlertMode.notification || this == PrayerAlertMode.adhan;

  static PrayerAlertMode fromStorage(Object? value) {
    if (value is bool) {
      // Migration from the old boolean per-prayer switches.
      return value ? PrayerAlertMode.adhan : PrayerAlertMode.off;
    }
    return PrayerAlertMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => PrayerAlertMode.adhan,
    );
  }
}

/// Everything the scheduler needs to know, in one persisted object.
///
/// Stored as JSON under a single preferences key so adding a new reminder type
/// never means adding another loose key.
class NotificationPreferences {
  const NotificationPreferences({
    this.masterEnabled = false,
    this.prayerModes = const {},
    this.preAdhanMinutes = 0,
    this.iqamaMinutes = 0,
    this.morningAzkarEnabled = false,
    this.morningAzkarOffsetMinutes = 30,
    this.eveningAzkarEnabled = false,
    this.eveningAzkarOffsetMinutes = 30,
    this.dailyAyahEnabled = false,
    this.dailyAyahHour = 9,
    this.dailyAyahMinute = 0,
    this.wirdEnabled = false,
    this.wirdHour = 20,
    this.wirdMinute = 0,
    this.quietHoursEnabled = false,
    this.quietStartHour = 23,
    this.quietEndHour = 6,
    this.adhanSoundId = 'system',
  });

  /// Master switch. When off, nothing is scheduled.
  final bool masterEnabled;

  /// Per-prayer alert mode, keyed by [PrayerIds.obligatory].
  final Map<String, PrayerAlertMode> prayerModes;

  /// Minutes before the adhan for the "get ready" reminder (0 = off).
  final int preAdhanMinutes;

  /// Minutes after the adhan for the iqama reminder (0 = off).
  final int iqamaMinutes;

  /// Morning azkar, anchored to Fajr rather than a fixed clock time.
  final bool morningAzkarEnabled;
  final int morningAzkarOffsetMinutes;

  /// Evening azkar, anchored to Asr.
  final bool eveningAzkarEnabled;
  final int eveningAzkarOffsetMinutes;

  /// Verse of the day at a fixed time.
  final bool dailyAyahEnabled;
  final int dailyAyahHour;
  final int dailyAyahMinute;

  /// Daily reading wird reminder at a fixed time.
  final bool wirdEnabled;
  final int wirdHour;
  final int wirdMinute;

  /// Quiet hours mute the non-prayer reminders only; prayer alerts keep
  /// whatever mode the user picked for them.
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  /// Which adhan plays for prayers set to [PrayerAlertMode.adhan].
  final String adhanSoundId;

  static const NotificationPreferences defaults = NotificationPreferences(
    prayerModes: {
      PrayerIds.fajr: PrayerAlertMode.adhan,
      PrayerIds.dhuhr: PrayerAlertMode.adhan,
      PrayerIds.asr: PrayerAlertMode.adhan,
      PrayerIds.maghrib: PrayerAlertMode.adhan,
      PrayerIds.isha: PrayerAlertMode.adhan,
    },
    preAdhanMinutes: 10,
    iqamaMinutes: 0,
  );

  PrayerAlertMode modeFor(String prayerId) =>
      prayerModes[prayerId] ?? PrayerAlertMode.off;

  bool get hasAnyPrayerAlert =>
      prayerModes.values.any((mode) => mode.isEnabled);

  /// True when [hour] falls inside the quiet window (wraps past midnight).
  bool isQuietHour(int hour) {
    if (!quietHoursEnabled) {
      return false;
    }
    if (quietStartHour == quietEndHour) {
      return false;
    }
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    return hour >= quietStartHour || hour < quietEndHour;
  }

  NotificationPreferences copyWith({
    bool? masterEnabled,
    Map<String, PrayerAlertMode>? prayerModes,
    int? preAdhanMinutes,
    int? iqamaMinutes,
    bool? morningAzkarEnabled,
    int? morningAzkarOffsetMinutes,
    bool? eveningAzkarEnabled,
    int? eveningAzkarOffsetMinutes,
    bool? dailyAyahEnabled,
    int? dailyAyahHour,
    int? dailyAyahMinute,
    bool? wirdEnabled,
    int? wirdHour,
    int? wirdMinute,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    String? adhanSoundId,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      prayerModes: prayerModes ?? this.prayerModes,
      preAdhanMinutes: preAdhanMinutes ?? this.preAdhanMinutes,
      iqamaMinutes: iqamaMinutes ?? this.iqamaMinutes,
      morningAzkarEnabled: morningAzkarEnabled ?? this.morningAzkarEnabled,
      morningAzkarOffsetMinutes:
          morningAzkarOffsetMinutes ?? this.morningAzkarOffsetMinutes,
      eveningAzkarEnabled: eveningAzkarEnabled ?? this.eveningAzkarEnabled,
      eveningAzkarOffsetMinutes:
          eveningAzkarOffsetMinutes ?? this.eveningAzkarOffsetMinutes,
      dailyAyahEnabled: dailyAyahEnabled ?? this.dailyAyahEnabled,
      dailyAyahHour: dailyAyahHour ?? this.dailyAyahHour,
      dailyAyahMinute: dailyAyahMinute ?? this.dailyAyahMinute,
      wirdEnabled: wirdEnabled ?? this.wirdEnabled,
      wirdHour: wirdHour ?? this.wirdHour,
      wirdMinute: wirdMinute ?? this.wirdMinute,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      adhanSoundId: adhanSoundId ?? this.adhanSoundId,
    );
  }

  Map<String, dynamic> toJson() => {
    'masterEnabled': masterEnabled,
    'prayerModes': {
      for (final entry in prayerModes.entries) entry.key: entry.value.storageId,
    },
    'preAdhanMinutes': preAdhanMinutes,
    'iqamaMinutes': iqamaMinutes,
    'morningAzkarEnabled': morningAzkarEnabled,
    'morningAzkarOffsetMinutes': morningAzkarOffsetMinutes,
    'eveningAzkarEnabled': eveningAzkarEnabled,
    'eveningAzkarOffsetMinutes': eveningAzkarOffsetMinutes,
    'dailyAyahEnabled': dailyAyahEnabled,
    'dailyAyahHour': dailyAyahHour,
    'dailyAyahMinute': dailyAyahMinute,
    'wirdEnabled': wirdEnabled,
    'wirdHour': wirdHour,
    'wirdMinute': wirdMinute,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartHour': quietStartHour,
    'quietEndHour': quietEndHour,
    'adhanSoundId': adhanSoundId,
  };

  String encode() => jsonEncode(toJson());

  factory NotificationPreferences.fromJson(Map<dynamic, dynamic> json) {
    final modes = <String, PrayerAlertMode>{};
    final rawModes = json['prayerModes'];
    if (rawModes is Map) {
      for (final entry in rawModes.entries) {
        final id = InputValidators.sanitizePrayerId(entry.key.toString());
        if (PrayerIds.obligatory.contains(id)) {
          modes[id] = PrayerAlertModeX.fromStorage(entry.value);
        }
      }
    }

    int intOr(String key, int fallback, {int min = 0, int max = 240}) {
      final value = json[key];
      if (value is num) {
        return value.toInt().clamp(min, max);
      }
      return fallback;
    }

    return NotificationPreferences(
      masterEnabled: json['masterEnabled'] == true,
      prayerModes: modes.isEmpty ? defaults.prayerModes : modes,
      preAdhanMinutes: intOr('preAdhanMinutes', 10, max: 60),
      iqamaMinutes: intOr('iqamaMinutes', 0, max: 60),
      morningAzkarEnabled: json['morningAzkarEnabled'] == true,
      morningAzkarOffsetMinutes: intOr(
        'morningAzkarOffsetMinutes',
        30,
        max: 180,
      ),
      eveningAzkarEnabled: json['eveningAzkarEnabled'] == true,
      eveningAzkarOffsetMinutes: intOr(
        'eveningAzkarOffsetMinutes',
        30,
        max: 180,
      ),
      dailyAyahEnabled: json['dailyAyahEnabled'] == true,
      dailyAyahHour: intOr('dailyAyahHour', 9, max: 23),
      dailyAyahMinute: intOr('dailyAyahMinute', 0, max: 59),
      wirdEnabled: json['wirdEnabled'] == true,
      wirdHour: intOr('wirdHour', 20, max: 23),
      wirdMinute: intOr('wirdMinute', 0, max: 59),
      quietHoursEnabled: json['quietHoursEnabled'] == true,
      quietStartHour: intOr('quietStartHour', 23, max: 23),
      quietEndHour: intOr('quietEndHour', 6, max: 23),
      adhanSoundId:
          json['adhanSoundId'] is String
              ? json['adhanSoundId'] as String
              : 'system',
    );
  }

  /// Decode from storage, tolerating the legacy `{"fajr": true}` format.
  static NotificationPreferences decode(String? raw, {bool? legacyMaster}) {
    if (raw == null || raw.isEmpty) {
      return defaults.copyWith(masterEnabled: legacyMaster ?? false);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return defaults;
      }
      if (decoded.containsKey('prayerModes') ||
          decoded.containsKey('masterEnabled')) {
        return NotificationPreferences.fromJson(decoded);
      }

      // Legacy shape: a flat map of prayer id -> bool.
      final migrated = <String, PrayerAlertMode>{};
      for (final entry in decoded.entries) {
        final id = InputValidators.sanitizePrayerId(entry.key.toString());
        if (PrayerIds.obligatory.contains(id)) {
          migrated[id] = PrayerAlertModeX.fromStorage(entry.value);
        }
      }
      return defaults.copyWith(
        masterEnabled: legacyMaster ?? false,
        prayerModes: migrated.isEmpty ? defaults.prayerModes : migrated,
      );
    } catch (_) {
      return defaults;
    }
  }
}
