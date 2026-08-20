import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../shared/providers/app_providers.dart';

/// Fine-tuning for the prayer timetable: method, madhab, high-latitude rule,
/// per-prayer minute offsets, and the Hijri correction.
///
/// Every control previews against today's calculated times, so the user can
/// match the timetable to their own mosque and see the result immediately.
class PrayerSettingsPage extends ConsumerWidget {
  const PrayerSettingsPage({super.key});

  static const List<int> _offsetChoices = [-5, -3, -2, -1, 0, 1, 2, 3, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final notifier = ref.read(prayerCalculationSettingsProvider.notifier);
    final method = ref.watch(prayerMethodProvider);
    final location = ref.watch(currentLocationCoordinatesProvider);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(context.tr('prayer_calculation_settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          location.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
            error: (_, _) => const SizedBox.shrink(),
            data:
                (coordinates) =>
                    _preview(context, coordinates, method, settings),
          ),
          const SizedBox(height: 16),
          _card(
            context,
            title: context.tr('calculation_method'),
            icon: Icons.calculate,
            subtitle: context.tr('calc_method_desc'),
            children: [
              RadioGroup<int>(
                groupValue: method,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(prayerMethodProvider.notifier).setMethod(value);
                  }
                },
                child: Column(
                  children: [
                    for (final entry
                        in AppConstants.prayerCalculationMethods.entries)
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        value: entry.key,
                        title: Text(entry.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            context,
            title: context.tr('asr_madhab'),
            icon: Icons.wb_cloudy,
            subtitle: context.tr('asr_madhab_desc'),
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(context.tr('madhab_shafi')),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(context.tr('madhab_hanafi')),
                  ),
                ],
                selected: {settings.hanafiAsr},
                onSelectionChanged:
                    (value) => notifier.setHanafiAsr(value.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            context,
            title: context.tr('high_latitude_rule'),
            icon: Icons.public,
            subtitle: context.tr('high_latitude_desc'),
            children: [
              DropdownButtonFormField<HighLatitudeRule>(
                initialValue: settings.highLatitudeRule,
                isExpanded: true,
                items: [
                  for (final rule in HighLatitudeRule.values)
                    DropdownMenuItem(
                      value: rule,
                      child: Text(context.tr('high_lat_${rule.name}')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    notifier.setHighLatitudeRule(value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            context,
            title: context.tr('manual_offsets'),
            icon: Icons.tune,
            subtitle: context.tr('manual_offsets_desc'),
            children: [
              for (final prayerId in PrayerIds.all)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 84, child: Text(context.tr(prayerId))),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final offset in _offsetChoices) ...[
                                ChoiceChip(
                                  selected:
                                      (settings.minuteAdjustments[prayerId] ??
                                          0) ==
                                      offset,
                                  onSelected:
                                      (_) =>
                                          notifier.setOffset(prayerId, offset),
                                  label: Text(
                                    offset > 0 ? '+$offset' : '$offset',
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: notifier.resetOffsets,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(context.tr('reset_offsets')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            context,
            title: context.tr('hijri_adjustment'),
            icon: Icons.calendar_month,
            subtitle: context.tr('hijri_adjustment_desc'),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final offset in [-2, -1, 0, 1, 2])
                    ChoiceChip(
                      selected: settings.hijriOffsetDays == offset,
                      onSelected: (_) => notifier.setHijriOffset(offset),
                      label: Text(offset > 0 ? '+$offset' : '$offset'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final result = await NotificationScheduler.refresh();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.translate(
                        Localizations.localeOf(context).languageCode,
                        'notif_scheduled_count',
                        replacements: {'count': result.scheduled.toString()},
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active, size: 18),
              label: Text(context.tr('notif_reschedule')),
            ),
          ),
        ],
      ),
    );
  }

  /// Today's timetable as the current settings produce it.
  Widget _preview(
    BuildContext context,
    UserCoordinates coordinates,
    int method,
    PrayerCalculationSettings settings,
  ) {
    final day = PrayerCalculationService.computeDay(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      method: method,
      settings: settings,
    );
    final languageCode = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('today_preview'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${day.hijri.day} ${day.hijri.monthNameAr} ${day.hijri.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final prayer in day.prayers)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.tr(prayer.id),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        NotificationPlanner.formatClock(
                          prayer.time,
                          languageCode,
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.secondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
