import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/app_providers.dart';

/// Text faces available to the reader. All three are bundled with the app, so
/// switching fonts never needs a network round-trip.
enum ReaderFont {
  amiriQuran('AmiriQuran'),
  scheherazade('ScheherazadeNew'),
  cairo('Cairo');

  const ReaderFont(this.family);

  final String family;
}

/// Reading surfaces tuned for different light conditions.
enum ReaderTheme { auto, light, sepia, dark, green }

/// How the Mushaf is laid out.
enum ReaderViewMode {
  /// One continuous scroll — good for reading a long passage.
  continuous,

  /// Page by page, the way a printed Mushaf is read and memorised.
  pages,
}

/// A resolved palette for the reading surface.
class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
    required this.highlight,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color accent;
  final Color highlight;
  final bool isDark;
}

/// Everything the reader lets the user control.
class ReaderSettings {
  const ReaderSettings({
    this.font = ReaderFont.amiriQuran,
    this.fontSize = 28,
    this.lineHeight = 2.2,
    this.horizontalPadding = 16,
    this.theme = ReaderTheme.auto,
    this.autoScrollSpeed = 1.0,
    this.keepScreenOn = false,
    this.brightnessOverride,
    this.showVerseNumbers = true,
    this.reciterCode = 'ar.alafasy',
    this.viewMode = ReaderViewMode.continuous,
  });

  final ReaderFont font;

  /// 18-56 logical pixels.
  final double fontSize;

  /// Line box multiplier, 1.6-3.4.
  final double lineHeight;

  /// Page side padding, 8-48.
  final double horizontalPadding;

  final ReaderTheme theme;

  /// Auto-scroll speed multiplier, 0.2-3.0 (pixels per frame at 1.0 ≈ slow).
  final double autoScrollSpeed;

  /// Keep the screen awake while reading.
  final bool keepScreenOn;

  /// Locked screen brightness (0-1), or null to follow the system.
  final double? brightnessOverride;

  final bool showVerseNumbers;

  /// Reciter used for verse-by-verse playback.
  final String reciterCode;

  /// Continuous scroll or page-by-page.
  final ReaderViewMode viewMode;

