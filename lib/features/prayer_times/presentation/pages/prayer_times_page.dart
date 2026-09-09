import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/duration_words.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/arc_gauge.dart';
import '../../../../core/widgets/shortcut_grid.dart';
import 'hijri_calendar_page.dart';
import 'monthly_timetable_page.dart';
import 'nearby_mosques_page.dart';
import 'prayer_settings_page.dart';
import 'qibla_page.dart';
import 'travel_mode_page.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/entities/prayer_times_entity.dart';
import '../providers/prayer_times_providers.dart';
import '../widgets/city_change_banner.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/prayer_log_card.dart';

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
    if (lower.contains('fajr') || lower.contains('sunrise')) {
      return Icons.wb_twilight_rounded;
    }
    if (lower.contains('maghrib')) return Icons.nights_stay_outlined;
    if (lower.contains('isha')) return Icons.bedtime_rounded;
    if (lower.contains('asr')) return Icons.wb_cloudy_outlined;
    return Icons.light_mode_rounded;
  }

  /// What is left before the next prayer, in words.
  String _remainingLabel(BuildContext context, Duration duration) {
    final words = remainingInWords(context, duration);
    return words.isEmpty ? context.tr('prayer_time_now') : words;
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
                            : _remainingLabel(
                              context,
                              nextSlot.time.difference(_currentTime),
                            ),
                    headlineParts:
                        nextSlot == null
                            ? const []
                            : remainingParts(
                              context,
                              nextSlot.time.difference(_currentTime),
                            ),
                    caption:
                        nextSlot == null
                            ? null
                            : '${context.tr('until_word')} '
                                '${_getPrayerDisplayName(context, nextSlot.prayer.name)}'
                                ' · ${_formatTime12H(context, nextSlot.time)}',
                    footnote: locationText,
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
                            ? Icons.wb_twilight_rounded
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
                            ? Icons.bedtime_rounded
                            : _getIconForPrayer(nextSlot.prayer.name),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // The five times, written out, before anything else asks for
                // attention. This tab is opened to read a time, and until now
                // it opened on a picture of one: the arc, the location card
                // and the log card all came first, so a reader had to scroll
                // before a single number appeared in words.
                SectionHeader(title: context.tr('prayer_times_today')),
                ...slots.map((slot) {
                  return _buildPrayerTimeTile(
                    context: context,
                    name: _getPrayerDisplayName(context, slot.prayer.name),
                    time: _formatTime12H(context, slot.time),
                    icon: _getIconForPrayer(slot.prayer.name),
                    isCurrent: currentSlot?.id == slot.id,
                  );
                }),

                const SizedBox(height: AppSpacing.lg),

                // The six tools, straight after the times rather than at the
                // foot of the page. They were about seventeen hundred pixels
                // down — two full screens — and two of them, the mosques
                // nearby and the travel mode, are wanted precisely when the
                // reader is somewhere unfamiliar and in a hurry.
                SectionHeader(title: context.tr('prayer_tools')),
                ShortcutGrid(
                  items: [
                    ShortcutItem(
                      icon: Icons.explore_outlined,
                      label: context.tr('qibla_direction'),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const QiblaPage(),
                            ),
                          ),
                    ),
                    ShortcutItem(
                      icon: Icons.calendar_month_outlined,
                      label: context.tr('hijri_calendar'),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HijriCalendarPage(),
                            ),
                          ),
                    ),
                    ShortcutItem(
                      icon: Icons.tune,
                      label: context.tr('prayer_settings'),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrayerSettingsPage(),
                            ),
                          ),
                    ),
                    ShortcutItem(
                      icon: Icons.calendar_view_month_outlined,
                      label: context.tr('monthly_timetable'),
                      onTap: () => MonthlyTimetablePage.open(context),
                    ),
                    ShortcutItem(
                      icon: Icons.mosque_outlined,
                      label: context.tr('nearby_mosques'),
                      onTap: () => NearbyMosquesPage.open(context),
                    ),
                    ShortcutItem(
                      icon: Icons.flight_takeoff_outlined,
                      label: context.tr('travel_mode'),
                      onTap: () => TravelModePage.open(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                const CityChangeBanner(),

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

                const PrayerLogCard(),
                const SizedBox(height: AppSpacing.lg),
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
  }) {
    final tokens = context.tokens;

    return AppListRow(
      dense: true,
      selected: isCurrent,
      // The shared tile, not a hand-rolled circle. This one was 38px on a
      // gold-at-0.18 or a groundAlt fill depending on state — two different
      // background families for one control — while the row beneath it in the
      // same list used another set again.
      leading: AppIconTile(
        icon,
        role: AppIconRole.row,
        tone: isCurrent ? AppIconTone.accent : AppIconTone.neutral,
        selected: isCurrent,
      ),
      title: name,
      meta: isCurrent ? context.tr('current_prayer') : null,
      // The time alone. There used to be a tick beside every row as well, and
      // it asked the same question the card above already asks in more
      // detail — that card records whether a prayer was in the mosque, in
      // congregation, alone or made up, and this one could only say "done".
      // Two answers to one question, and the coarser one on top.
      trailing: Text(
        time,
        style: AppTextStyles.display(
          context,
          fontSize: 15,
          color: isCurrent ? tokens.ink : tokens.inkMuted,
        ),
      ),
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
          const AppIconTile(Icons.place_outlined, role: AppIconRole.row),
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
