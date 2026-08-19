import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/app_services.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/pages/splash_screen.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all app services (Hive, Dio, etc.)
  await AppServices.initialize();
  
  // Initialize SharedPreferences and theme provider
  await initializeThemeProvider();

  // Warm offline-first caches in the background.
  unawaited(runStartupSync());

  // Run the app
  runApp(const ProviderScope(child: IslamicApp()));
}

/// Main application widget.
///
/// This is the root of the entire application tree.
/// It sets up:
/// - Material 3 design
/// - RTL support for Arabic
/// - Light and dark themes
/// - Provider scope for Riverpod
class IslamicApp extends ConsumerWidget {
  const IslamicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode - will rebuild when theme changes
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      // App metadata
      onGenerateTitle: (context) => context.tr('app_title'),
      debugShowCheckedModeBanner: false,

      // ========================
      // Theme Configuration
      // ========================
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // ========================
      // Localization & RTL Support
      // ========================
      localizationsDelegates: const [
        /// Provides localized strings for Material widgets like buttons, dialogs, etc.
        GlobalMaterialLocalizations.delegate,
        
        /// Provides localized text directions (LTR/RTL)
        GlobalWidgetsLocalizations.delegate,
        
        /// Provides localized strings for Cupertino (iOS-style) widgets
        GlobalCupertinoLocalizations.delegate,
      ],

      /// Supported locales for the app
      supportedLocales: const [
        /// Arabic - RTL language
        Locale('ar', ''),
        
        /// English - LTR language
        Locale('en', ''),
      ],

      /// Locale is user-selectable and persisted via Riverpod/SharedPreferences.
      locale: locale,

      // ========================
      // Home Screen
      // ========================
      home: const SplashScreen(),

      // ========================
      // Global Settings
      // ========================
      
      /// Enable scrollbar visibilty by default
      scrollBehavior: const ScrollBehavior(),
    );
  }
}

/// Scroll behavior configuration.
///
/// Customizes scrolling behavior across platforms.
class ScrollBehavior extends MaterialScrollBehavior {
  const ScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
