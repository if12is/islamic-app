import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/prayer_times/data/prayer_log_store.dart';
import '../../features/quran/data/services/quran_local_service.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'friday_progress.dart';
import 'hijri_service.dart';
import 'surah_virtues.dart';
import 'notification_service.dart';
import 'prayer_calculation_service.dart';
import 'prayer_settings_store.dart';
import 'widget_service.dart';
import 'wird_habit_store.dart';
import '../utils/arabic_numerals.dart';

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

  /// Enough for a week with every reminder switched on (a little over 200),
  /// and well under the 500 alarms Android allows one app.
  static const int defaultMaxItems = 300;

  static const int _prayerIdBase = 1000;
  static const int _preAdhanIdBase = 2000;
  static const int _iqamaIdBase = 3000;
  static const int _morningAzkarIdBase = 4000;
  static const int _eveningAzkarIdBase = 4100;
  static const int _dailyAyahIdBase = 5000;
  static const int _wirdIdBase = 6000;
  static const int _eventIdBase = 7000;
  static const int _surahIdBase = 7200;
  // This was 7200 as well, so on a day with both a surah suggestion and a
  // fasting reminder one silently replaced the other.
  static const int _fastingIdBase = 7300;

  // The follow-up series are numbered by date rather than by position in the
  // plan, so the app can cancel "the rest of today's Fajr asks" the moment
  // Fajr is logged, without rebuilding the week to find out which ids those
  // were. Eight slots cover the seven-day horizon with no two days sharing.
  static const int _prayerLogIdBase = 8000;
  static const int _kahfIdBase = 8400;
  static const int _fridaySalawatIdBase = 8500;

  /// Room for the first ask plus every follow-up allowed.
  static const int _prayerLogSlots =
      NotificationPreferences.maxPrayerLogFollowUps + 1;
  static const int _fridaySlots = 10;

  /// How far apart the follow-up asks about one prayer are.
  static const Duration prayerLogGap = Duration(hours: 2);

  /// Days of the horizon that get prayer-log asks: today and the next two.
  ///
  /// Not the whole week. The notification plugin rewrites its entire stored
  /// schedule on the main thread for every alarm it adds, so the cost of a
  /// pass grows with the square of its length, and a week of asks would
  /// nearly triple it. Every launch, and every return to the app on a new
  /// day, plans three days on from there, so anyone answering them never
  /// runs out; someone who has ignored the app for three days stops being
  /// asked, and keeps every adhan.
  static const int prayerLogHorizonDays = 3;

  /// 0–7, different for every day in any run of eight.
  static int daySlot(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay %
      8;

  /// Every id today's asks about [prayerId] can have, sent or still pending.
  static List<int> prayerLogIds(DateTime date, String prayerId) {
    final prayerIndex = PrayerIds.obligatory.indexOf(prayerId);
    if (prayerIndex < 0) {
      return const [];
    }
    final base = _prayerLogIdBase + daySlot(date) * 50 + prayerIndex * 10;
    return [for (var i = 0; i < _prayerLogSlots; i++) base + i];
  }

  static List<int> kahfIds(DateTime date) {
    final base = _kahfIdBase + daySlot(date) * 10;
    return [for (var i = 0; i < _fridaySlots; i++) base + i];
  }

  static List<int> fridaySalawatIds(DateTime date) {
    final base = _fridaySalawatIdBase + daySlot(date) * 10;
    return [for (var i = 0; i < _fridaySlots; i++) base + i];
  }

  /// `log:fajr:2026-09-11` — which prayer, on which day.
  static String prayerLogPayload(String prayerId, DateTime date) =>
      'log:$prayerId:${_dayKey(date)}';

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// [isPrayerLogged], [isKahfRead] and [isSalawatDone] say what has already
  /// been done, so a series that would only nag about it is never queued.
  static List<ScheduledNotification> build({
    required NotificationPreferences prefs,
    required List<ComputedPrayerDay> days,
    required DateTime now,
    required String languageCode,
    String? Function(DateTime date)? dailyAyahBody,
    String? Function(DateTime date)? dailyAyahReference,
    bool Function(DateTime date, String prayerId)? isPrayerLogged,
    bool Function(DateTime date)? isKahfRead,
    bool Function(DateTime date)? isSalawatDone,
    int maxItems = defaultMaxItems,
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
        if (time == null) {
          continue;
        }

        final prayerName = _prayerName(languageCode, prayerId);

        // Asked whether or not the adhan itself is on: someone who has the
        // adhan from the mosque down the road still wants the log kept.
        if (prefs.prayerLogRemindersEnabled &&
            dayIndex < prayerLogHorizonDays &&
            !(isPrayerLogged?.call(day.date, prayerId) ?? false)) {
          _addPrayerLogAsks(
            items,
            now,
            prefs: prefs,
            day: day,
            prayerId: prayerId,
            prayerName: prayerName,
            adhan: time,
            languageCode: languageCode,
          );
        }

        if (!mode.isEnabled) {
          continue;
        }

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

      // Friday: Al-Kahf and salawat, through the day, until each is done.
      if (day.date.weekday == DateTime.friday) {
        if (prefs.kahfRemindersEnabled &&
            !(isKahfRead?.call(day.date) ?? false)) {
          _addKahfAsks(items, now, prefs: prefs, day: day, lang: languageCode);
        }
        if (prefs.fridaySalawatEnabled &&
            !(isSalawatDone?.call(day.date) ?? false)) {
          _addSalawatAsks(
            items,
            now,
            prefs: prefs,
            day: day,
            lang: languageCode,
          );
        }
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

  /// "How did you pray Fajr?" — first once there has been time to pray, then
  /// every [prayerLogGap] while it is still not logged, never past midnight.
  ///
  /// Every ask about one prayer on one day shares an id family, so logging it
  /// cancels the lot — the ones already in the shade as well as the ones not
  /// yet sent.
  static void _addPrayerLogAsks(
    List<ScheduledNotification> items,
    DateTime now, {
    required NotificationPreferences prefs,
    required ComputedPrayerDay day,
    required String prayerId,
    required String prayerName,
    required DateTime adhan,
    required String languageCode,
  }) {
    final ids = prayerLogIds(day.date, prayerId);
    final endOfDay = DateTime(
      day.date.year,
      day.date.month,
      day.date.day,
      23,
      59,
    );
    final payload = prayerLogPayload(prayerId, day.date);

    var at = adhan.add(Duration(minutes: prefs.prayerLogDelayMinutes));
    for (var ask = 0; ask <= prefs.prayerLogFollowUps; ask++) {
      if (at.isAfter(endOfDay) || ask >= ids.length) {
        break;
      }
      _add(
        items,
        now,
        ScheduledNotification(
          id: ids[ask],
          kind: NotificationKind.prayerLog,
          time: at,
          mode: _quietAware(prefs, at),
          prayerId: prayerId,
          title: AppLocalizations.translate(
            languageCode,
            'notif_log_title',
            replacements: {'prayer': prayerName},
          ),
          body: AppLocalizations.translate(
            languageCode,
            ask == 0 ? 'notif_log_body' : 'notif_log_again_body',
            replacements: {'prayer': prayerName},
          ),
          payload: payload,
          actions: [
            for (final record in const ['mosque', 'alone', 'missed'])
              NotificationActionSpec(
                id: 'log_$record',
                label: AppLocalizations.translate(
                  languageCode,
                  'prayer_log_$record',
                ),
              ),
          ],
        ),
      );
      at = at.add(prayerLogGap);
    }
  }

  /// Al-Kahf through Friday: after Fajr, before and after Jumu'ah, after Asr,
  /// and a last one before Maghrib. The moment it has been read the rest are
  /// cancelled, so reading it after the first leaves the day quiet.
  static void _addKahfAsks(
    List<ScheduledNotification> items,
    DateTime now, {
    required NotificationPreferences prefs,
    required ComputedPrayerDay day,
    required String lang,
  }) {
    final times = _spaced([
      day.timeOf(PrayerIds.fajr)?.add(const Duration(minutes: 60)),
      day.timeOf(PrayerIds.dhuhr)?.subtract(const Duration(minutes: 90)),
      day.timeOf(PrayerIds.dhuhr)?.add(const Duration(minutes: 75)),
      day.timeOf(PrayerIds.asr)?.add(const Duration(minutes: 30)),
      day.timeOf(PrayerIds.maghrib)?.subtract(const Duration(minutes: 40)),
    ]);
    final ids = kahfIds(day.date);

    for (var ask = 0; ask < times.length && ask < ids.length; ask++) {
      final time = times[ask];
      final bodyKey =
          ask == 0
              ? 'notif_kahf_body'
              : ask == times.length - 1
              ? 'notif_kahf_last_body'
              : 'notif_kahf_again_body';
      _add(
        items,
        now,
        ScheduledNotification(
          id: ids[ask],
          kind: NotificationKind.friday,
          time: time,
          mode: _quietAware(prefs, time),
          title: AppLocalizations.translate(lang, 'notif_kahf_title'),
          body: AppLocalizations.translate(lang, bodyKey),
          payload: 'quran:surah:18',
          actions: [
            NotificationActionSpec(
              id: 'open_kahf',
              label: AppLocalizations.translate(lang, 'notif_kahf_read'),
            ),
            NotificationActionSpec(
              id: 'kahf_done',
              label: AppLocalizations.translate(lang, 'notif_kahf_done'),
            ),
          ],
        ),
      );
    }
  }

  /// Salawat upon the Prophet ﷺ through Friday, until the day's count on the
  /// salawat counter reaches its goal.
  static void _addSalawatAsks(
    List<ScheduledNotification> items,
    DateTime now, {
    required NotificationPreferences prefs,
    required ComputedPrayerDay day,
    required String lang,
  }) {
    final times = _spaced([
      day.timeOf(PrayerIds.fajr)?.add(const Duration(minutes: 120)),
      day.timeOf(PrayerIds.dhuhr)?.subtract(const Duration(minutes: 40)),
      day.timeOf(PrayerIds.asr)?.subtract(const Duration(minutes: 45)),
      day.timeOf(PrayerIds.maghrib)?.add(const Duration(minutes: 20)),
    ]);
    final ids = fridaySalawatIds(day.date);

    for (var ask = 0; ask < times.length && ask < ids.length; ask++) {
      final time = times[ask];
      _add(
        items,
        now,
        ScheduledNotification(
          id: ids[ask],
          kind: NotificationKind.friday,
          time: time,
          mode: _quietAware(prefs, time),
          title: AppLocalizations.translate(lang, 'notif_salawat_title'),
          body: AppLocalizations.translate(
            lang,
            ask == 0 ? 'notif_salawat_body' : 'notif_salawat_again_body',
          ),
          payload: 'salawat',
          actions: [
            NotificationActionSpec(
              id: 'open_salawat',
              label: AppLocalizations.translate(lang, 'notif_salawat_open'),
            ),
          ],
        ),
      );
    }
  }

  /// The times in order, with any that land within twenty minutes of the one
  /// before dropped — on a short winter day two anchors can fall together,
  /// and two of the same reminder at once is one too many.
  static List<DateTime> _spaced(List<DateTime?> candidates) {
    final spaced = <DateTime>[];
    for (final time in candidates.whereType<DateTime>()) {
      if (spaced.isEmpty ||
          time.difference(spaced.last) >= const Duration(minutes: 20)) {
        spaced.add(time);
      }
    }
    return spaced;
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

  static String _digits(String value, String languageCode) =>
      localizeDigitsFor(languageCode, value);
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
    int maxItems = NotificationPlanner.defaultMaxItems,
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
      // What is already done is not asked about again.
      isPrayerLogged:
          (date, prayerId) =>
              PrayerLogStore.read(prefs, date).recordFor(prayerId).isPrayed,
      isKahfRead: (date) => FridayProgress.isKahfRead(prefs, date),
      isSalawatDone: (date) => FridayProgress.isSalawatDone(prefs, date),
      maxItems: maxItems,
    );
  }

  /// Cancel everything and schedule the next [NotificationPlanner.horizonDays].
  ///
  /// Each call runs after the one before it, in a chain. It used to wait on a
  /// snapshot of the pass in flight, so two callers waiting on the same pass
  /// both started together once it finished, and cancelled each other's work.
  static Future<ScheduleResult> refresh({
    SharedPreferences? preferences,
    NotificationPreferences? overrides,
  }) {
    final previous = _inFlight;
    final run = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // The pass before failing is no reason for this one not to run.
        }
      }
      return _refresh(preferences: preferences, overrides: overrides);
    }();
    _inFlight = run;
    unawaited(
      run
          .whenComplete(() {
            if (identical(_inFlight, run)) {
              _inFlight = null;
            }
          })
          .catchError((Object _) => ScheduleResult.empty),
    );
    return run;
  }

  /// The day the last pass ran, so a return to the app can tell whether the
  /// plan it left behind has started to run short.
  static DateTime? _lastPlannedDay;

  /// Re-plan if the last pass was on an earlier day.
  ///
  /// An app kept alive in the background is never launched again, and a plan
  /// made on Monday runs out of prayer-log asks by Thursday. Coming back to
  /// the app on a new day slides the window forward.
  static Future<void> refreshIfStale({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final last = _lastPlannedDay;
    if (last != null &&
        last.year == today.year &&
        last.month == today.month &&
        last.day == today.day) {
      return;
    }
    await refresh();
  }

  /// Completes once no scheduling pass is running or queued.
  ///
  /// A pass plans the week from what is stored when it starts. One already
  /// under way when a prayer is logged will queue that prayer's asks again
  /// after they have been cancelled, so whoever cancels waits for it first.
  static Future<void> whenIdle() async {
    while (true) {
      final pending = _inFlight;
      if (pending == null) {
        return;
      }
      try {
        await pending;
      } catch (_) {
        // Finished is finished, however it went.
      }
      if (identical(_inFlight, pending)) {
        return;
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
        _lastPlannedDay = DateTime.now();
        return ScheduleResult.empty;
      }

      final plan = await preview(
        preferences: prefs,
        overrides: withLearnedWirdTime(settings, prefs),
      );
      final scheduled = await NotificationService.replaceSchedule(plan);
      _lastPlannedDay = DateTime.now();
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
