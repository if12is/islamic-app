import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'onboarding_page.dart';

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
        builder: (_) =>
            showOnboarding ? const OnboardingPage() : const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.brightness_low,
                  color: onSurface,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'الفجر',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: onSurface,
                  fontFamily: 'Cairo',
                  letterSpacing: -1,
                ),
              ),
              Text(
                'AL - FAJR',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w500,
                  color: colors.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
