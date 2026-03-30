import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// State notifier for theme mode management.
///
/// Manages switching between light and dark themes and persists the user's preference.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Reference to SharedPreferences for persistence
  final SharedPreferences prefs;

  /// Constructor - initializes with saved theme or defaults to system
  ThemeModeNotifier({required this.prefs})
      : super(ThemeMode.system) {
    _loadSavedTheme();
  }

  /// Load saved theme mode from storage.
  Future<void> _loadSavedTheme() async {
    final savedTheme = prefs.getString(AppConstants.themeModeKey);
    
    if (savedTheme != null) {
      final themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
      state = themeMode;
    }
  }

  /// Toggle between light and dark themes.
  Future<void> toggleTheme() async {
    final newTheme = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider for theme mode state management.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
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
final prayerMethodProvider = StateNotifierProvider<PrayerMethodNotifier, int>((ref) {
  return PrayerMethodNotifier(prefs: _globalPrefs);
});
