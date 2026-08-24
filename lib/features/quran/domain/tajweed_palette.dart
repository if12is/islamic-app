import 'package:flutter/painting.dart';

import 'tajweed.dart';

/// The colour code for the tajweed rules.
///
/// These are didactic colours, not app chrome: a reader who learns that red
/// means six counts should find red meaning six counts next year and in the
/// dark theme too. So they live here rather than in the design tokens, and
/// they are grouped by family so the code can be learned rather than memorised:
///
///  * reds and ambers are the madds, deepening with the count;
///  * greens are everything with ghunnah in it;
///  * blues are the lip rules and qalqalah;
///  * purple is iqlab, the one rule that swaps a letter for another;
///  * grey is a letter that is written and not said.
///
/// Two sets, because the reading page has a paper ground and a night ground
/// and a colour that reads on one disappears on the other.
class TajweedPalette {
  const TajweedPalette._(this._colours);

  final Map<TajweedRule, Color> _colours;

  Color of(TajweedRule rule) => _colours[rule] ?? const Color(0xFF000000);

  /// On paper, sepia, and the green reading ground.
  static const TajweedPalette onLight = TajweedPalette._({
    TajweedRule.maddLazim: Color(0xFFB3261E),
    TajweedRule.maddMuttasil: Color(0xFFC2410C),
    TajweedRule.maddMunfasil: Color(0xFFB45309),
    TajweedRule.ghunnah: Color(0xFF15803D),
    TajweedRule.idghamGhunnah: Color(0xFF047857),
    TajweedRule.ikhfa: Color(0xFF0F766E),
    TajweedRule.idghamNoGhunnah: Color(0xFF6B7B1F),
    TajweedRule.iqlab: Color(0xFF7C3AED),
    TajweedRule.ikhfaShafawi: Color(0xFF1D4ED8),
    TajweedRule.idghamShafawi: Color(0xFF2563EB),
    TajweedRule.qalqalah: Color(0xFF3730A3),
    TajweedRule.silent: Color(0xFF9CA3AF),
  });

  /// On the night ground, where the same hues would sink into the page.
  static const TajweedPalette onDark = TajweedPalette._({
    TajweedRule.maddLazim: Color(0xFFF87171),
    TajweedRule.maddMuttasil: Color(0xFFFB923C),
    TajweedRule.maddMunfasil: Color(0xFFFBBF24),
    TajweedRule.ghunnah: Color(0xFF4ADE80),
    TajweedRule.idghamGhunnah: Color(0xFF34D399),
    TajweedRule.ikhfa: Color(0xFF2DD4BF),
    TajweedRule.idghamNoGhunnah: Color(0xFFBEF264),
    TajweedRule.iqlab: Color(0xFFC4B5FD),
    TajweedRule.ikhfaShafawi: Color(0xFF93C5FD),
    TajweedRule.idghamShafawi: Color(0xFF60A5FA),
    TajweedRule.qalqalah: Color(0xFFA5B4FC),
    TajweedRule.silent: Color(0xFF6B7280),
  });

  static TajweedPalette forGround({required bool isDark}) =>
      isDark ? onDark : onLight;

  /// The rules in the order the key lists them: madds, then ghunnah, then the
  /// lip rules, then the two odd ones out.
  static const List<TajweedRule> keyOrder = [
    TajweedRule.maddLazim,
    TajweedRule.maddMuttasil,
    TajweedRule.maddMunfasil,
    TajweedRule.ghunnah,
    TajweedRule.idghamGhunnah,
    TajweedRule.ikhfa,
    TajweedRule.idghamNoGhunnah,
    TajweedRule.iqlab,
    TajweedRule.ikhfaShafawi,
    TajweedRule.idghamShafawi,
    TajweedRule.qalqalah,
    TajweedRule.silent,
  ];
}