  ReaderSettings copyWith({
    ReaderFont? font,
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    ReaderTheme? theme,
    double? autoScrollSpeed,
    bool? keepScreenOn,
    double? brightnessOverride,
    bool clearBrightnessOverride = false,
    bool? showVerseNumbers,
    String? reciterCode,
    ReaderViewMode? viewMode,
  }) {
    return ReaderSettings(
      font: font ?? this.font,
      fontSize: (fontSize ?? this.fontSize).clamp(18, 56).toDouble(),
      lineHeight: (lineHeight ?? this.lineHeight).clamp(1.6, 3.4).toDouble(),
      horizontalPadding:
          (horizontalPadding ?? this.horizontalPadding).clamp(8, 48).toDouble(),
      theme: theme ?? this.theme,
      autoScrollSpeed:
          (autoScrollSpeed ?? this.autoScrollSpeed).clamp(0.2, 8.0).toDouble(),
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      brightnessOverride:
          clearBrightnessOverride
              ? null
              : (brightnessOverride ?? this.brightnessOverride),
      showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
      reciterCode: reciterCode ?? this.reciterCode,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'font': font.name,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'horizontalPadding': horizontalPadding,
    'theme': theme.name,
    'autoScrollSpeed': autoScrollSpeed,
    'keepScreenOn': keepScreenOn,
    'brightnessOverride': brightnessOverride,
    'showVerseNumbers': showVerseNumbers,
    'reciterCode': reciterCode,
    'viewMode': viewMode.name,
  };

  factory ReaderSettings.fromJson(Map<dynamic, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return const ReaderSettings().copyWith(
      font: ReaderFont.values.firstWhere(
        (font) => font.name == json['font'],
        orElse: () => ReaderFont.amiriQuran,
      ),
      fontSize: number('fontSize', 28),
      lineHeight: number('lineHeight', 2.2),
      horizontalPadding: number('horizontalPadding', 16),
      theme: ReaderTheme.values.firstWhere(
        (theme) => theme.name == json['theme'],
        orElse: () => ReaderTheme.auto,
      ),
      autoScrollSpeed: number('autoScrollSpeed', 1.0),
      keepScreenOn: json['keepScreenOn'] == true,
      brightnessOverride:
          json['brightnessOverride'] is num
              ? (json['brightnessOverride'] as num).toDouble()
              : null,
      clearBrightnessOverride: json['brightnessOverride'] == null,
      showVerseNumbers: json['showVerseNumbers'] != false,
      reciterCode:
          json['reciterCode'] is String
              ? json['reciterCode'] as String
              : 'ar.alafasy',
      viewMode: ReaderViewMode.values.firstWhere(
        (mode) => mode.name == json['viewMode'],
        orElse: () => ReaderViewMode.continuous,
      ),
    );
  }

  /// Colours for the current reading theme, falling back to the app theme when
  /// the reader theme is [ReaderTheme.auto].
  ReaderPalette paletteFor(BuildContext context) {
    switch (theme) {
      case ReaderTheme.auto:
        // Follows the app's own tokens, so the reader is dressed for the
        // season along with everything else.
        final tokens = context.tokens;
        return ReaderPalette(
          background: tokens.ground,
          surface: tokens.surface,
          text: tokens.ink,
          accent: tokens.gold,
          highlight: tokens.brand.withValues(
            alpha: tokens.isDark ? 0.28 : 0.16,
          ),
          isDark: tokens.isDark,
        );
      case ReaderTheme.light:
        return ReaderPalette(
          background: const Color(0xFFFBF6EC),
          surface: const Color(0xFFFFFCF6),
          text: const Color(0xFF12261F),
          accent: const Color(0xFFB07C21),
          highlight: const Color(0xFF0F6B4F).withValues(alpha: 0.14),
          isDark: false,
        );
      case ReaderTheme.sepia:
        return ReaderPalette(
          background: const Color(0xFFF3E9D6),
          surface: const Color(0xFFFBF3E4),
          text: const Color(0xFF4A3A22),
          accent: const Color(0xFF9A6B1F),
          highlight: const Color(0xFF9A6B1F).withValues(alpha: 0.18),
          isDark: false,
        );
      case ReaderTheme.dark:
        return ReaderPalette(
          background: const Color(0xFF0D1114),
          surface: const Color(0xFF16191C),
          text: const Color(0xFFE7EAE8),
          accent: const Color(0xFFE9C349),
          highlight: const Color(0xFF34D399).withValues(alpha: 0.22),
          isDark: true,
        );
      case ReaderTheme.green:
        return ReaderPalette(
          background: const Color(0xFF07130F),
          surface: const Color(0xFF0E1F19),
          text: const Color(0xFFDCE9E1),
          accent: const Color(0xFFE9C349),
          highlight: const Color(0xFF34D399).withValues(alpha: 0.24),
          isDark: true,
        );
    }
  }
}

/// Persisted reader preferences.
///
/// Written straight through to storage so a crash never loses the reader's
/// setup, and read synchronously at build time so the page never flashes
/// default typography before the user's own settings land.
class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    final raw = appPreferences.getString(AppConstants.readerSettingsKey);
    if (raw == null || raw.isEmpty) {
      return _migrateLegacyFontSize();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ReaderSettings.fromJson(decoded);
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return const ReaderSettings();
  }

  /// The old reader stored only `quran_font_size`; keep it.
  ReaderSettings _migrateLegacyFontSize() {
    final legacy = appPreferences.getDouble('quran_font_size');
    if (legacy == null) {
      return const ReaderSettings();
    }
    return const ReaderSettings().copyWith(fontSize: legacy);
  }

  Future<void> update(ReaderSettings next) async {
    state = next;
    await appPreferences.setString(
      AppConstants.readerSettingsKey,
      jsonEncode(next.toJson()),
    );
  }

  Future<void> setFont(ReaderFont font) => update(state.copyWith(font: font));

  Future<void> setTheme(ReaderTheme theme) =>
      update(state.copyWith(theme: theme));

  Future<void> changeFontSize(double delta) =>
      update(state.copyWith(fontSize: state.fontSize + delta));

  Future<void> setFontSize(double size) =>
      update(state.copyWith(fontSize: size));

  Future<void> setLineHeight(double value) =>
      update(state.copyWith(lineHeight: value));

  Future<void> setHorizontalPadding(double value) =>
      update(state.copyWith(horizontalPadding: value));

  Future<void> setAutoScrollSpeed(double value) =>
      update(state.copyWith(autoScrollSpeed: value));

  Future<void> setKeepScreenOn(bool value) =>
      update(state.copyWith(keepScreenOn: value));

  Future<void> setBrightnessOverride(double? value) => update(
    value == null
        ? state.copyWith(clearBrightnessOverride: true)
        : state.copyWith(brightnessOverride: value),
  );

  Future<void> setShowVerseNumbers(bool value) =>
      update(state.copyWith(showVerseNumbers: value));

  Future<void> setReciter(String code) =>
      update(state.copyWith(reciterCode: code));

  Future<void> setViewMode(ReaderViewMode mode) =>
      update(state.copyWith(viewMode: mode));

  Future<void> resetToDefaults() => update(const ReaderSettings());
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );
