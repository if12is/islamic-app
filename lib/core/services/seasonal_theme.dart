import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'hijri_service.dart';

/// Seasons the app dresses up for.
enum SeasonalEvent {
  none,

  /// The month itself.
  ramadan,

  /// The last ten nights — the same month, dialled up.
  lastTenNights,

  /// Eid al-Fitr and the two days after it.
  eidFitr,

  /// Eid al-Adha and the days of Tashreeq.
  eidAdha,
}

/// What a season changes, expressed as an override of the design tokens.
///
/// A season is a change of accent and atmosphere, never a change of identity:
/// the green stays exactly where it was, the surfaces keep their contrast, and
/// only the accent, the wash behind the page, and the drawn ornaments move.
/// That is why the seasonal look can be built once here and picked up by every
/// screen for free.
class SeasonalPalette {
  const SeasonalPalette({
    required this.accent,
    required this.accentBright,
    required this.heroGradient,
    required this.meshTop,
    required this.meshBottom,
    required this.ornament,
    required this.bannerColors,
  });

  /// Replaces the gold accent for the season.
  final Color accent;
  final Color accentBright;

  /// Two stops for hero cards while the season lasts.
  final List<Color> heroGradient;

  /// The wash painted behind every page.
  final Color meshTop;
  final Color meshBottom;

  /// Colour of the drawn decorations — lanterns, crescent, sheep.
  final Color ornament;

  /// Deep two-stop gradient used behind the seasonal banner and the intro.
  final List<Color> bannerColors;
}

/// Turns the Hijri date into a look.
///
/// Nothing here is a setting: Ramadan arrives, the app changes, and it changes
/// back on its own. The accent shifts, the wash behind the page warms, a
/// decorated banner appears — and every screen picks all of it up for free,
/// because the change happens in the tokens rather than in the screens.
class SeasonalTheme {
  SeasonalTheme._();

  /// The palette a season paints with, or null outside the seasons.
  static SeasonalPalette? paletteFor(SeasonalEvent event) {
    switch (event) {
      case SeasonalEvent.none:
        return null;

      // Lantern light against a night sky.
      case SeasonalEvent.ramadan:
        return const SeasonalPalette(
          accent: Color(0xFFC98A18),
          accentBright: Color(0xFFF0B429),
          heroGradient: [Color(0xFFF4CE7B), Color(0xFFCB9333)],
          meshTop: Color(0x241D3B5C),
          meshBottom: Color(0x1FF0B429),
          ornament: Color(0xFFF0B429),
          bannerColors: [Color(0xFF10233F), Color(0xFF1D3B5C)],
        );

      // The same night, dialled up: deeper sky, brighter gold.
      case SeasonalEvent.lastTenNights:
        return const SeasonalPalette(
          accent: Color(0xFFB8842A),
          accentBright: Color(0xFFFFD166),
          heroGradient: [Color(0xFFF9DE99), Color(0xFFD3A648)],
          meshTop: Color(0x2E101B33),
          meshBottom: Color(0x26FFD166),
          ornament: Color(0xFFFFD166),
          bannerColors: [Color(0xFF080F22), Color(0xFF16264A)],
        );

      // Fitr is bright and cool — the morning after the month.
      case SeasonalEvent.eidFitr:
        return const SeasonalPalette(
          accent: Color(0xFF0E9E86),
          accentBright: Color(0xFF2DD4BF),
          heroGradient: [Color(0xFF74E7D2), Color(0xFF19B79D)],
          meshTop: Color(0x242DD4BF),
          meshBottom: Color(0x1FF0B429),
          ornament: Color(0xFF2DD4BF),
          bannerColors: [Color(0xFF07463F), Color(0xFF0E7C5A)],
        );

      // Adha is warm and earthen — sand, wool, and dates.
      case SeasonalEvent.eidAdha:
        return const SeasonalPalette(
          accent: Color(0xFFA9661F),
          accentBright: Color(0xFFE3A857),
          heroGradient: [Color(0xFFEDBE85), Color(0xFFC58A46)],
          meshTop: Color(0x24C9884A),
          meshBottom: Color(0x1F6B4A22),
          ornament: Color(0xFFF3D8A8),
          bannerColors: [Color(0xFF2C1E10), Color(0xFF6B4A22)],
        );
    }
  }

  static SeasonalEvent detect({DateTime? now, int hijriOffsetDays = 0}) {
    final hijri = HijriService.fromGregorian(
      now ?? DateTime.now(),
      offsetDays: hijriOffsetDays,
    );

    final month = hijri.hMonth;
    final day = hijri.hDay;

    if (month == 9) {
      return day >= 21 ? SeasonalEvent.lastTenNights : SeasonalEvent.ramadan;
    }
    if (month == 10 && day <= 3) {
      return SeasonalEvent.eidFitr;
    }
    if (month == 12 && day >= 10 && day <= 13) {
      return SeasonalEvent.eidAdha;
    }
    return SeasonalEvent.none;
  }

  /// Greeting shown on the banner.
  static String greetingKey(SeasonalEvent event) {
    switch (event) {
      case SeasonalEvent.ramadan:
        return 'season_ramadan_greeting';
      case SeasonalEvent.lastTenNights:
        return 'season_last_ten_greeting';
      case SeasonalEvent.eidFitr:
        return 'season_eid_fitr_greeting';
      case SeasonalEvent.eidAdha:
        return 'season_eid_adha_greeting';
      case SeasonalEvent.none:
        return '';
    }
  }

  static String subtitleKey(SeasonalEvent event) {
    switch (event) {
      case SeasonalEvent.ramadan:
        return 'season_ramadan_subtitle';
      case SeasonalEvent.lastTenNights:
        return 'season_last_ten_subtitle';
      case SeasonalEvent.eidFitr:
        return 'season_eid_fitr_subtitle';
      case SeasonalEvent.eidAdha:
        return 'season_eid_adha_subtitle';
      case SeasonalEvent.none:
        return '';
    }
  }

  /// Dress a token set for the season.
  ///
  /// Identity colours are untouched on purpose: the app should feel dressed
  /// for the occasion, not repainted into something the user has to relearn.
  static AppTokens dress(AppTokens base, SeasonalEvent event) {
    final palette = paletteFor(event);
    if (palette == null) {
      return base;
    }

    return base.copyWith(
      gold: base.isDark ? palette.accentBright : palette.accent,
      goldBright: palette.accentBright,
      heroGradient: palette.heroGradient,
      meshTop: palette.meshTop,
      meshBottom: palette.meshBottom,
    );
  }
}
