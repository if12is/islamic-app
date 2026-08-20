import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/seasonal_intro_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'onboarding_page.dart';
import 'seasonal_intro_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openNextScreen());
    });
  }

  Future<void> _openNextScreen() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }

    // Ramadan and the Eids open with a short film — once a day, skippable.
    await _playSeasonalIntro();
    if (!mounted) {
      return;
    }

    var showOnboarding = true;
    try {
      showOnboarding =
          ref.read(firstLaunchProvider.notifier).shouldShowOnboarding;
    } catch (e, stack) {
      AppLogger.error('Could not read first-launch flag', e, stack);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => showOnboarding ? const OnboardingPage() : const HomePage(),
      ),
    );
  }

  /// Show the seasonal opening and wait for it to finish or be skipped.
  Future<void> _playSeasonalIntro() async {
    try {
      final event = ref.read(seasonalEventProvider);
      final asset = SeasonalIntroService.assetFor(event);
      if (asset == null ||
          !SeasonalIntroService.shouldShow(appPreferences, event)) {
        return;
      }

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder:
              (context, animation, _) => FadeTransition(
                opacity: animation,
                child: SeasonalIntroScreen(
                  assetPath: asset,
                  event: event,
                  onFinished: () => Navigator.of(context).maybePop(),
                ),
              ),
        ),
      );

      // Marked only after it has actually played. Marking first meant a file
      // that failed to open burned the day's one showing.
      await SeasonalIntroService.markShown(appPreferences);
    } catch (e, stack) {
      AppLogger.warning('Seasonal intro failed: $e');
      AppLogger.debug(stack.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [tokens.brand, tokens.brandDeep],
                    ),
                    boxShadow: AppShadows.glow(tokens.brand, alpha: 0.30),
                  ),
                  child: const Icon(
                    Icons.brightness_low,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'الفجر',
                  style: TextStyle(
                    fontFamily: AppTextStyles.displayFamily,
                    fontSize: 58,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                Text(
                  'AL - FAJR',
                  style: TextStyle(
                    fontFamily: AppTextStyles.bodyFamily,
                    fontSize: 13,
                    letterSpacing: 7,
                    fontWeight: FontWeight.w600,
                    color: tokens.gold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
