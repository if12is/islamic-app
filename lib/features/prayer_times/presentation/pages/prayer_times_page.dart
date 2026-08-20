import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/arc_gauge.dart';
import 'hijri_calendar_page.dart';
import 'prayer_settings_page.dart';
import 'qibla_page.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../providers/prayer_times_providers.dart';
import '../widgets/location_picker_sheet.dart';

class _PrayerSlot {
  final String id;
  final PrayerEntity prayer;
  final DateTime time;

  const _PrayerSlot({
    required this.id,
    required this.prayer,
    required this.time,
  });
}

class PrayerTimesPage extends ConsumerStatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  ConsumerState<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends ConsumerState<PrayerTimesPage> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], arabic[i]);
    }
    return output;
  }

  String _localizeDigits(BuildContext context, String input) {
    return context.isAppRtl ? _toArabicDigits(input) : input;
  }

  String _normalizeToWesternDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < arabic.length; i++) {
      output = output.replaceAll(arabic[i], '$i');
    }
    return output;
  }

  DateTime _parseTime(String timeStr) {
    try {
      final clean = _normalizeToWesternDigits(timeStr.split(' ').first);
      final parts = clean.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _canonicalPrayerId(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return 'fajr';
    if (lower.contains('dhuhr')) return 'dhuhr';
    if (lower.contains('asr')) return 'asr';
    if (lower.contains('maghrib')) return 'maghrib';
    if (lower.contains('isha')) return 'isha';
    return '';
  }

  String _getPrayerDisplayName(BuildContext context, String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return context.tr('fajr');
    if (lower.contains('dhuhr')) return context.tr('dhuhr');
    if (lower.contains('asr')) return context.tr('asr');
    if (lower.contains('maghrib')) return context.tr('maghrib');
    if (lower.contains('isha')) return context.tr('isha');
    return name;
  }

  IconData _getIconForPrayer(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return Icons.wb_twilight;
    if (lower.contains('dhuhr')) return Icons.wb_sunny_outlined;
    if (lower.contains('asr')) return Icons.light_mode_outlined;
    if (lower.contains('maghrib')) return Icons.nightlight_round;
    if (lower.contains('isha')) return Icons.nightlight_outlined;
    return Icons.access_time;
  }

  /// "٤٢ د" or "٢:١٥" — what is left before the next prayer.
  String _remainingLabel(BuildContext context, Duration duration) {
    if (duration.isNegative) {
      return '';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final text = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}'
        : '$minutes ${context.tr('minute_short')}';
    return _localizeDigits(context, text);
  }

  /// The clock split from its marker, for the arc's centre.
  (String, String) _clockParts(BuildContext context, DateTime time) {
    final suffix =
        time.hour >= 12 ? context.tr('pm_short') : context.tr('am_short');
    var hour = time.hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final minutes = time.minute.toString().padLeft(2, '0');
    return (_localizeDigits(context, '$hour:$minutes'), suffix);
  }

  String _formatTime12H(BuildContext context, DateTime time) {
    var hour = time.hour;
    final minute = time.minute;
    final ampm = hour >= 12 ? context.tr('pm_short') : context.tr('am_short');
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final formatted =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
    return _localizeDigits(context, formatted);
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationCoordinatesProvider);
    final selectedMethod = ref.watch(prayerMethodProvider);
    final completedPrayers = ref.watch(dailyPrayerCompletionProvider);

    const fallbackCoordinates = UserCoordinates(
      latitude: 31.0345728,
      longitude: 30.4676864,
    );

    final coordinates = locationAsync.maybeWhen(
      data: (value) => value,
      orElse: () => fallbackCoordinates,
    );

    final method = ref
        .watch(sharedPreferencesProvider)
        .maybeWhen(
          data:
              (prefs) =>
                  prefs.getInt(AppConstants.prayerMethodKey) ?? selectedMethod,
          orElse: () => selectedMethod,
        );

    final params = PrayerTimesParams(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      method: method,
    );

    final prayerTimesAsync = ref.watch(prayerTimesProvider(params));

    Future<void> refreshAll() async {
      ref.invalidate(currentLocationCoordinatesProvider);
      ref.invalidate(prayerTimesProvider(params));
      await ref.read(dailyPrayerCompletionProvider.notifier).reloadToday();
    }

    return AppScaffold(
      title: 'prayer_times',
      showBack: Navigator.of(context).canPop(),
      body: prayerTimesAsync.when(
        loading: () => const Center(child: CustomLoader()),
        error:
            (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: context.tokens.inkFaint,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.tr('unable_load_prayer_times_connection'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(context, fontSize: 15),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentLocationCoordinatesProvider);
                        ref.invalidate(prayerTimesProvider(params));
                      },
                      child: Text(context.tr('retry')),
                    ),
                  ],
                ),
              ),
            ),
        data: (entity) {
          final tokens = context.tokens;
          final order = {
            'fajr': 0,
            'dhuhr': 1,
            'asr': 2,
            'maghrib': 3,
            'isha': 4,
          };

          final slots =
              entity.prayers
                  .map((prayer) {
                    final id = _canonicalPrayerId(prayer.name);
                    if (id.isEmpty) {
                      return null;
                    }
                    return _PrayerSlot(
                      id: id,
                      prayer: prayer,
                      time: _parseTime(prayer.time),
                    );
                  })
                  .whereType<_PrayerSlot>()
                  .toList()
                ..sort(
                  (a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99),
                );

          _PrayerSlot? currentSlot;
          _PrayerSlot? nextSlot;
          for (final slot in slots) {
            if (!_currentTime.isBefore(slot.time)) {
              currentSlot = slot;
            } else {
              nextSlot ??= slot;
            }
          }
          currentSlot ??= slots.isEmpty ? null : slots.last;
          nextSlot ??= slots.isEmpty ? null : slots.first;

          var progress = 0.0;
          if (currentSlot != null && nextSlot != null) {
            final start =
                currentSlot.time.isAfter(_currentTime)
                    ? currentSlot.time.subtract(const Duration(days: 1))
                    : currentSlot.time;
            final finish =
                nextSlot.time.isBefore(start)
                    ? nextSlot.time.add(const Duration(days: 1))
                    : nextSlot.time;
            final span = finish.difference(start).inSeconds;
            if (span > 0) {
              progress = _currentTime.difference(start).inSeconds / span;
            }
          }

          // The place name, not two numbers nobody can read.
          final locationLabel = ref.watch(locationLabelProvider);
          final isManualLocation = ref.watch(locationIsManualProvider);
          final locationText = locationLabel.maybeWhen(
            data:
                (label) =>
                    label.isEmpty ? context.tr('location_unknown') : label,
            orElse: () => context.tr('location_resolving'),
          );

          return RefreshIndicator(
            color: tokens.brand,
            onRefresh: refreshAll,
            child: ListView(
              padding: AppScaffold.scrollPadding,
              children: [
                Center(
                  child: ArcGauge(
                    progress: progress,
                    headline:
                        nextSlot == null
                            ? '—'
                            : _clockParts(context, nextSlot.time).$1,
                    headlineSuffix:
                        nextSlot == null
                            ? null
                            : _clockParts(context, nextSlot.time).$2,
                    caption:
                        nextSlot == null
                            ? null
                            : _getPrayerDisplayName(
                              context,
                              nextSlot.prayer.name,
                            ),
                    footnote: locationText,
                    remaining: nextSlot == null
                        ? null
                        : _remainingLabel(
                            context,
                            nextSlot.time.difference(_currentTime),
                          ),
                    startLabel:
                        currentSlot == null
                            ? null
                            : _getPrayerDisplayName(
                              context,
                              currentSlot.prayer.name,
                            ),
                    startTime:
                        currentSlot == null
                            ? null
                            : _formatTime12H(context, currentSlot.time),
                    startIcon:
                        currentSlot == null
                            ? Icons.wb_twilight
                            : _getIconForPrayer(currentSlot.prayer.name),
                    endLabel:
                        nextSlot == null
                            ? null
                            : _getPrayerDisplayName(
                              context,
                              nextSlot.prayer.name,
                            ),
                    endTime:
                        nextSlot == null
                            ? null
                            : _formatTime12H(context, nextSlot.time),
                    endIcon:
                        nextSlot == null
                            ? Icons.nights_stay_outlined
                            : _getIconForPrayer(nextSlot.prayer.name),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                _LocationCard(
                  label: locationText,
                  detail:
                      isManualLocation
                          ? context.tr('location_pinned')
                          : context.tr('prayer_times_auto_update'),
                  onChange: () async {
                    await LocationPickerSheet.show(context);
                    ref.invalidate(prayerTimesProvider(params));
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                SectionHeader(title: context.tr('prayer_times_today')),
                ...slots.map((slot) {
                  return _buildPrayerTimeTile(
                    context: context,
                    name: _getPrayerDisplayName(context, slot.prayer.name),
                    time: _formatTime12H(context, slot.time),
                    icon: _getIconForPrayer(slot.prayer.name),
                    isCurrent: currentSlot?.id == slot.id,
                    isDone: completedPrayers.contains(slot.id),
                    onToggleDone:
                        () => ref
                            .read(dailyPrayerCompletionProvider.notifier)
                            .togglePrayer(slot.id),
                  );
                }),

                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.explore_outlined,
                        label: context.tr('qibla_direction'),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const QiblaPage(),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.calendar_month_outlined,
                        label: context.tr('hijri_calendar'),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const HijriCalendarPage(),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.tune,
                        label: context.tr('prayer_settings'),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrayerSettingsPage(),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrayerTimeTile({
    required BuildContext context,
    required String name,
    required String time,
    required IconData icon,
    required bool isCurrent,
    required bool isDone,
    required VoidCallback onToggleDone,
  }) {
    final tokens = context.tokens;

    return AppListRow(
      dense: true,
      selected: isCurrent,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color:
              isCurrent
                  ? tokens.gold.withValues(alpha: 0.18)
                  : tokens.groundAlt,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 19,
          color: isCurrent ? tokens.gold : tokens.inkFaint,
        ),
      ),
      title: name,
      meta: isCurrent ? context.tr('current_prayer') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: AppTextStyles.display(
              context,
              fontSize: 15,
              color: isCurrent ? tokens.ink : tokens.inkMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GhostIconButton(
            icon: isDone ? Icons.check_circle : Icons.circle_outlined,
            active: isDone,
            onTap: onToggleDone,
            tooltip: context.tr('mark_prayed'),
          ),
        ],
      ),
      onTap: onToggleDone,
    );
  }
}

/// Where the times are being calculated for, and how to change it.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.label,
    required this.detail,
    required this.onChange,
  });

  final String label;
  final String detail;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      onTap: onChange,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.brand.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.place_outlined, size: 19, color: tokens.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(context, fontSize: 15),
                ),
                Text(
                  detail,
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
              ],
            ),
          ),
          Text(
            context.tr('change'),
            style: AppTextStyles.caption(context, color: tokens.brand),
          ),
        ],
      ),
    );
  }
}

/// A square shortcut under the day's list.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 22, color: tokens.brand),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
