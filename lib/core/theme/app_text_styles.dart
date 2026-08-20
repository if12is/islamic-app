import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The app's three voices, in one place.
///
/// * [quran] — revelation. Always the Mushaf face, never Cairo, so a verse is
///   recognisable at a glance even inside a du'a or a dhikr.
/// * [display] — titles and headers, in the Kufic display face.
/// * [body] — everything else.
class AppTextStyles {
  AppTextStyles._();

  /// Mushaf face. Bundled, so it renders offline.
  static const String quranFamily = 'AmiriQuran';

  /// Kufic display face used for titles.
  static const String displayFamily = AppTheme.displayFontFamily;

  /// Body face.
  static const String bodyFamily = AppTheme.fontFamily;

  /// Quranic text: bigger, airier, and in the Mushaf face.
  static TextStyle quran(
    BuildContext context, {
    double fontSize = 22,
    Color? color,
    double height = 2.1,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: quranFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Titles and section headers.
  static TextStyle display(
    BuildContext context, {
    double fontSize = 20,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Ordinary text: du'a, azkar prose, explanations, UI copy.
  static TextStyle body(
    BuildContext context, {
    double fontSize = 16,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.9,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Small captions: references, virtues, counters.
  static TextStyle caption(
    BuildContext context, {
    double fontSize = 12.5,
    Color? color,
    double height = 1.7,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: fontSize,
      height: height,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
