import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/quran/data/services/quran_local_service.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'hijri_service.dart';
import 'surah_virtues.dart';
import 'notification_service.dart';
import 'prayer_calculation_service.dart';
import 'prayer_settings_store.dart';
import 'widget_service.dart';
import 'wird_habit_store.dart';

/// Outcome of a scheduling pass, surfaced in the notification centre.
class ScheduleResult {
  const ScheduleResult({
    required this.scheduled,
    required this.plan,
    required this.exactAlarms,
  });

  final int scheduled;
  final List<ScheduledNotification> plan;
  final bool exactAlarms;

  DateTime? get next => plan.isEmpty ? null : plan.first.time;

  static const ScheduleResult empty = ScheduleResult(
    scheduled: 0,
    plan: [],
    exactAlarms: true,
  );
}

/// Turns preferences + calculated prayer times into a concrete list of
/// notifications.
///
/// Pure and synchronous, so the notification centre can preview exactly what
/// the user will receive without touching the platform.
class NotificationPlanner {
  NotificationPlanner._();

  /// How many days ahead we schedule. Android keeps the alarms across reboots
  /// via the boot receiver; the app also reschedules on every launch.
  static const int horizonDays = 7;

  static const int _prayerIdBase = 1000;
  static const int _preAdhanIdBase = 2000;
  static const int _iqamaIdBase = 3000;
  static const int _morningAzkarIdBase = 4000;
  static const int _eveningAzkarIdBase = 4100;
  static const int _dailyAyahIdBase = 5000;
  static const int _wirdIdBase = 6000;
  static const int _eventIdBase = 7000;
  static const int _fridayIdBase = 7100;
  static const int _surahIdBase = 7200;
  static const int _fastingIdBase = 7200;

  static List<ScheduledNotification> build({
    required NotificationPreferences prefs,
    required List<ComputedPrayerDay> days,
    required DateTime now,
    required String languageCode,
    String? Function(DateTime date)? dailyAyahBody,
    String? Function(DateTime date)? dailyAyahReference,
    int maxItems = 200,
  }) {
    if (!prefs.masterEnabled) {
      return const [];
    }

    final items = <ScheduledNotification>[];

    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];

      for (
        var prayerIndex = 0;
        prayerIndex < PrayerIds.obligatory.length;
        prayerIndex++
      ) {
        final prayerId = PrayerIds.obligatory[prayerIndex];
        final mode = prefs.modeFor(prayerId);
        final time = day.timeOf(prayerId);
        if (time == null || !mode.isEnabled) {
          continue;
        }

        final prayerName = _prayerName(languageCode, prayerId);

        _add(
          items,
          now,
          ScheduledNotification(
            id: _prayerIdBase + dayIndex * 10 + prayerIndex,
            kind: NotificationKind.prayer,
            time: time,
            prayerId: prayerId,
            mode: mode,
            title: AppLocalizations.translate(
              languageCode,
              'notif_prayer_title',
              replacements: {'prayer': prayerName},
            ),
            body: AppLocalizations.translate(
              languageCode,
              'notif_prayer_body',
              replacements: {
                'prayer': prayerName,
                'time': formatClock(time, languageCode),
              },
            ),
            payload: 'prayer:$prayerId',
            adhanSound: prefs.soundForPrayer(prayerId),
            actions: [
              NotificationActionSpec(
                id: 'open_prayer',
                label: AppLocalizations.translate(languageCode, 'prayer_times'),
              ),
            ],
          ),
        );

        if (prefs.preAdhanMinutes > 0) {
          _add(
            items,
            now,
            ScheduledNotification(
              id: _preAdhanIdBase + dayIndex * 10 + prayerIndex,
              kind: NotificationKind.preAdhan,
              time: time.subtract(Duration(minutes: prefs.preAdhanMinutes)),
              prayerId: prayerId,
              mode: PrayerAlertMode.notification,
              title: AppLocalizations.translate(
                languageCode,
                'notif_pre_title',
                replacements: {'prayer': prayerName},
              ),
              body: AppLocalizations.translate(
                languageCode,
                'notif_pre_body',
                replacements: {
                  'prayer': prayerName,
                  'minutes': _number(prefs.preAdhanMinutes, languageCode),
                  'time': formatClock(time, languageCode),
                },
              ),
              payload: 'prayer:$prayerId',
            ),
          );
        }

        if (prefs.iqamaMinutes > 0) {
          _add(
            items,
            now,
            ScheduledNotification(
              id: _iqamaIdBase + dayIndex * 10 + prayerIndex,
              kind: NotificationKind.iqama,
              time: time.add(Duration(minutes: prefs.iqamaMinutes)),
              prayerId: prayerId,
              mode: PrayerAlertMode.notification,
              title: AppLocalizations.translate(
                languageCode,
                'notif_iqama_title',
                replacements: {'prayer': prayerName},
              ),
              body: AppLocalizations.translate(
                languageCode,
                'notif_iqama_body',
                replacements: {'prayer': prayerName},
              ),
              payload: 'prayer:$prayerId',
            ),
          );
        }
      }

