import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/startup_sync_service.dart';
import '../../core/utils/app_logger.dart';

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

    await _globalPrefs.setDouble(
      AppConstants.userLatitudeKey,
      position.latitude,
    );
    await _globalPrefs.setDouble(
      AppConstants.userLongitudeKey,
      position.longitude,
    );

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
  }
}

final prayerMethodProvider =
    NotifierProvider<PrayerMethodNotifier, int>(PrayerMethodNotifier.new);

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return _globalPrefs.getBool(AppConstants.notificationsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _globalPrefs.setBool(AppConstants.notificationsEnabledKey, enabled);
    AppLogger.info('Notifications enabled: $enabled');
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
      NotificationsEnabledNotifier.new,
    );

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
    return _globalPrefs.getBool(AppConstants.isFirstLaunchKey) ?? true;
  }

  Future<void> completeOnboarding() async {
    state = false;
    await _globalPrefs.setBool(AppConstants.isFirstLaunchKey, false);
  }
}

final firstLaunchProvider =
    NotifierProvider<FirstLaunchNotifier, bool>(FirstLaunchNotifier.new);
