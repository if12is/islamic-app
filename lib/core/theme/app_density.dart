import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

/// How tightly a screen should be packed, from its width alone.
///
/// The layout was drawn for a phone around 390 logical pixels wide. On a
/// 320-wide set the same 13px labels, 20px page gutters and 96px shortcut
/// tiles fight the width, so words wrap or clip even at the normal font size.
/// This factor is what lets one set of widgets serve both, without every
/// screen inventing its own "if small" branch.
class AppDensity {
  const AppDensity({
    required this.width,
    required this.textFactor,
    required this.pagePadding,
  });

  final double width;

  /// Multiplier for the app's text. 1.0 on a comfortable phone, down to
  /// [minTextFactor] on the tightest width we still claim to support.
  final double textFactor;

  /// Side gutter for a scrolling page.
  final double pagePadding;

  /// Narrower than a typical compact Android (360).
  bool get isTight => width < 360;

  /// Narrower than the width the screens were drawn at.
  bool get isCompact => width < comfortableWidth;

  static const double comfortableWidth = 390;
  static const double tightWidth = 320;
  static const double minTextFactor = 0.86;
  static const double tightPage = 14;

  /// Lines reserved for every shortcut label, whether the words use them
  /// or not. A 1-line tile next to a 2-line tile is what made the home
  /// grid look assembled from parts.
  static const int shortcutLabelLines = 2;

  static const double shortcutLabelHeight = 1.25;

  /// Lines reserved for every nav label. "مواقيت الصلاة" and "الورد اليومي"
  /// wrap; "القرآن" sits on the first line. The slot height stays the same.
  static const int navLabelLines = 2;

  static const double navLabelHeight = 1.15;

  /// Shared shortcut tile height so every cell in the grid is one size.
  double get shortcutTileHeight => isTight ? 88 : 104;

  double get shortcutIconSize => isTight ? 22 : 26;

  double get shortcutLabelSize => isTight ? 12 : 13;

  double get shortcutLabelBoxHeight =>
      shortcutLabelSize * shortcutLabelHeight * shortcutLabelLines;

  /// Readable on a comfortable phone; still two wrapped lines on a 320.
  double get navLabelSize => isTight ? 10 : 11;

  double get navLabelBoxHeight => navLabelSize * navLabelHeight * navLabelLines;

  /// Icon + gap + the reserved two-line label. Kept close to 50 so the
  /// floating bar does not grow and steal the page.
  double get navSlotHeight => 22 + 2 + navLabelBoxHeight;

  static AppDensity of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static AppDensity fromWidth(double width) {
    if (width >= comfortableWidth) {
      return AppDensity(
        width: width,
        textFactor: 1,
        pagePadding: AppSpacing.page,
      );
    }
    final t = ((width - tightWidth) / (comfortableWidth - tightWidth)).clamp(
      0.0,
      1.0,
    );
    return AppDensity(
      width: width,
      textFactor: minTextFactor + (1 - minTextFactor) * t,
      pagePadding: tightPage + (AppSpacing.page - tightPage) * t,
    );
  }

  double scale(double value) => value * textFactor;
}
