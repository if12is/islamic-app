import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/app_services.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all app services (Hive, Dio, etc.)
  await AppServices.initialize();
  
  // Initialize SharedPreferences and theme provider
  await initializeThemeProvider();

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
  const IslamicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode - will rebuild when theme changes
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      // App metadata
      title: 'Islamic App',
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

      /// Use Arabic as the default locale (first in list = default)
      locale: const Locale('ar', ''),

      // ========================
      // Home Screen
      // ========================
      home: const HomePage(),

      // ========================
      // Global Settings
      // ========================
      
      /// Use Material 3 design
      useMaterial3: true,

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
