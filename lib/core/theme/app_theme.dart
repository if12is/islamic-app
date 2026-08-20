import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Builds both themes out of [AppTokens] and nothing else.
///
/// There are no colour literals in this file on purpose. Every value comes
/// from the token set, so re-tuning the palette — or dressing the app for a
/// season — is a change to one object rather than a hunt through the widgets.
class AppTheme {
  AppTheme._();

  /// Body face.
  static const String fontFamily = 'Cairo';

  /// Kufic display face, used for titles and Surah names. Bundled (OFL 1.1).
  static const String displayFontFamily = 'ReemKufi';

  static ThemeData get lightTheme => from(AppTokens.light);

  static ThemeData get darkTheme => from(AppTokens.dark);

  /// The theme for a given token set. Seasonal dressing calls this with a
  /// modified copy, which is why nothing here is hard-coded.
  static ThemeData from(AppTokens tokens) {
    final colors = tokens.toColorScheme();
    final text = _textTheme(tokens);

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      fontFamily: fontFamily,
      colorScheme: colors,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      scaffoldBackgroundColor: tokens.ground,
      canvasColor: tokens.ground,
      cardColor: tokens.surface,
      dividerColor: tokens.line,
      textTheme: text,

      // Space separates, not rules: a divider has to be asked for.
      dividerTheme: DividerThemeData(
        color: tokens.line,
        thickness: 1,
        space: 1,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: displayFontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: tokens.ink,
        ),
        iconTheme: IconThemeData(color: tokens.ink),
      ),

      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      ),

      iconTheme: IconThemeData(color: tokens.inkMuted, size: 22),

      listTileTheme: ListTileThemeData(
        iconColor: tokens.inkMuted,
        textColor: tokens.ink,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.brand,
          side: BorderSide(color: tokens.line),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brand,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.brand,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: tokens.groundAlt,
        selectedColor: tokens.brand,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.inkMuted,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: tokens.inkFaint,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: tokens.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: tokens.danger),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        titleTextStyle: TextStyle(
          fontFamily: displayFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.ink,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: tokens.ground,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.brand,
        linearTrackColor: tokens.groundAlt,
        circularTrackColor: tokens.groundAlt,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? tokens.brand
                  : tokens.inkFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? tokens.brand.withValues(alpha: 0.28)
                  : tokens.groundAlt,
        ),
        trackOutlineColor: WidgetStateProperty.all(tokens.line),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.brand,
        inactiveTrackColor: tokens.groundAlt,
        thumbColor: tokens.brand,
        overlayColor: tokens.brand.withValues(alpha: 0.12),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(BorderSide(color: tokens.line)),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
          ),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.ink,
          borderRadius: AppRadii.smAll,
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: tokens.ground,
        ),
      ),
    );
  }

  static TextTheme _textTheme(AppTokens tokens) {
    TextStyle display(double size, [FontWeight weight = FontWeight.w600]) =>
        TextStyle(
          fontFamily: displayFontFamily,
          fontSize: size,
          fontWeight: weight,
          height: 1.45,
          color: tokens.ink,
        );

    TextStyle body(double size, [FontWeight weight = FontWeight.w500]) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          height: 1.8,
          color: tokens.ink,
        );

    return TextTheme(
      displayLarge: display(40, FontWeight.w700),
      displayMedium: display(32, FontWeight.w700),
      displaySmall: display(26),
      headlineLarge: display(24),
      headlineMedium: display(20),
      headlineSmall: display(17),
      titleLarge: display(17),
      titleMedium: body(15, FontWeight.w700),
      titleSmall: body(14, FontWeight.w600),
      bodyLarge: body(16),
      bodyMedium: body(14.5),
      bodySmall: body(13).copyWith(color: tokens.inkMuted, height: 1.7),
      labelLarge: body(14, FontWeight.w700),
      labelMedium: body(12.5, FontWeight.w600).copyWith(color: tokens.inkMuted),
      labelSmall: body(11.5, FontWeight.w600).copyWith(color: tokens.inkFaint),
    );
  }
}
