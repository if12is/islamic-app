import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Hamburger that opens Settings from any shell tab.
class ShellMenuButton extends ConsumerWidget {
  const ShellMenuButton({super.key, this.iconSize = 28});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        Icons.menu,
        color: Theme.of(context).colorScheme.onSurface,
        size: iconSize,
      ),
      onPressed: () => ref.read(mainTabIndexProvider.notifier).openSettings(),
    );
  }
}

/// Profile avatar that opens Settings from any shell tab.
class ShellProfileButton extends ConsumerWidget {
  const ShellProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => ref.read(mainTabIndexProvider.notifier).openSettings(),
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(context).cardColor,
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
