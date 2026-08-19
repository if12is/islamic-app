/// Application-wide constants for the Islamic app.
/// 
/// This file contains all hardcoded values used throughout the application
/// including API endpoints, cache durations, and configuration values.
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // ========================
  // API Endpoints
  // ========================
  
  /// Base URL for the Aladhan Prayer Times API
  static const String aladhanApiBaseUrl = 'https://api.aladhan.com/v1';
  
  /// Quran.com metadata API
  static const String quranApiBaseUrl = 'https://api.quran.com/api/v4';

  /// AlQuran Cloud API used for tafsir editions
  static const String alQuranCloudApiBaseUrl = 'https://api.alquran.cloud/v1';

  /// Verse-by-verse and full-surah recitation CDN
  static const String quranAudioCdnBaseUrl = 'https://cdn.islamic.network';

  /// Free public Azkar JSON source (open GitHub dataset)
  static const String azkarJsonUrl =
      'https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json';

  // ========================
  // Cache Configuration
  // ========================
  
  /// Cache duration for prayer times (24 hours)
  static const Duration prayerTimesCacheDuration = Duration(hours: 24);
  
  /// Cache duration for Quran data (7 days)
  static const Duration quranCacheDuration = Duration(days: 7);
  
  /// Cache duration for Azkar data (30 days)
  static const Duration azkarCacheDuration = Duration(days: 30);

  /// Tafsir text never changes, so cache it for a year.
  static const Duration tafsirCacheDuration = Duration(days: 365);

  // ========================
  // Prayer Times Configuration
  // ========================
  
  /// Available prayer calculation methods from Aladhan API
  /// 0: Shia Ithna-Ashari, 1: University of Islamic Sciences Qom
  /// 2: Islamic Society of North America, 3: Muslim World League
  /// 4: Umm al-Qura University, 5: Egyptian General Authority of Survey
  /// 7: Kuwait, 8: Qatar, 9: Majlis Ugama Islam Singapura
  /// 10: Tunisia, 11: Turkey, 12: Singapore, 13: MUIS
  /// 14: JAKIM, 15: BABULS
  static const Map<int, String> prayerCalculationMethods = {
    2: 'ISNA',
    3: 'Muslim World League',
    4: 'Umm al-Qura',
    5: 'Egyptian Authority',
  };

  // ========================
  // UI Configuration
  // ========================
  
  /// Default animation duration (milliseconds)
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  /// Short animation duration (milliseconds)
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  
  /// Long animation duration (milliseconds)
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // ========================
  // Storage Keys
  // ========================
  
  /// Key for storing first launch status in local storage
  static const String isFirstLaunchKey = 'is_first_launch';
  
  /// Key for storing selected theme mode
  static const String themeModeKey = 'theme_mode';
  
  /// Key for storing selected prayer calculation method
  static const String prayerMethodKey = 'prayer_method';
  
  /// Key for storing user's latitude
  static const String userLatitudeKey = 'user_latitude';
  
  /// Key for storing user's longitude
  static const String userLongitudeKey = 'user_longitude';
  
  /// Key for storing user's city name
  static const String userCityKey = 'user_city';

  /// Display name shown on the settings profile card
  static const String userNameKey = 'user_display_name';

  /// Last opened azkar category id for resume
  static const String lastAzkarCategoryIdKey = 'last_azkar_category_id';

  /// Legacy per-prayer adhan alert flags (JSON map of bools).
  ///
  /// Superseded by [notificationPreferencesKey]; still read once so existing
  /// installs keep their choices.
  static const String prayerNotificationPrefsKey = 'prayer_notification_prefs';

  /// Full notification settings (modes, reminders, quiet hours) as JSON.
  static const String notificationPreferencesKey = 'notification_prefs_v1';

  /// Prayer calculation fine-tuning (madhab, offsets) as JSON.
  static const String prayerCalculationSettingsKey = 'prayer_calc_settings_v1';

  /// Reader display settings (font, size, spacing, theme) as JSON.
  static const String readerSettingsKey = 'quran_reader_settings_v1';

  /// Selected tafsir edition identifier.
  static const String tafsirEditionKey = 'quran_tafsir_edition';

  /// Selected verse-audio reciter identifier.
  static const String verseReciterKey = 'quran_verse_reciter';

  /// Support inbox used by the contact form
  static const String supportEmail = 'support@alfajr.app';
  
  /// Key for storing notifications enabled status
  static const String notificationsEnabledKey = 'notifications_enabled';

  /// Key for storing selected app language (ar/en)
  static const String localeKey = 'app_locale';

  // ========================
  // Qibla Configuration
  // ========================
  
  /// Latitude of Kaaba in Mecca
  static const double kaabaLatitude = 21.4225;
  
  /// Longitude of Kaaba in Mecca
  static const double kaabaLongitude = 39.8264;

  // ========================
  // Localization
  // ========================
  
  /// Supported locales
  static const List<String> supportedLanguages = ['en', 'ar'];
  
  /// Default locale
  static const String defaultLocale = 'en';
  
  /// RTL languages
  static const List<String> rtlLanguages = ['ar'];
}
