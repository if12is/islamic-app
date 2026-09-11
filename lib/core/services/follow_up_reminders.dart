import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/prayer_times/data/prayer_log_store.dart';
import '../utils/app_logger.dart';
import 'friday_progress.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

/// The reminders that keep asking until something is done, told the moment
/// it is.
///
/// A follow-up that goes on asking about a prayer already logged, or a surah
/// already read, teaches people to swipe the app's notifications away unread
/// — the adhan with them. So each event cancels the rest of its own series
/// straight away, sent and pending alike, rather than waiting for the next
/// time the week is rescheduled.
class FollowUpReminders {
  FollowUpReminders._();

  static Timer? _refreshSoon;

  /// A prayer's log changed. Logged: stop asking about it today. Cleared:
  /// put the asks back.
  static Future<void> prayerLogged(
    DateTime date,
    String prayerId,
    PrayerRecord record, {
    DateTime? now,
  }) async {
    if (!record.isPrayed) {
      _rescheduleSoon();
      return;
    }
    // Id slots come round every eight days, so a day two or more back shares
    // its slot with one still ahead. Logging an old notification that sat in
    // the shade must not silence next week's Isha.
    if (!_isTodayOrYesterday(date, now ?? DateTime.now())) {
      return;
    }
    await _cancel(NotificationPlanner.prayerLogIds(date, prayerId));
  }

  static bool _isTodayOrYesterday(DateTime date, DateTime now) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    final back = today.difference(day).inDays;
    return back == 0 || back == 1;
  }

  /// Al-Kahf has been read today, by the reading log or by the reader's word.
  static Future<void> kahfRead(SharedPreferences prefs, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    await FridayProgress.markKahfRead(prefs, today);
    await _cancel(NotificationPlanner.kahfIds(today));
  }

  /// A page was read. On a Friday, see whether Al-Kahf is now done.
  static Future<void> pageRead(
    SharedPreferences prefs,
    int page,
    Set<int> pagesReadToday, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    if (!FridayProgress.isFriday(today) ||
        !FridayProgress.kahfPages().contains(page) ||
        FridayProgress.isKahfRead(prefs, today)) {
      return;
    }
    if (FridayProgress.kahfCovered(pagesReadToday)) {
      await kahfRead(prefs, now: today);
    }
  }

  /// A salawat was counted. On a Friday, stop the reminders at the goal.
  static Future<void> salawatCounted(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final key = FridayProgress.dayKey(today);
    // Once a day is enough; every tap after the hundredth would otherwise
    // cancel the same ten ids again.
    if (_salawatClosedFor == key ||
        !FridayProgress.isFriday(today) ||
        !FridayProgress.isSalawatDone(prefs, today)) {
      return;
    }
    _salawatClosedFor = key;
    await _cancel(NotificationPlanner.fridaySalawatIds(today));
  }

  static String? _salawatClosedFor;

  static Future<void> _cancel(List<int> ids) async {
    if (kIsWeb || ids.isEmpty) {
      return;
    }
    try {
      // A pass that began before this was done planned it as not done, and
      // would queue these again behind the cancel. The launch that a
      // notification button causes starts exactly such a pass.
      await NotificationScheduler.whenIdle();
      await NotificationService.cancelMany(ids);
    } catch (e) {
      // No plugin (tests, a desktop build): nothing is queued to cancel.
      AppLogger.warning('Could not cancel follow-up reminders: $e');
    }
  }

  /// Un-logging is rare and usually a mis-tap in the middle of cycling
  /// through the options, so the week is rebuilt once the taps settle rather
  /// than on each of them.
  static void _rescheduleSoon() {
    if (kIsWeb) {
      return;
    }
    _refreshSoon?.cancel();
    _refreshSoon = Timer(const Duration(seconds: 3), () {
      unawaited(NotificationScheduler.refresh());
    });
  }
}
