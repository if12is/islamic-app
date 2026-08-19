import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/notification_preferences.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/services/prayer_calculation_service.dart';
import '../../core/services/prayer_settings_store.dart';
import '../../core/services/startup_sync_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/input_validators.dart';

/// State notifier for theme mode management.
///
/// Manages switching between light and dark themes and persists the user's preference.
/// Manages switching between light and dark themes and persists the preference.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final savedTheme = _globalPrefs.getString(AppConstants.themeModeKey);
    if (savedTheme == null) {
      return ThemeMode.dark;
    }
    return ThemeMode.values.firstWhere(
      (mode) => mode.toString() == savedTheme,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> toggleTheme() async {
    final newTheme =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setTheme(newTheme);
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;
    await _globalPrefs.setString(AppConstants.themeModeKey, themeMode.toString());
    AppLogger.info('Theme changed to: $themeMode');
  }
}

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// Provider for theme mode state management.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Temporary global SharedPreferences instance for initialization
late SharedPreferences _globalPrefs;

/// Initialize global SharedPreferences for theme provider.
/// Call this in main() before running the app.
Future<void> initializeThemeProvider() async {
  _globalPrefs = await SharedPreferences.getInstance();
}

/// The already-open preferences instance.
///
/// Lets notifiers build their initial state synchronously instead of flashing
/// defaults for a frame while an async read completes.
SharedPreferences get appPreferences => _globalPrefs;

class UserCoordinates {
  final double latitude;
  final double longitude;

  const UserCoordinates({required this.latitude, required this.longitude});
}

const UserCoordinates _fallbackCoordinates = UserCoordinates(
  latitude: 31.0345728,
  longitude: 30.4676864,
);

/// Provider for the best available user location.
///
/// Priority:
/// 1. Fresh GPS location (when permission/service are available)
/// 2. Last saved coordinates in SharedPreferences
/// 3. Safe fallback coordinates
final currentLocationCoordinatesProvider = FutureProvider<UserCoordinates>((
  ref,
) async {
  final savedLatitude = _globalPrefs.getDouble(AppConstants.userLatitudeKey);
  final savedLongitude = _globalPrefs.getDouble(AppConstants.userLongitudeKey);

  final hasSaved = savedLatitude != null && savedLongitude != null;
  final savedCoordinates =
      hasSaved
          ? UserCoordinates(latitude: savedLatitude, longitude: savedLongitude)
          : null;

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return savedCoordinates ?? _fallbackCoordinates;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return savedCoordinates ?? _fallbackCoordinates;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );

    final movedFar =
        savedCoordinates == null ||
        (savedCoordinates.latitude - position.latitude).abs() > 0.05 ||
        (savedCoordinates.longitude - position.longitude).abs() > 0.05;

    await _globalPrefs.setDouble(
      AppConstants.userLatitudeKey,
      position.latitude,
    );
    await _globalPrefs.setDouble(
      AppConstants.userLongitudeKey,
      position.longitude,
    );

    // A new city means new prayer times, so re-arm the week's reminders.
    if (movedFar) {
      unawaited(NotificationScheduler.refresh(preferences: _globalPrefs));
    }

    return UserCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (_) {
    return savedCoordinates ?? _fallbackCoordinates;
  }
});

bool _startupSyncCompleted = false;
bool _startupSyncInProgress = false;

/// Run startup cache warm-up once per app session.
Future<void> runStartupSync({bool force = false}) async {
  if (_startupSyncInProgress) {
    return;
  }

  if (_startupSyncCompleted && !force) {
    return;
  }

  _startupSyncInProgress = true;

  try {
    await StartupSyncService.warmCaches(prefs: _globalPrefs);
    _startupSyncCompleted = true;
  } catch (e) {
    AppLogger.warning('Startup sync failed: $e');
  } finally {
    _startupSyncInProgress = false;
  }
}

/// Notifier for prayer calculation method selection.
class PrayerMethodNotifier extends Notifier<int> {
  @override
  int build() {
    return _globalPrefs.getInt(AppConstants.prayerMethodKey) ?? 3;
  }

  Future<void> setMethod(int method) async {
    state = method;
    await _globalPrefs.setInt(AppConstants.prayerMethodKey, method);
    AppLogger.info('Prayer method changed to: $method');

    // Prayer times just moved, so the queued reminders are stale.
    await NotificationScheduler.refresh(preferences: _globalPrefs);
  }
}

final prayerMethodProvider =
    NotifierProvider<PrayerMethodNotifier, int>(PrayerMethodNotifier.new);

/// Madhab, manual per-prayer offsets, high-latitude rule, and the Hijri
/// correction. Any change re-arms the notification schedule, because the
/// prayer times it was built from have just moved.
class PrayerCalculationSettingsNotifier
    extends Notifier<PrayerCalculationSettings> {
  @override
  PrayerCalculationSettings build() => PrayerSettingsStore.read(_globalPrefs);

  Future<void> update(PrayerCalculationSettings next) async {
    state = next;
    await PrayerSettingsStore.write(_globalPrefs, next);
    await NotificationScheduler.refresh(preferences: _globalPrefs);
    AppLogger.info('Prayer calculation settings updated');
  }

  Future<void> setHanafiAsr(bool value) =>
      update(state.copyWith(hanafiAsr: value));

  Future<void> setHighLatitudeRule(HighLatitudeRule rule) =>
      update(state.copyWith(highLatitudeRule: rule));

  Future<void> setHijriOffset(int days) =>
      update(state.copyWith(hijriOffsetDays: days));

  Future<void> setOffset(String prayerId, int minutes) {
    final offsets = Map<String, int>.from(state.minuteAdjustments);
    if (minutes == 0) {
      offsets.remove(prayerId);
    } else {
      offsets[prayerId] = minutes;
    }
    return update(state.copyWith(minuteAdjustments: offsets));
  }

  Future<void> resetOffsets() =>
      update(state.copyWith(minuteAdjustments: const {}));
}

