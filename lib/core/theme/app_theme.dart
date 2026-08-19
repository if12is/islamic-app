import 'package:flutter/material.dart';

/// Application theme configuration with full support for light and dark modes.
///
/// Implements the Islamic app design system with:
/// - Material Design 3
/// - Cairo font for Arabic RTL support
/// - Comprehensive color palette
/// - Consistent typography and component styling
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // ========================
  // Light Mode Colors
  // ========================
  
  static const Color primaryLight = Color(0xFF003527);
  static const Color primaryDarkLight = Color(0xFF064E3B);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  
  static const Color secondaryLight = Color(0xFF735C00);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  
  static const Color backgroundLight = Color(0xFFF9F9F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1A1C1C);
  static const Color onSurfaceVariantLight = Color(0xFF404944);
  
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  
  // ========================
  // Dark Mode Colors
  // ========================
  
  static const Color primaryDark = Color(0xFF10B981);
  static const Color primaryDarkDark = Color(0xFF064E3B); // Used as primaryContainer equivalent
  static const Color onPrimaryDark = Color(0xFF111827);
  
  static const Color secondaryDark = Color(0xFFE9C349);
  static const Color onSecondaryDark = Color(0xFF241A00);
  
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color onSurfaceDark = Color(0xFFF9FAFB);
  static const Color onSurfaceVariantDark = Color(0xFF9CA3AF);
  
  static const Color errorDark = Color(0xFFBA1A1A);
  static const Color onErrorDark = Color(0xFFFFFFFF);

  // ========================
  // Shared Config
  // ========================
  
  static const String fontFamily = 'Cairo';
  static const String altFontFamily = 'Tajawal';
  static const double borderRadius = 8;

  // ========================
  // Light Theme Data
  // ========================
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        onPrimary: onPrimaryLight,
        secondary: secondaryLight,
        onSecondary: onSecondaryLight,
        surface: surfaceLight,
        onSurface: onSurfaceLight,
        error: errorLight,
        onError: onErrorLight,
      ),
      
      scaffoldBackgroundColor: backgroundLight,
      cardColor: surfaceLight,
      
      appBarTheme: AppBarTheme(
        backgroundColor: primaryLight,
        foregroundColor: onPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textThemeLight().headlineMedium,
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryLight,
        unselectedItemColor: onSurfaceVariantLight,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      textTheme: _textThemeLight(),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: onPrimaryLight,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF5F5F5),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorLight, width: 2),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: primaryLight,
      ),
    );
  }

  // ========================
  // Dark Theme Data
  // ========================
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      
      colorScheme: ColorScheme.dark(
        primary: primaryDark,
        onPrimary: onPrimaryDark,
        primaryContainer: primaryDarkDark,
        onPrimaryContainer: Colors.white,
        secondary: secondaryDark,
        onSecondary: onSecondaryDark,
        surface: surfaceDark,
        onSurface: onSurfaceDark,
        onSurfaceVariant: onSurfaceVariantDark,
        error: errorDark,
        onError: onErrorDark,
      ),
      
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: onSurfaceDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textThemeDark().headlineMedium,
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryDark,
        unselectedItemColor: onSurfaceVariantDark,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      textTheme: _textThemeDark(),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: onPrimaryDark,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2C2C2C),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorDark, width: 2),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: primaryDark,
      ),
    );
  }

  // ========================
  // Text Themes
  // ========================
  
  static TextTheme _textThemeLight() {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurfaceLight,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurfaceLight,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurfaceLight,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurfaceLight,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurfaceLight,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurfaceLight,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurfaceLight,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurfaceLight,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceLight,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariantLight,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariantLight,
      ),
    );
  }

  static TextTheme _textThemeDark() {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurfaceDark,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurfaceDark,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurfaceDark,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurfaceDark,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurfaceDark,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurfaceDark,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurfaceDark,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurfaceDark,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceDark,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariantDark,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariantDark,
      ),
    );
  }
}
