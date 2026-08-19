import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/app_providers.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'onboarding_page.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _logoController;
  late Animation<double> _revealAnimation;

  @override
  void initState() {
    super.initState();
    // Progress bar animation
    _progressController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat();

    // Logo reveal animation
    _logoController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));
        
    _revealAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _logoController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final isFirstLaunch = ref.read(firstLaunchProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isFirstLaunch ? const OnboardingPage() : const HomePage(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // "العربي مفروض من اليمين للشمال"
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Background Pattern
            Positioned.fill(
              child: CustomPaint(
                painter: StarPatternPainter(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            
            // Decorative Gradients (Atmospheric Tones)
            Positioned(
              top: 0, left: 0, right: 0, height: 256,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0, height: 256,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Iconography with Animated Reveal
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                         // Glow effect
                         Positioned(
                           bottom: -10,
                           left: 0, right: 0,
                           height: 60,
                           child: ImageFilterFiltered(
                             imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                             child: Container(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                           )
                         ),
                         
                         Icon(
                           Icons.brightness_low,
                           color: Theme.of(context).textTheme.bodyLarge!.color!,
                           size: 60,
                         ),
                         
                         // Animated Mask to reveal the star
                         AnimatedBuilder(
                           animation: _revealAnimation,
                           builder: (context, child) {
                             return Positioned(
                               top: 8 - (30 * (1 - _revealAnimation.value)),
                               left: 8 - (30 * (1 - _revealAnimation.value)), 
                               child: Opacity(
                                 opacity: _revealAnimation.value,
                                 child: Container(
                                   width: 80, height: 80,
                                   decoration: BoxDecoration(
                                     color: Theme.of(context).colorScheme.primaryContainer,
                                     shape: BoxShape.circle,
                                   ),
                                 ),
                               ),
                             );
                           },
                         )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Text "الفجر"
                  Text(
                    "الفجر",
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge!.color!,
                      fontFamily: 'Cairo', // Same requested font
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    "AL - FAJR",
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 6.0,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Three dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(Theme.of(context).dividerColor),
                      const SizedBox(width: 8),
                      _buildDot(Theme.of(context).dividerColor),
                      const SizedBox(width: 8),
                      _buildDot(Theme.of(context).colorScheme.secondary),
                    ],
                  ),
                ],
              ),
            ),

            // Loading Bar Section
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Bar
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, child) {
                                  final width = constraints.maxWidth;
                                  final leftOffset = -width + (width * 2 * _progressController.value);
                                  
                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: leftOffset,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: width * 0.75,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context).colorScheme.primary,
                                                Theme.of(context).colorScheme.secondary,
                                                Theme.of(context).colorScheme.primary,
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Status Texts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "جاري التحميل...",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            "INITIALIZING SANCTUARY",
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class ImageFilterFiltered extends StatelessWidget {
  final ImageFilter imageFilter;
  final Widget child;
  const ImageFilterFiltered({super.key, required this.imageFilter, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: imageFilter,
        child: child,
      ),
    );
  }
}

class StarPatternPainter extends CustomPainter {
  final Color color;

  StarPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Star path based on the SVG 
    final path = Path();
    path.moveTo(30, 0);
    path.lineTo(35.878, 18.09);
    path.lineTo(54.9, 18.09);
    path.lineTo(39.512, 29.27);
    path.lineTo(45.39, 47.36);
    path.lineTo(30, 36.18);
    path.lineTo(14.612, 47.36);
    path.lineTo(20.49, 29.27);
    path.lineTo(5.1, 18.09);
    path.lineTo(24.122, 18.09);
    path.close();

    const double spacingX = 75.0;
    const double spacingY = 75.0;
    
    int row = 0;
    for (double y = -40; y < size.height + 100; y += spacingY) {
      double offsetX = (row % 2 == 0) ? 0 : spacingX / 2;
      for (double x = -40 - offsetX; x < size.width + 100; x += spacingX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(0.65); // Adjust star size slightly
        canvas.drawPath(path, paint);
        canvas.restore();
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
