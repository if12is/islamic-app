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
