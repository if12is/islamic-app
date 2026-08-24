import 'dart:convert';

import '../services/prayer_calculation_service.dart';
import 'adhan_sound.dart';
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
    this.wirdAdaptive = false,
    this.quietHoursEnabled = false,
    this.quietStartHour = 23,
    this.quietEndHour = 6,
    this.adhanSound = AdhanSoundSelection.system,
    this.fajrAdhanSound,
    this.islamicEventsEnabled = false,
    this.fridayRemindersEnabled = false,
    this.fastingRemindersEnabled = false,
    this.surahRemindersEnabled = false,
    this.surahReminderHour = 20,
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

  /// Move the wird reminder to the hour this person already reads in.
  ///
  /// Learned on the device from nothing but which hour sessions happen in.
  final bool wirdAdaptive;

  /// Quiet hours mute the non-prayer reminders only; prayer alerts keep
  /// whatever mode the user picked for them.
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  /// Which adhan plays for prayers set to [PrayerAlertMode.adhan].
  final AdhanSoundSelection adhanSound;

  /// Optional Fajr-only adhan — the Fajr call has its own extra line, so many
  /// people want a different recording for it. Null means "same as the rest".
  final AdhanSoundSelection? fajrAdhanSound;

  /// Ashura, Arafah, the two Eids, Ramadan, the white days.
  final bool islamicEventsEnabled;

  /// Surah Al-Kahf and salawat on Friday.
  final bool fridayRemindersEnabled;

  /// The night before Monday, Thursday, and the white days.
  final bool fastingRemindersEnabled;

  /// A daily nudge towards a surah worth reading, with why it is worth it.
  final bool surahRemindersEnabled;
  final int surahReminderHour;

  /// The adhan a given prayer should play.
  AdhanSoundSelection soundForPrayer(String prayerId) {
    if (prayerId == PrayerIds.fajr && fajrAdhanSound != null) {
      return fajrAdhanSound!.sanitized;
    }
    return adhanSound.sanitized;
  }

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
    bool? wirdAdaptive,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    AdhanSoundSelection? adhanSound,
    AdhanSoundSelection? fajrAdhanSound,
    bool clearFajrAdhanSound = false,
    bool? islamicEventsEnabled,
    bool? fridayRemindersEnabled,
    bool? fastingRemindersEnabled,
    bool? surahRemindersEnabled,
    int? surahReminderHour,
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
      wirdAdaptive: wirdAdaptive ?? this.wirdAdaptive,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      adhanSound: adhanSound ?? this.adhanSound,
      fajrAdhanSound:
          clearFajrAdhanSound ? null : (fajrAdhanSound ?? this.fajrAdhanSound),
      islamicEventsEnabled: islamicEventsEnabled ?? this.islamicEventsEnabled,
      fridayRemindersEnabled:
          fridayRemindersEnabled ?? this.fridayRemindersEnabled,
      fastingRemindersEnabled:
          fastingRemindersEnabled ?? this.fastingRemindersEnabled,
      surahRemindersEnabled:
          surahRemindersEnabled ?? this.surahRemindersEnabled,
      surahReminderHour: (surahReminderHour ?? this.surahReminderHour).clamp(
        0,
        23,
      ),
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
    'wirdAdaptive': wirdAdaptive,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartHour': quietStartHour,
    'quietEndHour': quietEndHour,
    'adhanSound': adhanSound.toJson(),
    if (fajrAdhanSound != null) 'fajrAdhanSound': fajrAdhanSound!.toJson(),
    'islamicEventsEnabled': islamicEventsEnabled,
    'fridayRemindersEnabled': fridayRemindersEnabled,
    'fastingRemindersEnabled': fastingRemindersEnabled,
    'surahRemindersEnabled': surahRemindersEnabled,
    'surahReminderHour': surahReminderHour,
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
      wirdAdaptive: json['wirdAdaptive'] == true,
      quietHoursEnabled: json['quietHoursEnabled'] == true,
      quietStartHour: intOr('quietStartHour', 23, max: 23),
      quietEndHour: intOr('quietEndHour', 6, max: 23),
      adhanSound: _readSound(json['adhanSound']) ?? AdhanSoundSelection.system,
      fajrAdhanSound: _readSound(json['fajrAdhanSound']),
      islamicEventsEnabled: json['islamicEventsEnabled'] == true,
      fridayRemindersEnabled: json['fridayRemindersEnabled'] == true,
      fastingRemindersEnabled: json['fastingRemindersEnabled'] == true,
      surahRemindersEnabled: json['surahRemindersEnabled'] == true,
      surahReminderHour: (json['surahReminderHour'] as num?)?.toInt() ?? 20,
    );
  }

  static AdhanSoundSelection? _readSound(Object? raw) {
    if (raw is Map) {
      return AdhanSoundSelection.fromJson(raw);
    }
    // Older builds stored just the id.
    if (raw is String && raw.isNotEmpty) {
      return AdhanSoundSelection(id: raw).sanitized;
    }
    return null;
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
