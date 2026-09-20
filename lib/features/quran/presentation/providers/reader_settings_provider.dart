import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/services/mushaf_reader.dart';
import '../../data/services/reciter_catalogue.dart';
import '../../data/services/verse_reciters.dart';
import '../../domain/entities/riwaya.dart';

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
    this.reciterChosen = false,
    this.viewMode = ReaderViewMode.continuous,
    this.showTajweed = false,
    this.edition = MushafEdition.hafs,
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

  /// Whether the reader has ever picked a voice.
  ///
  /// [reciterCode] alone cannot answer this: it holds a default from the first
  /// launch, so "Al-Afasy because nobody asked" and "Al-Afasy because I chose
  /// him" look identical. Without the difference the app starts a recitation in
  /// a stranger's voice on the first tap, which is not a small thing when the
  /// voice is the whole point of the tap.
  final bool reciterChosen;

  /// Continuous scroll or page-by-page.
  final ReaderViewMode viewMode;

  /// Colour the tajweed rules on the page.
  final bool showTajweed;

  /// Which reading the reader is reading.
  ///
  /// Not a display preference. It changes the text on the page, how the verses
  /// are numbered, and which recordings may be offered — a Hafs recitation
  /// over a Warsh page recites words that are not there.
  final MushafEdition edition;

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
    bool? reciterChosen,
    ReaderViewMode? viewMode,
    bool? showTajweed,
    MushafEdition? edition,
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
      reciterChosen: reciterChosen ?? this.reciterChosen,
      viewMode: viewMode ?? this.viewMode,
      showTajweed: showTajweed ?? this.showTajweed,
      edition: edition ?? this.edition,
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
    'reciterChosen': reciterChosen,
    'viewMode': viewMode.name,
    'showTajweed': showTajweed,
    'edition': edition.id,
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
      // Anyone upgrading who already has a stored reciter is treated as having
      // chosen it, so the picker does not open on a settled habit.
      reciterChosen:
          json['reciterChosen'] == true ||
          (json['reciterChosen'] == null && json['reciterCode'] is String),
      viewMode: ReaderViewMode.values.firstWhere(
        (mode) => mode.name == json['viewMode'],
        orElse: () => ReaderViewMode.continuous,
      ),
      showTajweed: json['showTajweed'] == true,
      edition: MushafEdition.fromId(json['edition'] as String?),
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
  ReaderSettings build() => _publish(readStoredReaderSettings());

  /// Mirror the chosen reading where code with no `Ref` can see it.
  ///
  /// The reading is one setting, but it decides what the whole app shows: an
  /// ayah of the day, a share card, a memorisation prompt, a notification. Not
  /// one of those has a `Ref`, and threading a provider through all of them
  /// would mean every new screen has to remember. This is the one place the
  /// mirror is written, on every change, so forgetting is not possible.
  ReaderSettings _publish(ReaderSettings settings) {
    MushafReader.current = settings.edition;
    return settings;
  }

  Future<void> update(ReaderSettings next) async {
    state = _publish(next);
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

  /// Remember a voice, and that it was actually picked.
  ///
  /// Every route into this is a deliberate choice — a name tapped in the
  /// picker — so the flag is set here rather than at each call site, where it
  /// would be forgotten at one of them.
  Future<void> setReciter(String code) =>
      update(state.copyWith(reciterCode: code, reciterChosen: true));

  /// Change which reading the reader reads.
  ///
  /// The voice moves with it. A reader who switches to Warsh and keeps a Hafs
  /// reciter would be shown one text and recited another — which is the exact
  /// complaint this whole change answers — so a voice that does not belong to
  /// the new reading is dropped, and the reader is asked again rather than
  /// left with a silent substitution.
  ///
  /// Dropped, not replaced. Substituting a default here is how a reader of
  /// Qalun — for whom the per-ayah corpus has nothing, so the "default" is a
  /// Hafs voice — would end up with al-Afasy's name on the screen above a
  /// Qalun page. Clearing the flag sends them back to the picker, which only
  /// ever lists what can actually play.
  Future<void> setEdition(MushafEdition value) async {
    if (state.edition == value) {
      return;
    }

    await update(
      state.copyWith(
        edition: value,
        reciterChosen: _voiceSuits(state.reciterCode, value) ? null : false,
      ),
    );
  }

  /// Whether a saved id belongs to [edition], whichever list it came from.
  ///
  /// Both are asked, because one id can name a per-ayah voice or a whole-surah
  /// recording and the reader does not distinguish them.
  bool _voiceSuits(String code, MushafEdition edition) {
    final file = VerseReciters.find(code);
    if (file != null) {
      return edition.accepts(file.riwayaId);
    }
    final catalogued = ReciterCatalogue.byId(code, ReciterCatalogue.known);
    return catalogued != null && edition.accepts(catalogued.riwayaId);
  }

  Future<void> setViewMode(ReaderViewMode mode) =>
      update(state.copyWith(viewMode: mode));

  Future<void> setShowTajweed(bool value) =>
      update(state.copyWith(showTajweed: value));

  Future<void> resetToDefaults() => update(const ReaderSettings());
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );

/// The reader's stored settings, without building a provider.
ReaderSettings readStoredReaderSettings() {
  final raw = appPreferences.getString(AppConstants.readerSettingsKey);
  if (raw == null || raw.isEmpty) {
    // The old reader stored only `quran_font_size`; keep it.
    final legacy = appPreferences.getDouble('quran_font_size');
    return legacy == null
        ? const ReaderSettings()
        : const ReaderSettings().copyWith(fontSize: legacy);
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

/// Publish the stored reading before anything that runs at startup reads it.
///
/// `main` schedules notifications — including the ayah of the day, which is
/// rendered into the notification text — before any widget has built the
/// reader settings provider. Without this, every cold start would write that
/// ayah in Hafs for someone who reads Warsh or Qalun.
void publishStoredEdition() {
  MushafReader.current = readStoredReaderSettings().edition;
}
