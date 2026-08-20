import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/hijri_service.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../prayer_times/presentation/pages/hijri_calendar_page.dart';
import '../../../prayer_times/presentation/widgets/imsakiya_table.dart';

/// Ramadan only: which day it is, how long until imsak or iftar, and a
/// tarawih check-in.
///
/// The card appears on its own when the month turns and disappears when it
/// ends — no setting to find, nothing to switch on.
class RamadanCard extends ConsumerStatefulWidget {
  const RamadanCard({super.key});

  @override
  ConsumerState<RamadanCard> createState() => _RamadanCardState();
}

class _RamadanCardState extends ConsumerState<RamadanCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _tarawihKey(DateTime date) =>
      'tarawih_${date.year}-${date.month}-${date.day}';

  bool get _tarawihDone => appPreferences.getBool(_tarawihKey(_now)) ?? false;

  Future<void> _toggleTarawih() async {
    await appPreferences.setBool(_tarawihKey(_now), !_tarawihDone);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final hijri = HijriService.fromGregorian(
      _now,
      offsetDays: settings.hijriOffsetDays,
    );

    if (!HijriService.isRamadan(hijri.hMonth)) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final location = ref.watch(currentLocationCoordinatesProvider);
    final method = ref.watch(prayerMethodProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isLastTen = HijriService.isLastTenOfRamadan(hijri.hMonth, hijri.hDay);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLastTen ? colorScheme.secondary : colorScheme.outlineVariant,
          width: isLastTen ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.translate(
                    languageCode,
                    'ramadan_day',
                    replacements: {'day': hijri.hDay.toString()},
                  ),
                  style: AppTextStyles.display(context, fontSize: 18),
                ),
              ),
              if (isLastTen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr('event_last_ten'),
                    style: AppTextStyles.caption(
                      context,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          location.when(
            loading:
                () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
            error: (_, _) => const SizedBox.shrink(),
            data: (coordinates) {
              final day = PrayerCalculationService.computeDay(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                method: method,
                date: _now,
                settings: settings,
              );
              final fajr = day.timeOf(PrayerIds.fajr)!;
              final maghrib = day.timeOf(PrayerIds.maghrib)!;

              final beforeFajr = _now.isBefore(fajr);
              final fasting = !beforeFajr && _now.isBefore(maghrib);

              final target =
                  fasting
                      ? maghrib
                      : beforeFajr
                      ? fajr.subtract(
                        const Duration(
                          minutes: ImsakiyaTable.imsakOffsetMinutes,
                        ),
                      )
                      : fajr
                          .add(const Duration(days: 1))
                          .subtract(
                            const Duration(
                              minutes: ImsakiyaTable.imsakOffsetMinutes,
                            ),
                          );

              final remaining = target.difference(_now);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fasting
                        ? context.tr('ramadan_until_iftar')
                        : context.tr('ramadan_until_imsak'),
                    style: AppTextStyles.caption(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRemaining(remaining, languageCode),
                    style: AppTextStyles.display(context, fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _timeChip(
                        context,
                        label: context.tr('imsak'),
                        value: NotificationPlanner.formatClock(
                          fajr.subtract(
                            const Duration(
                              minutes: ImsakiyaTable.imsakOffsetMinutes,
                            ),
                          ),
                          languageCode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _timeChip(
                        context,
                        label: context.tr('iftar'),
                        value: NotificationPlanner.formatClock(
                          maghrib,
                          languageCode,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('tarawih_tonight'),
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
              ),
              FilterChip(
                selected: _tarawihDone,
                onSelected: (_) => _toggleTarawih(),
                avatar: Icon(
                  _tarawihDone ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                ),
                label: Text(
                  _tarawihDone
                      ? context.tr('tarawih_done')
                      : context.tr('tarawih_mark'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HijriCalendarPage(),
                    ),
                  ),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(context.tr('imsakiya')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.caption(context)),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTextStyles.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration remaining, String languageCode) {
    if (remaining.isNegative) {
      return '00:00';
    }
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    return languageCode == 'ar'
        ? '$hours:$minutes'.split('').map(_arabicDigit).join()
        : '$hours:$minutes';
  }

  static String _arabicDigit(String char) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final value = int.tryParse(char);
    return value == null ? char : digits[value];
  }
}
