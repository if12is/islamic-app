import 'package:flutter/material.dart';

/// Corner radii. Two sizes, far apart on purpose.
///
/// A half-graded scale is what makes an interface look assembled in a hurry:
/// cards are [lg], pills and fields are [pill], small icon tiles are [sm], and
/// there is deliberately nothing between [sm] and [lg].
class AppRadii {
  AppRadii._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// The spacing scale. Every gap in the app is one of these six numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Room for the floating glass nav bar to sit over scrolling content.
  static const double navClearance = 110;

  /// Page side padding, the same on every screen.
  static const double page = 20;
}

/// Elevation as light, not as a grey box.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> lift(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.10),
      blurRadius: 36,
      offset: const Offset(0, 16),
    ),
  ];

  /// A coloured halo, for the raised nav circle and live elements.
  static List<BoxShadow> glow(Color color, {double alpha = 0.34}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Motion durations. Slow enough to read, short enough to stay out of the way.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 460);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Every colour the app is allowed to use, in one object.
///
/// Read it with `context.tokens`. Nothing outside this file may declare a
/// colour: a value that exists in one place can be re-tuned in one place, and
/// the seasonal dressing works by handing back a modified copy of this object
/// rather than by sprinkling special cases through the screens.
///
/// The rule the whole palette rests on: **green is the identity, gold is the
/// accent.** Gold appears on the live element, the hero card, and the single
/// primary button of a screen — nowhere else, or it stops being an accent and
/// becomes noise.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// The tint Android paints the media notification with.
  ///
  /// It lives here rather than at the call site because it is a brand colour
  /// like any other — but it cannot be read through `context.tokens`, since
  /// the background audio service is configured before any widget exists.
  static const Color notificationTint = Color(0xFF003527);

  const AppTokens({
    required this.ground,
    required this.groundAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.gold,
    required this.goldBright,
    required this.onGold,
    required this.danger,
    required this.glassTint,
    required this.glassEdge,
    required this.heroGradient,
    required this.meshTop,
    required this.meshBottom,
    required this.isDark,
  });

  /// Page background.
  final Color ground;

  /// A second ground, for headers and inset strips.
  final Color groundAlt;

  /// Cards and sheets.
  final Color surface;

  /// A card sitting on a card.
  final Color surfaceRaised;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Captions, meta, disabled.
  final Color inkFaint;

  /// Hairlines, used sparingly — space separates, not rules.
  final Color line;

  final Color brand;
  final Color brandDeep;

  /// Brand at low weight, for fills behind icons.
  final Color brandSoft;

  final Color gold;
  final Color goldBright;

  /// Text and icons on top of gold. Never white — gold on white fails contrast.
  final Color onGold;

  final Color danger;

  /// Fill painted over the blur in glass surfaces.
  final Color glassTint;

  /// The single highlight line along a glass edge.
  final Color glassEdge;

  /// Two stops for hero cards.
  final List<Color> heroGradient;

  /// The wash painted behind every page, top and bottom.
  final Color meshTop;
  final Color meshBottom;

  final bool isDark;

  static const AppTokens light = AppTokens(
    ground: Color(0xFFF6F0E4),
    groundAlt: Color(0xFFEFE7D7),
    surface: Color(0xFFFFFCF6),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF12261F),
    inkMuted: Color(0xFF3E5148),
    inkFaint: Color(0xFF7A8A80),
    line: Color(0xFFDED2BB),
    brand: Color(0xFF0F6B4F),
    brandDeep: Color(0xFF0A4A37),
    brandSoft: Color(0xFFD8E8E0),
    gold: Color(0xFFB07C21),
    goldBright: Color(0xFFD9A233),
    onGold: Color(0xFF12261F),
    danger: Color(0xFFA3312B),
    glassTint: Color(0x8CFFFCF6),
    glassEdge: Color(0x40FFFFFF),
    heroGradient: [Color(0xFFF3D089), Color(0xFFCF9B3C)],
    meshTop: Color(0x1AB07C21),
    meshBottom: Color(0x140F6B4F),
    isDark: false,
  );

  static const AppTokens dark = AppTokens(
    ground: Color(0xFF0B1411),
    groundAlt: Color(0xFF0F1D18),
    surface: Color(0xFF14231D),
    surfaceRaised: Color(0xFF1B2E27),
    ink: Color(0xFFEDE6D7),
    inkMuted: Color(0xFFB7C4BB),
    inkFaint: Color(0xFF7E8F85),
    line: Color(0xFF26362F),
    brand: Color(0xFF10B981),
    brandDeep: Color(0xFF064E3B),
    brandSoft: Color(0xFF16352B),
    gold: Color(0xFFE0AE4A),
    goldBright: Color(0xFFF0C063),
    onGold: Color(0xFF12261F),
    danger: Color(0xFFE06C64),
    glassTint: Color(0x9914231D),
    glassEdge: Color(0x1AFFFFFF),
    heroGradient: [Color(0xFFE8BC63), Color(0xFFBE8B33)],
    meshTop: Color(0x2610B981),
    meshBottom: Color(0x1AE0AE4A),
    isDark: true,
  );

  @override
  AppTokens copyWith({
    Color? ground,
    Color? groundAlt,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? brand,
    Color? brandDeep,
    Color? brandSoft,
    Color? gold,
    Color? goldBright,
    Color? onGold,
    Color? danger,
    Color? glassTint,
    Color? glassEdge,
    List<Color>? heroGradient,
    Color? meshTop,
    Color? meshBottom,
    bool? isDark,
  }) {
    return AppTokens(
      ground: ground ?? this.ground,
      groundAlt: groundAlt ?? this.groundAlt,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      gold: gold ?? this.gold,
      goldBright: goldBright ?? this.goldBright,
      onGold: onGold ?? this.onGold,
      danger: danger ?? this.danger,
      glassTint: glassTint ?? this.glassTint,
      glassEdge: glassEdge ?? this.glassEdge,
      heroGradient: heroGradient ?? this.heroGradient,
      meshTop: meshTop ?? this.meshTop,
      meshBottom: meshBottom ?? this.meshBottom,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppTokens(
      ground: mix(ground, other.ground),
      groundAlt: mix(groundAlt, other.groundAlt),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      brand: mix(brand, other.brand),
      brandDeep: mix(brandDeep, other.brandDeep),
      brandSoft: mix(brandSoft, other.brandSoft),
      gold: mix(gold, other.gold),
      goldBright: mix(goldBright, other.goldBright),
      onGold: mix(onGold, other.onGold),
      danger: mix(danger, other.danger),
      glassTint: mix(glassTint, other.glassTint),
      glassEdge: mix(glassEdge, other.glassEdge),
      heroGradient: [
        mix(heroGradient.first, other.heroGradient.first),
        mix(heroGradient.last, other.heroGradient.last),
      ],
      meshTop: mix(meshTop, other.meshTop),
      meshBottom: mix(meshBottom, other.meshBottom),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  /// The colour scheme Material widgets fall back to, derived from the tokens
  /// so a stock button never lands outside the palette.
  ColorScheme toColorScheme() {
    return ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: brand,
      onPrimary: isDark ? const Color(0xFF06251B) : Colors.white,
      primaryContainer: brandSoft,
      onPrimaryContainer: isDark ? ink : brandDeep,
      secondary: gold,
      onSecondary: onGold,
      secondaryContainer:
          isDark ? const Color(0xFF33280F) : const Color(0xFFF6E7C4),
      onSecondaryContainer: isDark ? const Color(0xFFF4DCA8) : brandDeep,
      tertiary: goldBright,
      onTertiary: onGold,
      tertiaryContainer: groundAlt,
      onTertiaryContainer: ink,
      surface: surface,
      onSurface: ink,
      surfaceContainerLowest: ground,
      surfaceContainerLow: groundAlt,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceRaised,
      surfaceContainerHighest: groundAlt,
      onSurfaceVariant: inkMuted,
      outline: line,
      outlineVariant: line,
      error: danger,
      onError: Colors.white,
      errorContainer: danger.withValues(alpha: isDark ? 0.22 : 0.14),
      onErrorContainer:
          isDark ? const Color(0xFFFFD9D6) : const Color(0xFF5C1512),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: ground,
      inversePrimary: brandDeep,
    );
  }
}

/// `context.tokens` — the only way screens should reach a colour.
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppTokens.dark
          : AppTokens.light);
}
