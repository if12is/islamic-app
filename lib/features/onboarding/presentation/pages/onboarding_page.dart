import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';

/// Onboarding page showing welcome screens for new users.
///
/// Features:
/// - 3-page welcome flow
/// - Location permission request
/// - Notification permission request
/// - Beautiful page transitions
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: isDark ? 0.36 : 0.18),
              Theme.of(context).scaffoldBackgroundColor,
              colorScheme.surface.withValues(alpha: isDark ? 0.98 : 0.94),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: context.isAppRtl ? null : -48,
              left: context.isAppRtl ? -48 : null,
              child: IgnorePointer(
                child: _GlowOrb(
                  color: colorScheme.tertiary
                      .withValues(alpha: isDark ? 0.24 : 0.16),
                  size: 180,
                ),
              ),
            ),
            Positioned(
              bottom: -88,
              left: context.isAppRtl ? null : -56,
              right: context.isAppRtl ? -56 : null,
              child: IgnorePointer(
                child: _GlowOrb(
                  color: colorScheme.primary
                      .withValues(alpha: isDark ? 0.20 : 0.14),
                  size: 220,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isFinishing
                              ? null
                              : () => _finishOnboarding(
                                    requestNotifications: false,
                                  ),
                          child: Text(context.tr('skip')),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (int page) =>
                            setState(() => _currentPage = page),
                        children: [
                          _buildFeaturePage(
                            context,
                            icon: Icons.auto_awesome,
                            accent: colorScheme.tertiary,
                            titleKey: 'onboarding_welcome_title',
                            bodyKey: 'onboarding_welcome_body',
                          ),
                          _buildFeaturePage(
                            context,
                            icon: Icons.location_on,
                            accent: colorScheme.primary,
                            titleKey: 'onboarding_location_title',
                            bodyKey: 'onboarding_location_body',
                          ),
                          _buildFeaturePage(
                            context,
                            icon: Icons.notifications_active,
                            accent: colorScheme.secondary,
                            titleKey: 'onboarding_notifications_title',
                            bodyKey: 'onboarding_notifications_body',
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomNavigation(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLocationPermission() async {
    final messenger = ScaffoldMessenger.of(context);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) {
      return;
    }
    if (!serviceEnabled) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('location_services_disabled'))),
      );
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('location_permission_required'))),
      );
    } else {
      unawaited(runStartupSync(force: true));
    }

    if (!mounted) {
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding({bool requestNotifications = true}) async {
    if (_isFinishing) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      if (requestNotifications) {
        await NotificationService.requestPermissions().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            AppLogger.warning('Notification permission request timed out');
            return false;
          },
        );
      }
      unawaited(runStartupSync(force: true));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to finish onboarding', error, stackTrace);
    }

    try {
      await ref.read(firstLaunchProvider.notifier).completeOnboarding();
    } catch (error, stackTrace) {
      AppLogger.error('Failed to persist onboarding completion', error, stackTrace);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Widget _buildFeaturePage(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String titleKey,
    required String bodyKey,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.88),
                      Theme.of(context).colorScheme.primary,
                    ],
                  ),
                ),
                child: Icon(icon, size: 42, color: Colors.white),
              ),
              const SizedBox(height: 30),
              Text(
                context.tr(titleKey),
                textDirection: context.appTextDirection,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 14),
              Text(
                context.tr(bodyKey),
                textDirection: context.appTextDirection,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _currentPage == index ? 24 : 10,
                    height: 10,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _isFinishing
                          ? null
                          : () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                      child: Text(context.tr('back')),
                    )
                  else
                    const SizedBox(width: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isFinishing
                          ? null
                          : () async {
                              if (_currentPage == 0) {
                                await _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                return;
                              }

                              if (_currentPage == 1) {
                                await _handleLocationPermission();
                                return;
                              }

                              await _finishOnboarding(
                                requestNotifications: true,
                              );
                            },
                      child: _isFinishing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_primaryActionLabel(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _primaryActionLabel(BuildContext context) {
    if (_currentPage == 0) {
      return context.tr('next_btn');
    }

    if (_currentPage == 1) {
      return context.tr('enable_location');
    }

    return context.tr('enable_notifications');
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
