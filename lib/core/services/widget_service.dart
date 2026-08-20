import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../utils/app_logger.dart';
import 'notification_scheduler.dart';
import 'prayer_calculation_service.dart';
import 'prayer_settings_store.dart';

/// Keeps the home-screen widget in step with the app.
///
/// The widget shows the next prayer and today's timetable; both come from the
/// same on-device calculation the app uses, so the widget stays correct even
/// with no network.
class WidgetService {
  WidgetService._();

  static const String _androidWidget = 'PrayerWidgetProvider';

  static const double _fallbackLatitude = 31.0345728;
  static const double _fallbackLongitude = 30.4676864;

  /// Recompute today's times and push them to the widget.
  static Future<void> refresh({SharedPreferences? preferences}) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final languageCode = prefs.getString(AppConstants.localeKey) ?? 'ar';

      final day = PrayerCalculationService.computeDay(
        latitude:
            prefs.getDouble(AppConstants.userLatitudeKey) ?? _fallbackLatitude,
        longitude:
            prefs.getDouble(AppConstants.userLongitudeKey) ??
            _fallbackLongitude,
        method: prefs.getInt(AppConstants.prayerMethodKey) ?? 3,
        settings: PrayerSettingsStore.read(prefs),
      );

      final now = DateTime.now();
      final next = _nextPrayer(day, now);

      await HomeWidget.saveWidgetData<String>(
        'next_label',
        AppLocalizations.translate(languageCode, 'next_prayer'),
      );
      await HomeWidget.saveWidgetData<String>(
        'next_name',
        AppLocalizations.translate(languageCode, next?.id ?? 'fajr'),
      );
      await HomeWidget.saveWidgetData<String>(
        'next_time',
        next == null
            ? '--:--'
            : NotificationPlanner.formatClock(next.time, languageCode),
      );
      await HomeWidget.saveWidgetData<String>(
        'countdown',
        next == null ? '' : _countdownLabel(next.time, now, languageCode),
      );
      await HomeWidget.saveWidgetData<String>(
        'hijri',
        '${day.hijri.day} ${day.hijri.monthNameAr} ${day.hijri.year}',
      );

      for (final id in PrayerIds.obligatory) {
        final time = day.timeOf(id);
        await HomeWidget.saveWidgetData<String>(
          '${id}_label',
          AppLocalizations.translate(languageCode, id),
        );
        await HomeWidget.saveWidgetData<String>(
          '${id}_time',
          time == null
              ? '--:--'
              : NotificationPlanner.formatClock(time, languageCode),
        );
      }

      await HomeWidget.updateWidget(
        name: _androidWidget,
        androidName: _androidWidget,
        iOSName: _androidWidget,
      );
    } catch (e, stack) {
      // A missing widget is not an error worth surfacing to the user.
      AppLogger.warning('Home widget refresh skipped: $e');
      AppLogger.debug(stack.toString());
    }
  }

  /// Next prayer today, or tomorrow's Fajr once Isha has passed.
  static ComputedPrayer? _nextPrayer(ComputedPrayerDay day, DateTime now) {
    for (final id in PrayerIds.obligatory) {
      final time = day.timeOf(id);
      if (time != null && time.isAfter(now)) {
        return ComputedPrayer(id: id, time: time);
      }
    }

    final fajr = day.timeOf(PrayerIds.fajr);
    if (fajr == null) {
      return null;
    }
    return ComputedPrayer(
      id: PrayerIds.fajr,
      time: fajr.add(const Duration(days: 1)),
    );
  }

  static String _countdownLabel(
    DateTime time,
    DateTime now,
    String languageCode,
  ) {
    final remaining = time.difference(now);
    if (remaining.isNegative) {
      return '';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return AppLocalizations.translate(
      languageCode,
      hours > 0 ? 'widget_in_hours' : 'widget_in_minutes',
      replacements: {'hours': hours.toString(), 'minutes': minutes.toString()},
    );
  }
}