      // Azkar follow the sun, not the clock.
      final fajr = day.timeOf(PrayerIds.fajr);
      if (prefs.morningAzkarEnabled && fajr != null) {
        final time = fajr.add(
          Duration(minutes: prefs.morningAzkarOffsetMinutes),
        );
        _add(
          items,
          now,
          ScheduledNotification(
            id: _morningAzkarIdBase + dayIndex,
            kind: NotificationKind.azkar,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(
              languageCode,
              'notif_morning_azkar_title',
            ),
            body: AppLocalizations.translate(
              languageCode,
              'notif_morning_azkar_body',
            ),
            payload: 'azkar:morning',
            actions: [
              NotificationActionSpec(
                id: 'open_azkar',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
            ],
          ),
        );
      }

      final asr = day.timeOf(PrayerIds.asr);
      if (prefs.eveningAzkarEnabled && asr != null) {
        final time = asr.add(
          Duration(minutes: prefs.eveningAzkarOffsetMinutes),
        );
        _add(
          items,
          now,
          ScheduledNotification(
            id: _eveningAzkarIdBase + dayIndex,
            kind: NotificationKind.azkar,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(
              languageCode,
              'notif_evening_azkar_title',
            ),
            body: AppLocalizations.translate(
              languageCode,
              'notif_evening_azkar_body',
            ),
            payload: 'azkar:evening',
            actions: [
              NotificationActionSpec(
                id: 'open_azkar',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
            ],
          ),
        );
      }

      if (prefs.dailyAyahEnabled) {
        final time = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          prefs.dailyAyahHour,
          prefs.dailyAyahMinute,
        );
        final verse = dailyAyahBody?.call(day.date);
        final reference = dailyAyahReference?.call(day.date);
        _add(
          items,
          now,
          ScheduledNotification(
            id: _dailyAyahIdBase + dayIndex,
            kind: NotificationKind.dailyAyah,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(
              languageCode,
              'notif_daily_ayah_title',
            ),
            body:
                verse ??
                AppLocalizations.translate(
                  languageCode,
                  'notif_daily_ayah_body',
                ),
            payload:
                reference == null
                    ? 'quran:ayah_of_the_day'
                    : 'quran:verse:$reference',
            actions: [
              NotificationActionSpec(
                id: 'open_ayah',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
              if (reference != null)
                NotificationActionSpec(
                  id: 'listen_ayah',
                  label: AppLocalizations.translate(languageCode, 'listen'),
                ),
            ],
          ),
        );
      }

      // Friday: Surah Al-Kahf, an hour after Fajr.
      if (prefs.fridayRemindersEnabled &&
          day.date.weekday == DateTime.friday &&
          fajr != null) {
        final time = fajr.add(const Duration(hours: 1));
        _add(
          items,
          now,
          ScheduledNotification(
            id: _fridayIdBase + dayIndex,
            kind: NotificationKind.dailyAyah,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(
              languageCode,
              'notif_friday_title',
            ),
            body: AppLocalizations.translate(languageCode, 'notif_friday_body'),
            payload: 'quran:verse:18:1',
            actions: [
              NotificationActionSpec(
                id: 'open_ayah',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
            ],
          ),
        );
      }

      // A surah worth reading today, and the narration that says why.
      if (prefs.surahRemindersEnabled) {
        final virtue = SurahVirtues.suggestionFor(day.date);
        final time = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          prefs.surahReminderHour,
        );
        _add(
          items,
          now,
          ScheduledNotification(
            id: _surahIdBase + dayIndex,
            kind: NotificationKind.dailyAyah,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(
              languageCode,
              'notif_surah_title',
              replacements: {'surah': virtue.nameAr},
            ),
            // The grade rides along with the text; a virtue quoted bare is a
            // virtue the reader has no way to weigh.
            body: virtue.virtueWithGradeAr,
            payload:
                'quran:verse:${virtue.surahNumber}:${virtue.fromAyah ?? 1}',
            actions: [
              NotificationActionSpec(
                id: 'open_ayah',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
            ],
          ),
        );
      }

      // Hijri occasions: Ashura, Arafah, the Eids, the white days.
      if (prefs.islamicEventsEnabled) {
        final events = HijriService.eventsOn(day.hijri.month, day.hijri.day);
        if (events.isNotEmpty) {
          final time = DateTime(day.date.year, day.date.month, day.date.day, 9);
          _add(
            items,
            now,
            ScheduledNotification(
              id: _eventIdBase + dayIndex,
              kind: NotificationKind.event,
              time: time,
              mode: _quietAware(prefs, time),
              title: AppLocalizations.translate(languageCode, events.first.key),
              body: AppLocalizations.translate(
                languageCode,
                events.first.isFasting
                    ? 'notif_event_fasting_body'
                    : 'notif_event_body',
              ),
              payload: 'calendar',
            ),
          );
        }
      }

      // The night before a fasting day.
      if (prefs.fastingRemindersEnabled) {
        final tomorrow = DateTime(
          day.date.year,
          day.date.month,
          day.date.day + 1,
        );
        final tomorrowHijri = HijriService.fromGregorian(tomorrow);
        final isWhiteDay = tomorrowHijri.hDay >= 13 && tomorrowHijri.hDay <= 15;

        if (HijriService.isRecommendedFastingWeekday(tomorrow) || isWhiteDay) {
          final time = DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
            21,
          );
          _add(
            items,
            now,
            ScheduledNotification(
              id: _fastingIdBase + dayIndex,
              kind: NotificationKind.event,
              time: time,
              mode: _quietAware(prefs, time),
              title: AppLocalizations.translate(
                languageCode,
                'notif_fasting_title',
              ),
              body: AppLocalizations.translate(
                languageCode,
                isWhiteDay ? 'notif_fasting_white_body' : 'notif_fasting_body',
              ),
              payload: 'calendar',
            ),
          );
        }
      }

      if (prefs.wirdEnabled) {
        final time = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          prefs.wirdHour,
          prefs.wirdMinute,
        );
        _add(
          items,
          now,
          ScheduledNotification(
            id: _wirdIdBase + dayIndex,
            kind: NotificationKind.wird,
            time: time,
            mode: _quietAware(prefs, time),
            title: AppLocalizations.translate(languageCode, 'notif_wird_title'),
            body: AppLocalizations.translate(languageCode, 'notif_wird_body'),
            payload: 'quran:wird',
            actions: [
              NotificationActionSpec(
                id: 'open_wird',
                label: AppLocalizations.translate(languageCode, 'open'),
              ),
            ],
          ),
        );
      }
    }

