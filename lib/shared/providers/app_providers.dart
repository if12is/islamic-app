import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/startup_sync_service.dart';

/// State notifier for theme mode management.
///
/// Manages switching between light and dark themes and persists the user's preference.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Reference to SharedPreferences for persistence
  final SharedPreferences prefs;

  /// Constructor - initializes with saved theme or defaults to system
  ThemeModeNotifier({required this.prefs}) : super(ThemeMode.dark) {
    _loadSavedTheme();
  }

  /// Load saved theme mode from storage.
  Future<void> _loadSavedTheme() async {
    final savedTheme = prefs.getString(AppConstants.themeModeKey);

    if (savedTheme != null) {
      final themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedTheme,
        orElse: () => ThemeMode.dark,
      );
      state = themeMode;
    }
  }

  /// Toggle between light and dark themes.
  Future<void> toggleTheme() async {
    final newTheme =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setTheme(newTheme);
  }

  /// Set a specific theme mode.
  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;
    await prefs.setString(AppConstants.themeModeKey, themeMode.toString());
    print('✅ Theme changed to: $themeMode');
  }
}

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// Provider for theme mode state management.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  // Create a ThemeModeNotifier with default system theme
  // In a real app, we'd wait for SharedPreferences, but for simplicity:
  return ThemeModeNotifier(prefs: _globalPrefs);
});

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
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
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
    print('⚠️ Startup sync failed: $e');
  } finally {
    _startupSyncInProgress = false;
  }
}

/// Notifier for prayer calculation method selection.
class PrayerMethodNotifier extends StateNotifier<int> {
  final SharedPreferences prefs;

  PrayerMethodNotifier({required this.prefs}) : super(3) {
    _loadSavedMethod();
  }

  Future<void> _loadSavedMethod() async {
    final saved = prefs.getInt(AppConstants.prayerMethodKey);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setMethod(int method) async {
    state = method;
    await prefs.setInt(AppConstants.prayerMethodKey, method);
    print('✅ Prayer method changed to: $method');
  }
}

/// Provider for prayer calculation method.
final prayerMethodProvider = StateNotifierProvider<PrayerMethodNotifier, int>((
  ref,
) {
  return PrayerMethodNotifier(prefs: _globalPrefs);
});

/// Notifier for enabling/disabling notifications.
class NotificationsEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences prefs;

  NotificationsEnabledNotifier({required this.prefs}) : super(false) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    state = prefs.getBool(AppConstants.notificationsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await prefs.setBool(AppConstants.notificationsEnabledKey, enabled);
    print('✅ Notifications enabled: $enabled');
  }
}

/// Provider for notification enabled/disabled state.
final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
      return NotificationsEnabledNotifier(prefs: _globalPrefs);
    });

/// Notifier for application locale (Arabic/English).
class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences prefs;

  LocaleNotifier({required this.prefs}) : super(const Locale('ar')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final code = prefs.getString(AppConstants.localeKey);
    if (code == 'ar' || code == 'en') {
      state = Locale(code!);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'ar' && languageCode != 'en') {
      return;
    }

    state = Locale(languageCode);
    await prefs.setString(AppConstants.localeKey, languageCode);
    print('✅ Locale changed to: $languageCode');
  }
}

/// Provider for app locale state.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(prefs: _globalPrefs);
});

/// Notifier for onboarding visibility on first app launch.
class FirstLaunchNotifier extends StateNotifier<bool> {
  final SharedPreferences prefs;

  FirstLaunchNotifier({required this.prefs})
    : super(prefs.getBool(AppConstants.isFirstLaunchKey) ?? true);

  Future<void> completeOnboarding() async {
    state = false;
    await prefs.setBool(AppConstants.isFirstLaunchKey, false);
  }
}

/// Provider that determines whether onboarding should be displayed.
final firstLaunchProvider = StateNotifierProvider<FirstLaunchNotifier, bool>((
  ref,
) {
  return FirstLaunchNotifier(prefs: _globalPrefs);
});