final prayerCalculationSettingsProvider =
    NotifierProvider<
      PrayerCalculationSettingsNotifier,
      PrayerCalculationSettings
    >(PrayerCalculationSettingsNotifier.new);

/// Single source of truth for every reminder the app schedules.
///
/// Any change persists immediately and reschedules the next seven days, so
/// what the user sees in the notification centre is always what the platform
/// will actually deliver.
class NotificationPreferencesNotifier extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    return NotificationScheduler.readPreferences(_globalPrefs);
  }

  Future<ScheduleResult> update(NotificationPreferences next) async {
    state = next;
    await NotificationScheduler.savePreferences(_globalPrefs, next);
    final result = await NotificationScheduler.refresh(
      preferences: _globalPrefs,
      overrides: next,
    );
    AppLogger.info('Notification settings saved (${result.scheduled} queued)');
    return result;
  }

  Future<ScheduleResult> setMasterEnabled(bool enabled) =>
      update(state.copyWith(masterEnabled: enabled));

  Future<ScheduleResult> setPrayerMode(String prayerId, PrayerAlertMode mode) {
    final modes = Map<String, PrayerAlertMode>.from(state.prayerModes);
    modes[prayerId] = mode;
    return update(state.copyWith(prayerModes: modes));
  }

  /// Quick on/off used by the compact settings card.
  Future<ScheduleResult> togglePrayer(String prayerId) {
    final current = state.modeFor(prayerId);
    return setPrayerMode(
      prayerId,
      current.isEnabled ? PrayerAlertMode.off : PrayerAlertMode.adhan,
    );
  }

  Future<ScheduleResult> setAllPrayers(PrayerAlertMode mode) {
    return update(
      state.copyWith(
        prayerModes: {for (final id in PrayerIds.obligatory) id: mode},
      ),
    );
  }

  /// Re-run scheduling without changing anything (location or method changed).
  Future<ScheduleResult> reschedule() {
    return NotificationScheduler.refresh(
      preferences: _globalPrefs,
      overrides: state,
    );
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );

/// Convenience view of the master switch for simple widgets.
final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(notificationPreferencesProvider).masterEnabled;
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = _globalPrefs.getString(AppConstants.localeKey);
    if (code == 'ar' || code == 'en') {
      return Locale(code!);
    }
    return const Locale('ar');
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'ar' && languageCode != 'en') {
      return;
    }

    state = Locale(languageCode);
    await _globalPrefs.setString(AppConstants.localeKey, languageCode);
    AppLogger.info('Locale changed to: $languageCode');
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class FirstLaunchNotifier extends Notifier<bool> {
  @override
  bool build() {
    return !_hasCompletedOnboarding();
  }

  static bool _hasCompletedOnboarding() {
    return _globalPrefs.getBool(AppConstants.isFirstLaunchKey) == false;
  }

  /// Source of truth from disk — not in-memory state.
  bool get shouldShowOnboarding => !_hasCompletedOnboarding();

  Future<void> completeOnboarding() async {
    await _globalPrefs.setBool(AppConstants.isFirstLaunchKey, false);
    state = false;
    AppLogger.info('Onboarding completed and saved');
  }
}

final firstLaunchProvider =
    NotifierProvider<FirstLaunchNotifier, bool>(FirstLaunchNotifier.new);

class MainTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index < 0 || index > 3) {
      return;
    }
    state = index;
  }

  void openHome() => setIndex(0);

  void openSettings() => setIndex(3);
}

final mainTabIndexProvider =
    NotifierProvider<MainTabNotifier, int>(MainTabNotifier.new);

class UserProfile {
  final String name;
  final String location;

  const UserProfile({required this.name, required this.location});
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return UserProfile(
      name: _globalPrefs.getString(AppConstants.userNameKey) ?? '',
      location: _globalPrefs.getString(AppConstants.userCityKey) ?? '',
    );
  }

  Future<void> update({required String name, required String location}) async {
    final sanitizedName = InputValidators.sanitizeDisplayName(name);
    final sanitizedLocation = InputValidators.sanitizeLocationLabel(location);
    state = UserProfile(name: sanitizedName, location: sanitizedLocation);
    await _globalPrefs.setString(AppConstants.userNameKey, sanitizedName);
    await _globalPrefs.setString(AppConstants.userCityKey, sanitizedLocation);
    AppLogger.info('Profile updated');
  }

  Future<void> clear() async {
    state = const UserProfile(name: '', location: '');
    await _globalPrefs.remove(AppConstants.userNameKey);
    await _globalPrefs.remove(AppConstants.userCityKey);
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);