    items.sort((a, b) => a.time.compareTo(b.time));
    if (items.length > maxItems) {
      return items.sublist(0, maxItems);
    }
    return items;
  }

  static void _add(
    List<ScheduledNotification> items,
    DateTime now,
    ScheduledNotification item,
  ) {
    if (item.time.isAfter(now)) {
      items.add(item);
    }
  }

  /// Quiet hours mute the optional reminders; prayer alerts are never touched.
  static PrayerAlertMode _quietAware(
    NotificationPreferences prefs,
    DateTime time,
  ) {
    return prefs.isQuietHour(time.hour)
        ? PrayerAlertMode.silent
        : PrayerAlertMode.notification;
  }

  static String _prayerName(String languageCode, String prayerId) =>
      AppLocalizations.translate(languageCode, prayerId);

  /// 12-hour clock with a localized suffix, in the locale's digits.
  static String formatClock(DateTime time, String languageCode) {
    final isPm = time.hour >= 12;
    var hour = time.hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final suffix = AppLocalizations.translate(
      languageCode,
      isPm ? 'pm_short' : 'am_short',
    );
    final minutes = time.minute.toString().padLeft(2, '0');
    return '${_digits(hour.toString(), languageCode)}:'
        '${_digits(minutes, languageCode)} $suffix';
  }

  static String _number(int value, String languageCode) =>
      _digits(value.toString(), languageCode);

  static String _digits(String value, String languageCode) {
    if (languageCode != 'ar') {
      return value;
    }
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      final digit = int.tryParse(char);
      buffer.write(digit == null ? char : arabic[digit]);
    }
    return buffer.toString();
  }
}

/// Reads stored settings, computes the week ahead, and hands it to the
/// platform. Safe to call on every app launch and after any settings change.
class NotificationScheduler {
  NotificationScheduler._();

  static const double _fallbackLatitude = 31.0345728;
  static const double _fallbackLongitude = 30.4676864;

  /// Serializes refreshes. Two overlapping passes could otherwise cancel each
  /// other's freshly scheduled alarms, leaving the user with nothing queued.
  static Future<ScheduleResult>? _inFlight;

