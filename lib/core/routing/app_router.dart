import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../localization/app_localizations.dart';

// Import features later
// import '../../features/home/presentation/pages/home_page.dart';
// import '../../features/onboarding/presentation/pages/onboarding_page.dart';
// import '../../features/onboarding/presentation/pages/splash_page.dart';

// Dummy pages for routing stub
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) =>
  Scaffold(body: Center(child: Text(context.tr('app_title'))));
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});
  @override
  Widget build(BuildContext context) =>
  Scaffold(body: Center(child: Text(context.tr('onboarding_welcome_title'))));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) =>
  Scaffold(body: Center(child: Text(context.tr('home'))));
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  ],
);
