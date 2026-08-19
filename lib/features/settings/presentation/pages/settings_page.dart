import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  final VoidCallback? onBackHome;

  const SettingsPage({super.key, this.onBackHome});

  void _handleBack(BuildContext context) {
    if (onBackHome != null) {
      onBackHome!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isNotificationsEnabled = ref.watch(notificationsEnabledProvider);
    final prayerMethod = ref.watch(prayerMethodProvider);

    final isDark = themeMode == ThemeMode.dark;

    // Colors
    final bgColor = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF9F9F9);
    final textColor = isDark ? Theme.of(context).textTheme.bodyLarge!.color! : const Color(0xFF1A1C1C);
    final subtitleColor =
        isDark ? Theme.of(context).colorScheme.onSurfaceVariant : const Color(0xFF707974);
    final cardColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final primaryColor =
        isDark ? Theme.of(context).colorScheme.primary : const Color(0xFF003527);
    final accentColor = isDark ? Theme.of(context).colorScheme.secondary : const Color(0xFF735C00);

    return Directionality(
      textDirection: context.appTextDirection,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            return;
          }
          _handleBack(context);
        },
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor, size: 28),
              onPressed: () {
                _handleBack(context);
              },
            ),
            title: Text(
              context.tr('settings'),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
          ),
          body: ListView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              // Profile Area
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFF1A1C1C),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white24,
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      right: -8,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  context.tr('user_name'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Center(
                child: Text(
                  context.tr('user_location'),
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
              ),
              const SizedBox(height: 32),

              // Adhan Notifications
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: accentColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('adhan_notifications'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: isNotificationsEnabled,
                          onChanged: (value) {
                            ref
                                .read(notificationsEnabledProvider.notifier)
                                .setEnabled(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPrayerIconTile(
                          context.tr('fajr'),
                          Icons.wb_twilight,
                          true,
                          primaryColor,
                          subtitleColor,
                        ),
                        _buildPrayerIconTile(
                          context.tr('dhuhr'),
                          Icons.wb_sunny,
                          true,
                          primaryColor,
                          subtitleColor,
                        ),
                        _buildPrayerIconTile(
                          context.tr('asr'),
                          Icons.wb_cloudy,
                          false,
                          primaryColor,
                          subtitleColor,
                        ),
                        _buildPrayerIconTile(
                          context.tr('maghrib'),
                          Icons.nights_stay,
                          true,
                          primaryColor,
                          subtitleColor,
                        ),
                        _buildPrayerIconTile(
                          context.tr('isha'),
                          Icons.bedtime,
                          true,
                          primaryColor,
                          subtitleColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment:
                          context.isAppRtl
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Theme.of(context).dividerColor
                                  : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.tr('customize_all'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Calculation Method
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: accentColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('calculation_method'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('calc_method_desc'),
                      style: TextStyle(color: subtitleColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    MenuAnchor(
                      builder: (context, controller, child) {
                        return FilledButton.tonalIcon(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            AppConstants.prayerCalculationMethods[prayerMethod] ??
                                context.tr('egyptian_general_authority'),
                          ),
                        );
                      },
                      menuChildren: AppConstants.prayerCalculationMethods.entries
                          .map(
                            (entry) => MenuItemButton(
                              onPressed: () {
                                ref
                                    .read(prayerMethodProvider.notifier)
                                    .setMethod(entry.key);
                              },
                              child: ListTile(
                                dense: true,
                                title: Text(entry.value),
                                trailing: prayerMethod == entry.key
                                    ? Icon(
                                        Icons.check,
                                        color: Theme.of(context).colorScheme.primary,
                                      )
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Language & Appearance
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final newLang =
                            locale.languageCode == 'ar' ? 'en' : 'ar';
                        ref.read(localeProvider.notifier).setLocale(newLang);
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Theme.of(context).dividerColor
                                      : const Color(0xFFF9F9F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.language, color: textColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('language'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  locale.languageCode == 'ar'
                                      ? context.tr('language_arabic')
                                      : context.tr('language_english'),
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            context.isAppRtl
                                ? Icons.keyboard_arrow_left
                                : Icons.keyboard_arrow_right,
                            color: subtitleColor,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        color:
                            isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                        thickness: 1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Theme.of(context).dividerColor
                                      : const Color(0xFFF9F9F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('appearance'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  isDark
                                      ? context.tr('dark_mode_on')
                                      : context.tr('light_mode'),
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isDark,
                            activeThumbColor: Colors.white,
                            activeTrackColor: primaryColor,
                            onChanged: (val) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .toggleTheme();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Contact Us Custom Card
              Container(
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).scaffoldBackgroundColor]
                            : const [Color(0xFF003527), Color(0xFF001A13)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.mosque,
                        size: 120,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('contact_us'),
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('contact_us_desc'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4B86A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.send,
                                  color: Color(0xFF241A00),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  context.tr('send_message'),
                                  style: TextStyle(
                                    color: Color(0xFF241A00),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Logout Button
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('logout'),
                      style: TextStyle(
                        color: Color(0xFFBA1A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.logout, color: Color(0xFFBA1A1A)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerIconTile(
    String title,
    IconData icon,
    bool active,
    Color primaryColor,
    Color subtitleColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: active ? primaryColor : subtitleColor, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? primaryColor : subtitleColor,
          ),
        ),
      ],
    );
  }
}
