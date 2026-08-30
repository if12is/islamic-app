import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../providers/app_providers.dart';

/// Switches the app between light and dark, from any shell tab.
///
/// This is what the two header buttons became. There were three ways to reach
/// Settings from every screen — a hamburger top left, an avatar top right, and
/// a tab in the bar — and the header is the most valuable space in the app to
/// have spent twice on a destination that was already one tap away.
///
/// A theme switch earns it instead: it is used far more often than Settings,
/// it is worth reaching in one tap rather than three, and it is the kind of
/// control that has to be somewhere constant to be found at all. It also shows
/// its own state, which the gear never did.
class ShellThemeButton extends ConsumerWidget {
  const ShellThemeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: IconButton(
        tooltip: context.tr(isDark ? 'theme_to_light' : 'theme_to_dark'),
        onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        icon: AnimatedSwitcher(
          duration: AppMotion.base,
          // Rotate rather than fade: the two glyphs are a sun and a moon, and
          // a crossfade between them is a smudge.
          transitionBuilder:
              (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 22,
            color: tokens.ink,
          ),
        ),
      ),
    );
  }
}

/// Opens the reader's own profile, which is the one thing the header used to
/// promise and did not deliver — the avatar opened Settings, not a profile.
class ShellProfileButton extends ConsumerWidget {
  const ShellProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final profile = ref.watch(userProfileProvider);
    final initial = _initialOf(profile.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Tooltip(
        message: context.tr('profile'),
        child: InkWell(
          // Pushed, not a tab. Settings stopped being a destination in the
          // bar — it was reachable three ways and the wird none — so it opens
          // over whatever screen asked for it and closes back to it.
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // The same wash as every icon tile, so the header belongs to
              // the same set as the cards under it.
              color: tokens.brand.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                initial.isEmpty
                    ? Icon(
                      Icons.person_outline_rounded,
                      size: 19,
                      color: tokens.brand,
                    )
                    : Text(
                      initial,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: tokens.brand,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  static String _initialOf(String name) {
    for (final word in name.trim().split(RegExp(r'\s+'))) {
      if (word.isNotEmpty) {
        return word.characters.first;
      }
    }
    return '';
  }
}
