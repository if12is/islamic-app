import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';
import '../../core/constants/app_constants.dart';

/// Settings page for app configuration.
///
/// Features:
/// - Toggle dark/light theme
/// - Change prayer calculation method
/// - Notification settings
/// - About app information
class SettingsPage extends ConsumerWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final prayerMethod = ref.watch(prayerMethodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ========================
          // Display Settings
          // ========================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Display',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          
          // Theme Toggle
          CheckboxListTile(
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              if (value == true) {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
              } else {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
              }
            },
          ),

          const Divider(),

          // ========================
          // Prayer Settings
          // ========================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Prayer Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Calculation Method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<int>(
              value: prayerMethod,
              items: AppConstants.prayerCalculationMethods.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(prayerMethodProvider.notifier).setMethod(value);
                }
              },
              isExpanded: true,
            ),
          ),

          const Divider(),

          // ========================
          // About
          // ========================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),

          ListTile(
            title: const Text('About This App'),
            subtitle: const Text(
              'A comprehensive Islamic app with prayer times, Quran, Azkar, and more.',
            ),
          ),

          const Divider(),

          // ========================
          // Version Info
          // ========================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Islamic App v1.0.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
