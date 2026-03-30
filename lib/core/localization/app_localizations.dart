import 'package:flutter/material.dart';

/// Lightweight in-app localization for Arabic and English.
class AppLocalizations {
  AppLocalizations._();

  static const String _fallbackLanguage = 'en';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Islamic App',
      'home': 'Home',
      'quran': 'Quran',
      'prayer': 'Prayer',
      'azkar': 'Azkar',
      'settings': 'Settings',
      'display': 'Display',
      'dark_mode': 'Dark Mode',
      'prayer_settings': 'Prayer Settings',
      'calculation_method': 'Calculation Method',
      'notifications': 'Notifications',
      'enable_prayer_notifications': 'Enable Prayer Notifications',
      'allow_reminders': 'Allow reminders for upcoming prayers.',
      'notification_permission_denied':
          'Notification permission denied. Please enable it in settings.',
      'send_test_notification': 'Send Test Notification',
      'trigger_test_reminder': 'Trigger an immediate local test reminder.',
      'test_notification_sent': 'Test notification sent.',
      'about': 'About',
      'app_version': 'App Version',
      'about_app': 'About This App',
      'about_description':
          'A comprehensive Islamic app with prayer times, Quran, Azkar, and more.',
      'language': 'Language',
      'language_arabic': 'Arabic',
      'language_english': 'English',
      'welcome_greeting': 'Peace be upon you',
      'home_intro':
          'Track your prayers, read Quran, and maintain daily Azkar.',
      'prayer_times': 'Prayer Times',
      'check_prayer_schedule': 'Check today\'s prayer schedule and Qibla.',
      'browse_surahs': 'Browse surahs and read verses.',
      'morning_evening_azkar': 'Morning and evening Azkar with tasbeeh counter.',
      'theme_method_notifications': 'Theme, method, language, and notifications.',
      'try_again': 'Try Again',
      'retry': 'Retry',
      'unable_load_prayer_times': 'Unable to load prayer times.',
      'location_services_disabled':
          'Location services are disabled. Please enable GPS.',
      'location_permission_required':
          'Location permission is required to fetch prayer times and Qibla.',
      'daily_prayers': 'Daily Prayers',
      'location': 'Location',
      'coordinates': 'Coordinates',
      'hijri': 'Hijri',
      'gregorian': 'Gregorian',
      'next': 'Next',
      'in': 'in',
      'qibla_compass': 'Qibla Compass',
      'qibla_direction': 'Qibla direction',
      'prayer_list': 'Prayer List',
      'compass_not_available': 'Compass is not available on this device.',
      'device_heading': 'Device heading',
      'search_surah_hint': 'Search surah by Arabic or English name',
      'unable_load_surahs': 'Unable to load Surahs.',
      'no_surah_match': 'No surah matched your search.',
      'verses': 'verses',
      'text_size': 'Text size',
      'unable_load_verses': 'Unable to load verses.',
      'no_verses': 'No verses available.',
      'azkar_tasbeeh': 'Azkar & Tasbeeh',
      'failed_load_azkar': 'Failed to load azkar data.',
      'no_azkar_found': 'No azkar data found.',
      'tasbeeh_counter': 'Tasbeeh Counter',
      'count': 'Count',
      'reset': 'Reset',
      'no_fixed_target': 'No fixed target count',
      'onboarding_welcome_title': 'Welcome to Islamic App',
      'onboarding_welcome_body':
          'Your companion for daily Islamic practices, prayer times, and the Holy Quran.',
      'onboarding_location_title': 'Enable Location',
      'onboarding_location_body':
          'We need your location to provide accurate prayer times for your area.',
      'onboarding_notifications_title': 'Enable Notifications',
      'onboarding_notifications_body':
          'Get reminders for prayer times and important Islamic events.',
      'back': 'Back',
      'next_btn': 'Next',
      'enable_location': 'Enable Location',
      'enable_notifications': 'Enable Notifications',
    'skip': 'Skip',
      'prayer_reminder_title': 'Prayer Reminder',
      'prayer_reminder_body': 'It is now time for prayer',
      'islamic_app_version': 'Islamic App v1.0.0',
    },
    'ar': {
      'app_title': 'التطبيق الإسلامي',
      'home': 'الرئيسية',
      'quran': 'القرآن',
      'prayer': 'الصلاة',
      'azkar': 'الأذكار',
      'settings': 'الإعدادات',
      'display': 'العرض',
      'dark_mode': 'الوضع الداكن',
      'prayer_settings': 'إعدادات الصلاة',
      'calculation_method': 'طريقة الحساب',
      'notifications': 'الإشعارات',
      'enable_prayer_notifications': 'تفعيل إشعارات الصلاة',
      'allow_reminders': 'السماح بتذكيرات الصلوات القادمة.',
      'notification_permission_denied':
          'تم رفض إذن الإشعارات. يرجى تفعيله من إعدادات النظام.',
      'send_test_notification': 'إرسال إشعار تجريبي',
      'trigger_test_reminder': 'إرسال تذكير تجريبي فوري.',
      'test_notification_sent': 'تم إرسال الإشعار التجريبي.',
      'about': 'حول التطبيق',
      'app_version': 'إصدار التطبيق',
      'about_app': 'عن هذا التطبيق',
      'about_description':
          'تطبيق إسلامي شامل لمواقيت الصلاة والقرآن والأذكار والمزيد.',
      'language': 'اللغة',
      'language_arabic': 'العربية',
      'language_english': 'الإنجليزية',
      'welcome_greeting': 'السلام عليكم ورحمة الله وبركاته',
      'home_intro': 'تابع صلاتك، اقرأ القرآن، واستمر في أذكارك اليومية.',
      'prayer_times': 'مواقيت الصلاة',
      'check_prayer_schedule': 'اعرض مواقيت اليوم والقبلة.',
      'browse_surahs': 'تصفح السور واقرأ الآيات.',
      'morning_evening_azkar': 'أذكار الصباح والمساء مع عداد تسبيح.',
      'theme_method_notifications': 'الثيم وطريقة الحساب واللغة والإشعارات.',
      'try_again': 'حاول مرة أخرى',
      'retry': 'إعادة المحاولة',
      'unable_load_prayer_times': 'تعذر تحميل مواقيت الصلاة.',
      'location_services_disabled':
          'خدمات الموقع متوقفة. يرجى تفعيل GPS.',
      'location_permission_required':
          'نحتاج إذن الموقع لجلب مواقيت الصلاة والقبلة.',
      'daily_prayers': 'الصلوات اليومية',
      'location': 'الموقع',
      'coordinates': 'الإحداثيات',
      'hijri': 'الهجري',
      'gregorian': 'الميلادي',
      'next': 'القادمة',
      'in': 'بعد',
      'qibla_compass': 'بوصلة القبلة',
      'qibla_direction': 'اتجاه القبلة',
      'prayer_list': 'قائمة الصلوات',
      'compass_not_available': 'البوصلة غير متاحة على هذا الجهاز.',
      'device_heading': 'اتجاه الجهاز',
      'search_surah_hint': 'ابحث عن السورة بالعربية أو الإنجليزية',
      'unable_load_surahs': 'تعذر تحميل السور.',
      'no_surah_match': 'لا توجد سورة مطابقة للبحث.',
      'verses': 'آية',
      'text_size': 'حجم النص',
      'unable_load_verses': 'تعذر تحميل الآيات.',
      'no_verses': 'لا توجد آيات متاحة.',
      'azkar_tasbeeh': 'الأذكار والتسبيح',
      'failed_load_azkar': 'تعذر تحميل بيانات الأذكار.',
      'no_azkar_found': 'لا توجد بيانات أذكار.',
      'tasbeeh_counter': 'عداد التسبيح',
      'count': 'تسبيح',
      'reset': 'إعادة',
      'no_fixed_target': 'لا يوجد عدد محدد',
      'onboarding_welcome_title': 'مرحبا بك في التطبيق الإسلامي',
      'onboarding_welcome_body':
          'رفيقك اليومي للعبادات ومواقيت الصلاة والقرآن الكريم.',
      'onboarding_location_title': 'تفعيل الموقع',
      'onboarding_location_body':
          'نحتاج موقعك لتقديم مواقيت صلاة دقيقة لمنطقتك.',
      'onboarding_notifications_title': 'تفعيل الإشعارات',
      'onboarding_notifications_body':
          'احصل على تذكيرات بمواقيت الصلاة والمناسبات الإسلامية.',
      'back': 'السابق',
      'next_btn': 'التالي',
      'enable_location': 'تفعيل الموقع',
      'enable_notifications': 'تفعيل الإشعارات',
    'skip': 'تخطي',
      'prayer_reminder_title': 'تذكير صلاة',
      'prayer_reminder_body': 'حان الآن وقت الصلاة',
      'islamic_app_version': 'التطبيق الإسلامي v1.0.0',
    },
  };

  static String tr(BuildContext context, String key) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final values = _localizedValues[languageCode] ??
        _localizedValues[_fallbackLanguage]!;
    return values[key] ?? _localizedValues[_fallbackLanguage]![key] ?? key;
  }

  static bool isRtl(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}

extension AppLocalizationContext on BuildContext {
  String tr(String key) => AppLocalizations.tr(this, key);

  bool get isAppRtl => AppLocalizations.isRtl(this);

  TextDirection get appTextDirection =>
      isAppRtl ? TextDirection.rtl : TextDirection.ltr;
}
