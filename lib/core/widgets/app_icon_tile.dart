import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// How much weight an icon carries on the screen it sits on.
///
/// Not a size in pixels — a role. Passing a role rather than a number is what
/// stops the same kind of icon being 18px in one card and 26px in the next,
/// which is how the app ended up with icons that plainly did not belong to
/// each other.
enum AppIconRole {
  /// Beside a line of text: a unit, a hint, a meta label.
  inline,

  /// The leading mark of a list row.
  row,

  /// The mark that names a card or a section.
  card,

  /// The one mark a whole screen is introduced by.
  feature,
}

/// The colour family an icon speaks in.
enum AppIconTone {
  /// The default. Brand green on a soft brand wash.
  brand,

  /// The accent, for the one thing on the screen that is special.
  accent,

  /// No opinion — a control, not a subject.
  neutral,

  /// Something is wrong.
  danger,
}

/// One icon, drawn the same way everywhere.
///
/// The app had 132 hand-placed `Icon(Icons.…)` calls against 5 uses of a shared
/// component, and it showed: some icons sat on a tinted circle and some on
/// nothing, at sizes between 15 and 26, in whichever of the palette's colours
/// the nearest line of code happened to use. Two cards side by side did not
/// look like they came from the same app.
///
/// This is the one component. Give it a role and a tone; it decides the size,
/// the container, the radius and the colour, so those decisions are made once
/// and are the same on every screen.
class AppIconTile extends StatelessWidget {
  const AppIconTile(
    this.icon, {
    super.key,
    this.role = AppIconRole.row,
    this.tone = AppIconTone.brand,
    this.filled = true,
    this.selected = false,
  });

  final IconData icon;
  final AppIconRole role;
  final AppIconTone tone;

  /// Whether the icon sits on its own soft container.
  ///
  /// An inline icon never does — a chip behind a word in a sentence is noise —
  /// so this is ignored for [AppIconRole.inline].
  final bool filled;

  /// Draws the tone at full strength, for "this is the one you are on".
  final bool selected;

  /// The box, by role. Inline has none.
  static double boxFor(AppIconRole role) => switch (role) {
    AppIconRole.inline => 0,
    AppIconRole.row => 40,
    AppIconRole.card => 44,
    AppIconRole.feature => 56,
  };

  /// The glyph, by role.
  ///
  /// Held at a constant fraction of its box so an icon never looks cramped in
  /// one size and lost in another.
  static double glyphFor(AppIconRole role) => switch (role) {
    AppIconRole.inline => 17,
    AppIconRole.row => 20,
    AppIconRole.card => 21,
    AppIconRole.feature => 26,
  };

  Color _foreground(AppTokens tokens) => switch (tone) {
    AppIconTone.brand => tokens.brand,
    // goldInk, not gold: this colour is read, and the accent that fills the
    // hero card does not clear 4.5:1 against cream.
    AppIconTone.accent => tokens.goldInk,
    AppIconTone.neutral => tokens.inkMuted,
    AppIconTone.danger => tokens.danger,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = _foreground(tokens);
    final glyph = glyphFor(role);

    if (role == AppIconRole.inline || !filled) {
      return Icon(icon, size: glyph, color: tint);
    }

    final box = boxFor(role);

    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // One wash for every icon in the app, at one strength. The alpha is
        // higher when selected rather than the colour being swapped, so the
        // state reads as the same object turned up, not a different object.
        color: tint.withValues(alpha: selected ? 0.22 : 0.11),
        // A superellipse rather than a circle: the cards are rounded
        // rectangles, and a circle inside them reads as borrowed from
        // somewhere else. Radius is a third of the box, which keeps the same
        // curvature at every role.
        borderRadius: BorderRadius.circular(box / 3),
      ),
      child: Icon(icon, size: glyph, color: tint),
    );
  }
}

/// A small count or state sitting on an icon tile, for lists that keep score.
///
/// The number and the icon share one background family. They were two
/// different fills in the light theme, which is why the light Azkar cards
/// looked assembled from parts while the dark ones looked designed.
class AppIconCount extends StatelessWidget {
  const AppIconCount({
    super.key,
    required this.count,
    this.tone = AppIconTone.brand,
  });

  final String count;
  final AppIconTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = switch (tone) {
      AppIconTone.brand => tokens.brand,
      AppIconTone.accent => tokens.goldInk,
      AppIconTone.neutral => tokens.inkMuted,
      AppIconTone.danger => tokens.danger,
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 24,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        // The same 0.11 wash the icon tile uses, so the pair reads as one
        // object in both themes instead of two colours that happen to be near
        // each other.
        color: tint.withValues(alpha: 0.11),
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(
        count,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}