  /// Build the plan without scheduling it — used for the "what's next" preview.
  static Future<List<ScheduledNotification>> preview({
    SharedPreferences? preferences,
    NotificationPreferences? overrides,
    int maxItems = 200,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final settings = overrides ?? readPreferences(prefs);

    final days = PrayerCalculationService.computeRange(
      latitude:
          prefs.getDouble(AppConstants.userLatitudeKey) ?? _fallbackLatitude,
      longitude:
          prefs.getDouble(AppConstants.userLongitudeKey) ?? _fallbackLongitude,
      method: prefs.getInt(AppConstants.prayerMethodKey) ?? 3,
      days: NotificationPlanner.horizonDays,
      // Madhab, manual offsets, and the high-latitude rule move the times, so
      // reminders must be built from the same settings the screens use.
      settings: PrayerSettingsStore.read(prefs),
    );

    return NotificationPlanner.build(
      prefs: settings,
      days: days,
      now: DateTime.now(),
      languageCode: prefs.getString(AppConstants.localeKey) ?? 'ar',
      dailyAyahBody: _verseOfTheDay,
      dailyAyahReference: _verseOfTheDayReference,
      maxItems: maxItems,
    );
  }

  /// Cancel everything and schedule the next [NotificationPlanner.horizonDays].
  static Future<ScheduleResult> refresh({
    SharedPreferences? preferences,
    NotificationPreferences? overrides,
  }) async {
    final pending = _inFlight;
    if (pending != null) {
      await pending;
    }

    final run = _refresh(preferences: preferences, overrides: overrides);
    _inFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    }
  }

  static Future<ScheduleResult> _refresh({
    SharedPreferences? preferences,
    NotificationPreferences? overrides,
  }) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final settings = overrides ?? readPreferences(prefs);

      // The widget mirrors the same calculation, so refresh it here too.
      unawaited(WidgetService.refresh(preferences: prefs));

      if (!settings.masterEnabled) {
        await NotificationService.cancelAllScheduled();
        return ScheduleResult.empty;
      }

      final plan = await preview(
        preferences: prefs,
        overrides: withLearnedWirdTime(settings, prefs),
      );
      final scheduled = await NotificationService.replaceSchedule(plan);
      final exact = await NotificationService.canScheduleExactAlarms();

      return ScheduleResult(
        scheduled: scheduled,
        plan: plan,
        exactAlarms: exact,
      );
    } catch (e, stack) {
      AppLogger.error('Notification refresh failed', e, stack);
      return ScheduleResult.empty;
    }
  }

  /// Move the wird reminder to the hour this person actually reads in.
  ///
  /// Only when they asked for it, and only once there are enough sessions to
  /// mean something — otherwise the time they set themselves stands. A
  /// reminder that wanders on the evidence of two readings is worse than one
  /// that never moves.
  static NotificationPreferences withLearnedWirdTime(
    NotificationPreferences settings,
    SharedPreferences prefs,
  ) {
    if (!settings.wirdEnabled || !settings.wirdAdaptive) {
      return settings;
    }
    final suggestion = WirdHabitStore.suggestedTime(
      WirdHabitStore.readCounts(prefs),
    );
    if (suggestion == null) {
      return settings;
    }
    return settings.copyWith(
      wirdHour: suggestion.hour,
      wirdMinute: suggestion.minute,
    );
  }

  /// Persisted notification settings, migrating the legacy boolean map.
  static NotificationPreferences readPreferences(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.notificationPreferencesKey);
    if (raw != null && raw.isNotEmpty) {
      return NotificationPreferences.decode(raw);
    }

    return NotificationPreferences.decode(
      prefs.getString(AppConstants.prayerNotificationPrefsKey),
      legacyMaster: prefs.getBool(AppConstants.notificationsEnabledKey),
    );
  }

  static Future<void> savePreferences(
    SharedPreferences prefs,
    NotificationPreferences value,
  ) async {
    await prefs.setString(
      AppConstants.notificationPreferencesKey,
      value.encode(),
    );
    await prefs.setBool(
      AppConstants.notificationsEnabledKey,
      value.masterEnabled,
    );
  }

  /// `surah:verse` for the day, used as the notification payload so the
  /// action buttons can open (or play) that exact verse.
  static String? _verseOfTheDayReference(DateTime date) {
    try {
      final verse = QuranLocalService.verseOfTheDay(date);
      return '${verse.surahNumber}:${verse.numberInSurah}';
    } catch (_) {
      return null;
    }
  }

  static String? _verseOfTheDay(DateTime date) {
    try {
      final verse = QuranLocalService.verseOfTheDay(date);
      return '${verse.text}\n﴿${verse.surahNameAr} — ${verse.numberInSurah}﴾';
    } catch (_) {
      return null;
    }
  }
}
