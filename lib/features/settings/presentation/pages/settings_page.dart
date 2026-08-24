import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/models/notification_preferences.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../shared/providers/app_update_provider.dart';
import '../widgets/app_update_dialog.dart';
import '../../../prayer_times/presentation/pages/hijri_calendar_page.dart';
import '../../../quran/presentation/pages/playlists_page.dart';
import 'storage_page.dart';
import 'zakat_page.dart';
import '../../../prayer_times/presentation/pages/prayer_settings_page.dart';
import 'notification_center_page.dart';
import 'design_gallery_page.dart';
import 'seasonal_preview_page.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/input_validators.dart';
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
    final profile = ref.watch(userProfileProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final seasonalIntroEnabled = ref.watch(seasonalIntroEnabledProvider);
    final seasonalOverride = ref.watch(seasonalOverrideProvider);

    final isDark = themeMode == ThemeMode.dark;

    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = colorScheme.primary;
    final accentColor = colorScheme.secondary;
    final mutedFill = colorScheme.surfaceContainerHighest;

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
        child: MeshBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: context.tr('back'),
                icon: Icon(
                  context.isAppRtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  color: textColor,
                  size: 22,
                ),
                onPressed: () => _handleBack(context),
              ),
              title: Text(
                context.tr('settings'),
                style: AppTextStyles.display(context, fontSize: 18),
              ),
              centerTitle: true,
            ),
            body: ListView(
              padding: AppScaffold.scrollPadding,
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
                                  ? colorScheme.surfaceContainerHighest
                                  : context.tokens.ink,
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
                        child: Material(
                          color: accentColor,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _editProfile(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    profile.name.isEmpty
                        ? context.tr('user_name')
                        : profile.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    profile.location.isEmpty
                        ? context.tr('user_location')
                        : profile.location,
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
                              _setNotificationsEnabled(context, ref, value);
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
                            notificationPrefs.modeFor('fajr').isEnabled,
                            primaryColor,
                            subtitleColor,
                            onTap: () => _togglePrayerAlert(ref, 'fajr'),
                          ),
                          _buildPrayerIconTile(
                            context.tr('dhuhr'),
                            Icons.wb_sunny,
                            notificationPrefs.modeFor('dhuhr').isEnabled,
                            primaryColor,
                            subtitleColor,
                            onTap: () => _togglePrayerAlert(ref, 'dhuhr'),
                          ),
                          _buildPrayerIconTile(
                            context.tr('asr'),
                            Icons.wb_cloudy,
                            notificationPrefs.modeFor('asr').isEnabled,
                            primaryColor,
                            subtitleColor,
                            onTap: () => _togglePrayerAlert(ref, 'asr'),
                          ),
                          _buildPrayerIconTile(
                            context.tr('maghrib'),
                            Icons.nights_stay,
                            notificationPrefs.modeFor('maghrib').isEnabled,
                            primaryColor,
                            subtitleColor,
                            onTap: () => _togglePrayerAlert(ref, 'maghrib'),
                          ),
                          _buildPrayerIconTile(
                            context.tr('isha'),
                            Icons.bedtime,
                            notificationPrefs.modeFor('isha').isEnabled,
                            primaryColor,
                            subtitleColor,
                            onTap: () => _togglePrayerAlert(ref, 'isha'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment:
                            context.isAppRtl
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                        child: Material(
                          color: mutedFill,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openCustomizeSheet(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
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
                              AppConstants
                                      .prayerCalculationMethods[prayerMethod] ??
                                  context.tr('egyptian_general_authority'),
                            ),
                          );
                        },
                        menuChildren:
                            AppConstants.prayerCalculationMethods.entries
                                .map(
                                  (entry) => MenuItemButton(
                                    onPressed: () {
                                      ref
                                          .read(prayerMethodProvider.notifier)
                                          .setMethod(entry.key);
                                    },
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tools: everything with its own screen.
                Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildToolTile(
                          context,
                          icon: Icons.notifications_active,
                          color: accentColor,
                          title: context.tr('notification_center'),
                          subtitle: context.tr('notification_center_desc'),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => const NotificationCenterPage(),
                                ),
                              ),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.tune,
                          color: accentColor,
                          title: context.tr('prayer_calculation_settings'),
                          subtitle: context.tr('manual_offsets_desc'),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PrayerSettingsPage(),
                                ),
                              ),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.calendar_month,
                          color: accentColor,
                          title: context.tr('hijri_calendar'),
                          subtitle: context.tr('hijri_calendar_desc'),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const HijriCalendarPage(),
                                ),
                              ),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.balance,
                          color: accentColor,
                          title: context.tr('zakat'),
                          subtitle: context.tr('zakat_tool_desc'),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ZakatPage(),
                                ),
                              ),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.playlist_play_rounded,
                          color: accentColor,
                          title: context.tr('playlists'),
                          subtitle: context.tr('playlists_desc'),
                          onTap: () => PlaylistsPage.open(context),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.storage_outlined,
                          color: accentColor,
                          title: context.tr('storage'),
                          subtitle: context.tr('storage_desc'),
                          onTap: () => StoragePage.open(context),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.backup_outlined,
                          color: accentColor,
                          title: context.tr('backup'),
                          subtitle: context.tr('backup_desc'),
                          onTap: () => _openBackupSheet(context),
                        ),
                        _buildToolTile(
                          context,
                          icon: Icons.system_update_alt_outlined,
                          color: accentColor,
                          title: context.tr('app_update'),
                          subtitle: _updateSubtitle(context, ref),
                          onTap:
                              () => AppUpdateDialog.present(
                                context,
                                ref,
                                forceCheck: true,
                              ),
                        ),
                      ],
                    ),
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
                                color: mutedFill,
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
                          color: colorScheme.outlineVariant,
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
                                color: mutedFill,
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
                            Switch.adaptive(
                              value: isDark,
                              onChanged: (val) {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .toggleTheme();
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          color: colorScheme.outlineVariant,
                          thickness: 1,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: mutedFill,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.movie_filter_outlined,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('seasonal_intro'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  context.tr('seasonal_intro_desc'),
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: seasonalIntroEnabled,
                            onChanged:
                                (value) => ref
                                    .read(seasonalIntroEnabledProvider.notifier)
                                    .setEnabled(value),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          color: colorScheme.outlineVariant,
                          thickness: 1,
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const DesignGalleryPage(),
                              ),
                            ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mutedFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.widgets_outlined,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('design_gallery'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    context.tr('design_gallery_desc'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                          color: colorScheme.outlineVariant,
                          thickness: 1,
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SeasonalPreviewPage(),
                              ),
                            ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mutedFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.palette_outlined,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('seasonal_preview'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    seasonalOverride == null
                                        ? context.tr('seasonal_preview_auto')
                                        : context.tr('seasonal_preview_active'),
                                    style: TextStyle(
                                      color:
                                          seasonalOverride == null
                                              ? subtitleColor
                                              : accentColor,
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
                              ? [colorScheme.primaryContainer, bgColor]
                              : [context.tokens.brandDeep, context.tokens.ink],
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
                                color:
                                    isDark
                                        ? colorScheme.onPrimaryContainer
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('contact_us_desc'),
                              style: TextStyle(
                                color: (isDark
                                        ? colorScheme.onPrimaryContainer
                                        : Colors.white)
                                    .withValues(alpha: 0.8),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => _sendMessage(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.send, size: 20),
                              label: Text(
                                context.tr('send_message'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                  child: TextButton.icon(
                    onPressed: () => _logout(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      context.tr('logout'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider);
    final nameController = TextEditingController(
      text: profile.name.isEmpty ? '' : profile.name,
    );
    final locationController = TextEditingController(
      text: profile.location.isEmpty ? '' : profile.location,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('edit_profile')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('profile_name_label'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('profile_location_label'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('save')),
            ),
          ],
        );
      },
    );

    final name = nameController.text;
    final location = locationController.text;
    nameController.dispose();
    locationController.dispose();

    if (saved != true) {
      return;
    }
    if (!InputValidators.isDisplayName(name) ||
        !InputValidators.isLocationLabel(location)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('profile_invalid'))));
      }
      return;
    }

    await ref
        .read(userProfileProvider.notifier)
        .update(name: name, location: location);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('profile_saved'))));
    }
  }

  String _updateSubtitle(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final language = Localizations.localeOf(context).languageCode;
    switch (state.status) {
      case AppUpdateStatus.checking:
        return context.tr('app_update_checking');
      case AppUpdateStatus.available:
        return AppLocalizations.translate(
          language,
          'app_update_available',
          replacements: {
            'version': state.release?.label ?? '',
            'size': UpdateService.formatBytes(state.release?.apkBytes ?? 0),
          },
        );
      case AppUpdateStatus.downloading:
        return AppLocalizations.translate(
          language,
          'app_update_downloading',
          replacements: {'percent': '${state.progress?.percent ?? 0}'},
        );
      case AppUpdateStatus.installing:
        return context.tr('app_update_installing');
      case AppUpdateStatus.failed:
        return context.tr('app_update_failed');
      case AppUpdateStatus.current:
        return context.tr('app_update_current');
      case AppUpdateStatus.idle:
        return context.tr('app_update_desc');
    }
  }

  Widget _buildToolTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        context.isAppRtl
            ? Icons.keyboard_arrow_left
            : Icons.keyboard_arrow_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  /// Export everything to a file, or restore from one.
  Future<void> _openBackupSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetContext.tr('backup'),
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  sheetContext.tr('backup_explain'),
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share),
                  title: Text(sheetContext.tr('backup_export')),
                  subtitle: Text(sheetContext.tr('backup_export_desc')),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await BackupService.exportBackup();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore),
                  title: Text(sheetContext.tr('backup_import')),
                  subtitle: Text(sheetContext.tr('backup_import_desc')),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _restoreBackup(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final restoredMessage = context.tr('backup_restored');
    final invalidMessage = context.tr('backup_invalid');
    final versionMessage = context.tr('backup_newer_version');

    try {
      final summary = await BackupService.importBackup();
      if (summary == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          // The tasbeeh total is named because it is the number people are
          // most afraid of losing, and seeing it come back is the proof.
          content: Text(
            '$restoredMessage — '
            '${summary.bookmarks} · ${summary.readingDays} · '
            '${summary.hifzItems}'
            '${summary.tasbeehTotal > 0 ? ' · ${summary.tasbeehTotal}' : ''}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } on BackupException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.isWrongVersion ? versionMessage : invalidMessage),
        ),
      );
    }
  }

  Future<void> _setNotificationsEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final title = context.tr('adhan_notifications');
      final body = context.tr('notifications_enabled_body');
      final deniedMessage = context.tr('notifications_permission_denied');
      final granted = await NotificationService.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(deniedMessage)));
        }
        return;
      }
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setMasterEnabled(true);
      await NotificationService.showNow(title: title, body: body);
    } else {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .setMasterEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('notifications_disabled'))),
        );
      }
    }
  }

  Future<void> _togglePrayerAlert(WidgetRef ref, String prayerId) async {
    await ref
        .read(notificationPreferencesProvider.notifier)
        .togglePrayer(prayerId);
  }

  /// The compact card only toggles prayers on and off; every other reminder
  /// (modes, pre-adhan, iqama, azkar, quiet hours) lives in the notification
  /// centre.
  Future<void> _openCustomizeSheet(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterPage()),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final subject = context.tr('contact_email_subject');
    final invalidMessage = context.tr('contact_message_invalid');
    final launchFailed = context.tr('contact_launch_failed');
    final messageController = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('send_message')),
          content: TextField(
            controller: messageController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: dialogContext.tr('contact_message_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('send_message')),
            ),
          ],
        );
      },
    );

    final message = messageController.text;
    messageController.dispose();
    if (sent != true) {
      return;
    }
    if (!InputValidators.isFeedbackMessage(message)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(invalidMessage)));
      }
      return;
    }

    final uri = Uri.parse(
      'mailto:${AppConstants.supportEmail}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(InputValidators.sanitizeMessage(message))}',
    );

    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(launchFailed)));
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to open mail app', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(launchFailed)));
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('logout')),
          content: Text(dialogContext.tr('logout_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(dialogContext.tr('logout')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(userProfileProvider.notifier).clear();
    await ref
        .read(notificationPreferencesProvider.notifier)
        .setMasterEnabled(false);
    ref.read(mainTabIndexProvider.notifier).openHome();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('logged_out'))));
  }

  Widget _buildPrayerIconTile(
    String title,
    IconData icon,
    bool active,
    Color primaryColor,
    Color subtitleColor, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
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
        ),
      ),
    );
  }
}
