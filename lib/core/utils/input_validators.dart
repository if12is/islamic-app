/// Validates user/API inputs before they reach network or storage layers.
class InputValidators {
  InputValidators._();

  static const double minLatitude = -90;
  static const double maxLatitude = 90;
  static const double minLongitude = -180;
  static const double maxLongitude = 180;

  static bool isLatitude(double value) =>
      value >= minLatitude && value <= maxLatitude && value.isFinite;

  static bool isLongitude(double value) =>
      value >= minLongitude && value <= maxLongitude && value.isFinite;

  static bool isSupportedPrayerMethod(int method) =>
      method >= 0 && method <= 15;

  static bool isSupportedLanguage(String code) =>
      code == 'ar' || code == 'en';

  static String sanitizePrayerId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  }

  static String sanitizeDisplayName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isDisplayName(String value) {
    final sanitized = sanitizeDisplayName(value);
    return sanitized.length >= 2 && sanitized.length <= 40;
  }

  static String sanitizeLocationLabel(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isLocationLabel(String value) {
    final sanitized = sanitizeLocationLabel(value);
    return sanitized.length >= 2 && sanitized.length <= 60;
  }

  static String sanitizeMessage(String value) {
    return value.trim();
  }

  static bool isFeedbackMessage(String value) {
    final sanitized = sanitizeMessage(value);
    return sanitized.length >= 8 && sanitized.length <= 1000;
  }
}
