import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/hijri_service.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../shared/providers/app_providers.dart';
import 'prayer_settings_page.dart';

/// A Hijri month at a glance, with the Gregorian date under every day.
///
/// Tapping a day shows what it is (a fast day, an eid, a white day) and the
/// prayer times calculated for it — the calendar and the timetable come from
/// the same on-device source.
class HijriCalendarPage extends ConsumerStatefulWidget {
  const HijriCalendarPage({super.key});

  @override
  ConsumerState<HijriCalendarPage> createState() => _HijriCalendarPageState();
}

class _HijriCalendarPageState extends ConsumerState<HijriCalendarPage> {
  late int _year;
  late int _month;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = HijriService.fromGregorian(DateTime.now());
    _year = today.hYear;
    _month = today.hMonth;
    _selectedDay = today.hDay;
  }

  void _shiftMonth(int delta) {
    setState(() {
      var month = _month + delta;
      var year = _year;
      if (month > 12) {
        month = 1;
        year++;
      } else if (month < 1) {
        month = 12;
        year--;
      }
      _month = month;
      _year = year;
      _selectedDay = null;
    });
  }

  void _goToToday() {
    final today = HijriService.fromGregorian(
      DateTime.now(),
      offsetDays: ref.read(prayerCalculationSettingsProvider).hijriOffsetDays,
    );
    setState(() {
      _year = today.hYear;
      _month = today.hMonth;
      _selectedDay = today.hDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final offset = settings.hijriOffsetDays;
    final colorScheme = Theme.of(context).colorScheme;

    final daysInMonth = HijriService.daysInMonth(_year, _month);
    final today = HijriService.fromGregorian(DateTime.now(), offsetDays: offset);
    final isCurrentMonth = today.hYear == _year && today.hMonth == _month;

    final firstGregorian = HijriService.toGregorian(
      _year,
      _month,
      1,
      offsetDays: offset,
    );
    // Grid starts on Sunday, matching how Hijri calendars are printed.
    final leadingBlanks = firstGregorian.weekday % 7;

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('hijri_calendar')),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: context.tr('today'),
              icon: const Icon(Icons.today),
              onPressed: _goToToday,
            ),
            IconButton(
              tooltip: context.tr('hijri_adjustment'),
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrayerSettingsPage(),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _monthHeader(firstGregorian),
            const SizedBox(height: 12),
            _weekdayRow(),
            const SizedBox(height: 8),
            _grid(daysInMonth, leadingBlanks, offset, today, isCurrentMonth),
            const SizedBox(height: 20),
            if (_selectedDay != null) _dayDetails(_selectedDay!, offset),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(DateTime firstGregorian) {
    final lastGregorian = HijriService.toGregorian(
      _year,
      _month,
      HijriService.daysInMonth(_year, _month),
    );

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${HijriService.monthName(_month)} $_year هـ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${firstGregorian.month}/${firstGregorian.year}'
                ' — ${lastGregorian.month}/${lastGregorian.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _weekdayRow() {
    final labels = [
      context.tr('day_sun'),
      context.tr('day_mon'),
      context.tr('day_tue'),
      context.tr('day_wed'),
      context.tr('day_thu'),
      context.tr('day_fri'),
      context.tr('day_sat'),
    ];

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(
    int daysInMonth,
    int leadingBlanks,
    int offset,
    dynamic today,
    bool isCurrentMonth,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final cells = <Widget>[];

    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final gregorian = HijriService.toGregorian(
        _year,
        _month,
        day,
        offsetDays: offset,
      );
      final events = HijriService.eventsOn(_month, day);
      final isToday = isCurrentMonth && today.hDay == day;
      final isSelected = _selectedDay == day;
      final isFasting =
          events.any((event) => event.isFasting) ||
          HijriService.isRecommendedFastingWeekday(gregorian);

      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedDay = day),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primary
                  : isSelected
                  ? colorScheme.primaryContainer
                  : events.isNotEmpty
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: gregorian.weekday == DateTime.friday
                    ? colorScheme.secondary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${gregorian.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isFasting)
                  Icon(
                    Icons.circle,
                    size: 5,
                    color: isToday
                        ? colorScheme.onPrimary
                        : colorScheme.secondary,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: cells,
    );
  }

  Widget _dayDetails(int day, int offset) {
    final colorScheme = Theme.of(context).colorScheme;
    final gregorian = HijriService.toGregorian(
      _year,
      _month,
      day,
      offsetDays: offset,
    );
    final events = HijriService.eventsOn(_month, day);
    final languageCode = Localizations.localeOf(context).languageCode;
    final method = ref.watch(prayerMethodProvider);
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final location = ref.watch(currentLocationCoordinatesProvider);

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
          Text(
            '$day ${HijriService.monthName(_month)} $_year هـ',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${gregorian.day}/${gregorian.month}/${gregorian.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final event in events)
                  Chip(
                    avatar: Icon(
                      event.isFasting ? Icons.nightlight : Icons.star,
                      size: 16,
                    ),
                    label: Text(context.tr(event.key)),
                  ),
              ],
            ),
          ],
          if (HijriService.isRecommendedFastingWeekday(gregorian))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('event_monday_thursday'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Divider(height: 28),
          location.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (coordinates) {
              final computed = PrayerCalculationService.computeDay(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                method: method,
                date: gregorian,
                settings: settings,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('prayer_times'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (final prayer in computed.prayers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr(prayer.id)),
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
              );
            },
          ),
        ],
      ),
    );
  }
}
