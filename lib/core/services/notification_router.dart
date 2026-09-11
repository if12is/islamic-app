import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/azkar/presentation/pages/azkar_page.dart';
import '../../features/azkar/presentation/pages/salawat_page.dart';
import '../../features/prayer_times/data/prayer_log_store.dart';
import '../../features/prayer_times/presentation/pages/hijri_calendar_page.dart';
import '../../features/prayer_times/presentation/pages/prayer_times_page.dart';
import '../../features/prayer_times/presentation/widgets/prayer_log_sheet.dart';
import '../../features/quran/data/services/quran_local_service.dart';
import '../../features/quran/presentation/pages/surah_reader_page.dart';
import '../../features/quran/presentation/providers/bookmarks_provider.dart';
import '../../features/quran/presentation/providers/reading_history_provider.dart';
import '../localization/app_localizations.dart';
import '../utils/app_logger.dart';
import 'follow_up_reminders.dart';

/// Navigator used to open a screen from a notification tap or action.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Turns a notification payload into a screen.
///
/// Payload grammar (kept short because Android caps payload length):
/// * `prayer:<id>` — the prayer timetable
/// * `log:<prayer>:<yyyy-mm-dd>` — ask how that prayer was prayed
/// * `log:<prayer>:<yyyy-mm-dd>:<record>` — log it straight away (a button)
/// * `quran:verse:<surah>:<verse>` — the reader at that verse
/// * `quran:verse:<surah>:<verse>:play` — same, and start the recitation
/// * `quran:surah:<surah>` — the reader, resuming inside that surah
/// * `quran:wird` — the reader at the pinned wird, or where the user stopped
/// * `friday:kahf_done` — Al-Kahf is read; stop today's reminders
/// * `salawat` — the salawat counter
/// * `azkar:morning` / `azkar:evening` — the azkar screen
/// * `calendar` — the Hijri calendar
class NotificationRouter {
  NotificationRouter._();

  static String? _pending;

  /// Set once the home screen is up. Anything pushed before that — over the
  /// splash — was replaced along with the splash, so a notification that
  /// launched the app opened its screen and lost it half a second later.
  static bool _ready = false;

  /// Called by the home screen once it is showing.
  static void markReady() {
    _ready = true;
    flushPending();
  }

  /// Handle a payload now, or remember it until the navigator exists.
  ///
  /// [actionId] distinguishes the buttons under a notification. It is folded
  /// into the payload here, so a payload that has to wait for the app to
  /// start still knows which button was pressed.
  static void handle(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final resolved = resolve(payload, actionId);
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !_ready) {
      _pending = resolved;
      return;
    }

    AppLogger.info('Opening notification payload: $resolved');
    if (_act(resolved, navigator)) {
      return;
    }

    final page = _pageFor(resolved, navigator);
    if (page == null) {
      return;
    }
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// The payload with the pressed button folded in.
  static String resolve(String payload, String? actionId) {
    if (actionId == 'listen_ayah' && !payload.endsWith(':play')) {
      return '$payload:play';
    }
    if (actionId == 'kahf_done') {
      return 'friday:kahf_done';
    }
    if (actionId != null &&
        actionId.startsWith('log_') &&
        payload.startsWith('log:') &&
        payload.split(':').length == 3) {
      return '$payload:${actionId.substring(4)}';
    }
    return payload;
  }

  /// Called once the app is running, to open whatever launched it.
  static void flushPending() {
    final payload = _pending;
    if (payload == null || !_ready) {
      return;
    }
    _pending = null;
    handle(payload);
  }

  /// Payloads that do something rather than open a page.
  static bool _act(String payload, NavigatorState navigator) {
    final parts = payload.split(':');
    final context = navigator.overlay?.context ?? navigator.context;

    switch (parts.first) {
      case 'log':
        _prayerLog(parts, context);
        return true;
      case 'friday' when parts.length > 1 && parts[1] == 'kahf_done':
        unawaited(_kahfDone(context));
        return true;
      default:
        return false;
    }
  }

  /// `log:fajr:2026-09-11` asks; `log:fajr:2026-09-11:mosque` answers.
  static void _prayerLog(List<String> parts, BuildContext context) {
    if (parts.length < 3 || !PrayerLogStore.prayerIds.contains(parts[1])) {
      return;
    }
    final prayerId = parts[1];
    final date = DateTime.tryParse(parts[2]) ?? DateTime.now();

    if (parts.length < 4) {
      unawaited(PrayerLogSheet.show(context, prayerId: prayerId, date: date));
      return;
    }

    final record = PrayerRecord.values.where((r) => r.name == parts[3]);
    if (record.isEmpty || !record.first.isPrayed) {
      return;
    }
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      await PrayerLogSheet.record(
        prefs,
        prayerId: prayerId,
        date: date,
        record: record.first,
      );
      if (context.mounted) {
        PrayerLogSheet.confirm(
          context,
          prayerId: prayerId,
          record: record.first,
        );
      }
    }());
  }

  static Future<void> _kahfDone(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await FollowUpReminders.kahfRead(prefs);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.tr('kahf_marked_read'))),
    );
  }

  static Widget? _pageFor(String payload, NavigatorState navigator) {
    final parts = payload.split(':');
    if (parts.isEmpty) {
      return null;
    }

    switch (parts.first) {
      case 'prayer':
        return const PrayerTimesPage();
      case 'calendar':
        return const HijriCalendarPage();
      case 'azkar':
        return const AzkarPage();
      case 'salawat':
        return const SalawatPage();
      case 'quran':
        return _quranPageFor(parts, navigator);
      default:
        return null;
    }
  }

  static Widget? _quranPageFor(List<String> parts, NavigatorState navigator) {
    if (parts.length >= 4 && parts[1] == 'verse') {
      final surah = int.tryParse(parts[2]);
      final verse = int.tryParse(parts[3]);
      if (surah == null || verse == null) {
        return null;
      }
      return SurahReaderPage(
        surahNumber: surah,
        initialVerse: verse,
        autoPlay: parts.length > 4 && parts[4] == 'play',
      );
    }

    if (parts.length >= 3 && parts[1] == 'surah') {
      final surah = int.tryParse(parts[2]);
      if (surah == null || surah < 1 || surah > QuranLocalService.surahCount) {
        return null;
      }
      // No verse: the reader picks up wherever the last reading of this
      // surah stopped, or opens it at the start.
      return SurahReaderPage(surahNumber: surah);
    }

    if (parts.length >= 2 && parts[1] == 'wird') {
      // This opened Al-Fatiha, whatever the reader had been reading. The wird
      // is the line pinned in the reading history, or the last place read.
      final container = ProviderScope.containerOf(
        navigator.context,
        listen: false,
      );
      final resume = resumeForWird(
        container.read(lastReadProvider),
        container.read(readingHistoryProvider),
      );
      return SurahReaderPage(
        surahNumber: resume?.surah ?? 1,
        initialVerse: resume?.verse,
        historyId: resume?.historyId,
      );
    }

    // Fall back to the verse of the day.
    final verse = QuranLocalService.verseOfTheDay(DateTime.now());
    return SurahReaderPage(
      surahNumber: verse.surahNumber,
      initialVerse: verse.numberInSurah,
    );
  }
}
