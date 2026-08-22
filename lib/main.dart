import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/app_services.dart';
import 'core/services/notification_router.dart';
import 'core/services/notification_scheduler.dart';
import 'core/services/notification_service.dart';
import 'core/services/seasonal_theme.dart';
import 'core/theme/design_tokens.dart';
import 'core/widgets/seasonal_decor.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/quran/data/services/reciter_catalogue.dart';
import 'features/onboarding/presentation/pages/splash_screen.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
  runApp(const ProviderScope(child: IslamicApp()));
}

/// Start the UI even if a plugin hangs. A native splash freeze is worse than
/// a missing notification channel on first launch.
Future<void> _bootstrap() async {
  try {
    await AppServices.initialize();
  } catch (e, stack) {
    AppLogger.error('App services failed to initialize', e, stack);
  }

  if (!kIsWeb) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.islamicapp.islamic_app.audio',
        androidNotificationChannelName: 'Quran playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/launcher_icon',
      ).timeout(const Duration(seconds: 5));
    } catch (e, stack) {
      AppLogger.error('Background audio init failed', e, stack);
    }
  }

  try {
    await initializeThemeProvider();
  } catch (e, stack) {
    AppLogger.error('Preferences init failed', e, stack);
  }

  unawaited(runStartupSync());
  unawaited(NotificationScheduler.refresh());
  unawaited(NotificationService.handleLaunchPayload());
  // Teach the audio URL builder about every reciter before anything asks it
  // for one. Cached after the first run, so this is usually a disk read.
  unawaited(ReciterCatalogue.load());
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
    final season = ref.watch(seasonalEventProvider);

    // Ramadan and the two Eids shift the accent and the wash behind the page;
    // the green identity stays put so the app never becomes unfamiliar.
    ThemeData themeFor(AppTokens tokens) =>
        AppTheme.from(SeasonalTheme.dress(tokens, season));

    return MaterialApp(
      // App metadata
      onGenerateTitle: (context) => context.tr('app_title'),
      debugShowCheckedModeBanner: false,

      /// Lets notification taps open a screen without a BuildContext.
      navigatorKey: appNavigatorKey,

      // ========================
      // Theme Configuration
      // ========================
      theme: themeFor(AppTokens.light),
      darkTheme: themeFor(AppTokens.dark),
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

      /// Once the first screen is up, open whatever a notification asked for.
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationRouter.flushPending();
        });
        // One place tells the whole tree which season it is; every scaffold
        // and the nav bar pick their decoration up from here.
        return SeasonalDecorScope(
          event: season,
          child: child ?? const SizedBox.shrink(),
        );
      },

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
