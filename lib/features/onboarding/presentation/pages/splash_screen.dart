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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Simulate loading transition then read routing logic
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Optional: Add a faint background pattern here if needed,
          // for now we stick to the solid requested background color.

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B4633),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.star_border_purple500_outlined, // Placeholder for the actual logo star/crescent icon
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Text "الفجر" (Al-Fajr)
                const Text(
                  "الفجر",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B4633),
                    fontFamily: 'Amiri', // Or any appropriate Arabic font
                  ),
                ),
                const Text(
                  "AL - FAJR",
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0B4633),
                  ),
                ),
                const SizedBox(height: 48),

                // Tiny indicator dots (design detail from original)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(const Color(0xFFEBECEE)),
                    const SizedBox(width: 8),
                    _buildDot(const Color(0xFFEBECEE)),
                    const SizedBox(width: 8),
                    _buildDot(const Color(0xFF0B4633)), // Active dot
                  ],
                ),
              ],
            ),
          ),

          // Bottom Loading Bar Section
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom Shimmering Loader Bar
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      height: 4, // Thin, elegant preloader
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBECEE), // Light grey base
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final leftOffset = -width + (width * 2 * _animationController.value);
                            
                            return Stack(
                              children: [
                                Positioned(
                                  left: leftOffset,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: width,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          const Color(0xFFF6D167), // Golden-yellow
                                          Colors.white.withOpacity(0.5),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 0.4, 0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Status Texts
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "INITIALIZING SANCTUARY",
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B4633),
                      ),
                    ),
                    Text(
                      "جاري التحميل...",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Amiri', // Or appropriate Arabic font
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
