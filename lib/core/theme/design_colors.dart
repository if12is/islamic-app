import 'package:flutter/material.dart';

class DesignColors {
  const DesignColors._();

  static const Color bg = Color(0xFF111827);
  static const Color card = Color(0xFF1F2937);
  static const Color line = Color(0xFF374151);

  static const Color primary = Color(0xFF10B981);
  static const Color primaryDeep = Color(0xFF064E3B);
  static const Color primarySoft = Color(0xFF95D3BA);

  static const Color gold = Color(0xFFE9C349);
  static const Color goldStrong = Color(0xFFEAB308);

  static const Color text = Color(0xFFF9FAFB);
  static const Color textMuted = Color(0xFF9CA3AF);
}

extension AppThemeColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Chip, icon-circle, and muted button fill. Never use [ThemeData.dividerColor].
  Color get mutedFill => colors.surfaceContainerHighest;
}