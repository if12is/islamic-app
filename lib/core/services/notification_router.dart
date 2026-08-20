import 'package:flutter/material.dart';

import '../../features/azkar/presentation/pages/azkar_page.dart';
import '../../features/prayer_times/presentation/pages/hijri_calendar_page.dart';
import '../../features/prayer_times/presentation/pages/prayer_times_page.dart';
import '../../features/quran/data/services/quran_local_service.dart';
import '../../features/quran/presentation/pages/surah_reader_page.dart';
import '../utils/app_logger.dart';

/// Navigator used to open a screen from a notification tap or action.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Turns a notification payload into a screen.
///
/// Payload grammar (kept short because Android caps payload length):
/// * `prayer:<id>` — the prayer timetable
/// * `quran:verse:<surah>:<verse>` — the reader at that verse
/// * `quran:verse:<surah>:<verse>:play` — same, and start the recitation
/// * `quran:wird` — the reader where the user stopped
/// * `azkar:morning` / `azkar:evening` — the azkar screen
/// * `calendar` — the Hijri calendar
class NotificationRouter {
  NotificationRouter._();

  static String? _pending;

  /// Handle a payload now, or remember it until the navigator exists.
  ///
  /// [actionId] distinguishes the buttons under a notification; "listen"
  /// resolves to the same verse with playback started.
  static void handle(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final resolved =
        actionId == 'listen_ayah' && !payload.endsWith(':play')
            ? '$payload:play'
            : payload;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pending = resolved;
      return;
    }

    final page = _pageFor(resolved);
    if (page == null) {
      return;
    }

    AppLogger.info('Opening notification payload: $resolved');
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Called once the app is running, to open whatever launched it.
  static void flushPending() {
    final payload = _pending;
    if (payload == null) {
      return;
    }
    _pending = null;
    handle(payload);
  }

  static Widget? _pageFor(String payload) {
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
      case 'quran':
        return _quranPageFor(parts);
      default:
        return null;
    }
  }

  static Widget? _quranPageFor(List<String> parts) {
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

    if (parts.length >= 2 && parts[1] == 'wird') {
      return const SurahReaderPage(surahNumber: 1);
    }

    // Fall back to the verse of the day.
    final verse = QuranLocalService.verseOfTheDay(DateTime.now());
    return SurahReaderPage(
      surahNumber: verse.surahNumber,
      initialVerse: verse.numberInSurah,
    );
  }
}
