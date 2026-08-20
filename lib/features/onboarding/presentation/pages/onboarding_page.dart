import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/motif_icon.dart';
import '../../../../core/widgets/islamic_icon.dart';
import '../../../../core/widgets/islamic_ornaments.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    final tokens = context.tokens;

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: tokens.brandDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The panel runs the full height. The earlier version faded to
            // cream two thirds down and put white text on it — unreadable, and
            // it left a bare strip underneath.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tokens.brandDeep,
                    Color.lerp(tokens.brandDeep, tokens.ink, 0.7)!,
                    tokens.ink,
                  ],
                ),
              ),
            ),
            // A single quiet lattice, low enough to be texture rather than
            // pattern, and fading out before it reaches the words.
            Positioned.fill(
              child: CustomPaint(
                painter: _PanelPainter(colour: tokens.goldBright),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: TextButton(
                        onPressed: _isFinishing
                            ? null
                            : () =>
                                  _finishOnboarding(requestNotifications: false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        child: Text(context.tr('skip')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      children: [
                        _buildFeaturePage(
                          context,
                          icon: IslamicIcon.crescentStars,
                          titleKey: 'onboarding_welcome_title',
                          bodyKey: 'onboarding_welcome_body',
                        ),
                        _buildFeaturePage(
                          context,
                          icon: IslamicIcon.compass,
                          titleKey: 'onboarding_location_title',
                          bodyKey: 'onboarding_location_body',
                        ),
                        _buildFeaturePage(
                          context,
                          icon: IslamicIcon.bell,
                          titleKey: 'onboarding_notifications_title',
                          bodyKey: 'onboarding_notifications_body',
                        ),
                      ],
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
      AppLogger.error(
        'Failed to persist onboarding completion',
        error,
        stackTrace,
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  Widget _buildFeaturePage(
    BuildContext context, {
    required IslamicIcon icon,
    required String titleKey,
    required String bodyKey,
  }) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // The motif behind the icon, big and faint: decoration that does not
          // compete with the sentence it sits above.
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(190),
                  painter: MotifPainter(
                    motif: Motif.star8,
                    color: tokens.goldBright.withValues(alpha: 0.14),
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                      color: tokens.goldBright.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Center(
                    child: AppIcon(icon, size: 44, color: tokens.goldBright),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          Text(
            context.tr(titleKey),
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              context,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr(bodyKey),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              context,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.enter,
                width: _currentPage == index ? 26 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.pillAll,
                  color:
                      _currentPage == index
                          ? tokens.goldBright
                          : tokens.inkFaint.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.goldBright,
                foregroundColor: tokens.onGold,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg + 2,
                ),
              ),
              onPressed:
                  _isFinishing
                      ? null
                      : () async {
                        if (_currentPage == 0) {
                          await _pageController.nextPage(
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                          );
                          return;
                        }
                        if (_currentPage == 1) {
                          await _handleLocationPermission();
                          return;
                        }
                        await _finishOnboarding(requestNotifications: true);
                      },
              child:
                  _isFinishing
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        _primaryActionLabel(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
            ),
          ),
          if (_currentPage > 0)
            TextButton(
              onPressed:
                  _isFinishing
                      ? null
                      : () => _pageController.previousPage(
                        duration: AppMotion.base,
                        curve: AppMotion.enter,
                      ),
              child: Text(context.tr('back')),
            ),
        ],
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

/// The panel behind the words: an arch and a sparse lattice that fades out
/// before it reaches the text.
class _PanelPainter extends CustomPainter {
  const _PanelPainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    // Only the top half carries texture, and even there it fades.
    final band = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    canvas
      ..saveLayer(band, Paint())
      ..clipRect(band);

    IslamicOrnaments.lattice(
      canvas,
      Rect.fromLTWH(-30, -30, size.width + 60, size.height * 0.6),
      colour.withValues(alpha: 0.16),
      cell: 74,
    );

    // Fade the pattern to nothing towards the middle of the screen.
    canvas
      ..drawRect(
        band,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(band),
      )
      ..restore();

    final arch = IslamicOrnaments.archPath(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.08,
        size.width * 0.72,
        size.height * 0.60,
      ),
      pointPixels: 104,
    );
    canvas.drawPath(
      arch,
      Paint()
        ..color = colour.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.colour != colour;
}
