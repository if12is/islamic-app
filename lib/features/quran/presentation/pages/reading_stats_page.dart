import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/reading_progress_store.dart';
import '../../domain/entities/khatmah_plan.dart';
import '../../domain/weekly_report.dart';
import '../providers/reading_progress_provider.dart';
import '../widgets/weekly_report_card.dart';

/// Reading habits at a glance: the streak, the year, and the totals.
class ReadingStatsPage extends ConsumerWidget {
  const ReadingStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(readingProgressProvider);
    final plan = ref.watch(khatmahPlanProvider);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(context.tr('reading_stats')),
      body: summary.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(child: Text(error.toString())),
        data:
            (data) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _weeklyReport(context, data),
                const SizedBox(height: 16),
                _streakCard(context, data),
                const SizedBox(height: 16),
                _totalsCard(context, data),
                const SizedBox(height: 16),
                _weekCard(context, data),
                const SizedBox(height: 16),
                _yearCard(context, data),
                if (plan != null) ...[
                  const SizedBox(height: 16),
                  _planCard(context, plan, data),
                ],
              ],
            ),
      ),
    );
  }

  /// This week, with last week beside it and a way to send it to someone.
  Widget _weeklyReport(BuildContext context, ReadingSummary data) {
    final report = WeeklyReport.of(data.days);
    final previous = WeeklyReport.of(data.days, weeksAgo: 1);

    return WeeklyReportCard(
      report: report,
      previous: previous,
      onShare: () async {
        final failed = context.tr('share_failed');
        final ok = await WeeklyReportSharing.share(
          context: context,
          report: report,
          previous: previous,
        );
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failed)));
        }
      },
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

  Widget _streakCard(BuildContext context, ReadingSummary data) {
    final colorScheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return _card(
      context,
      title: context.tr('reading_streak'),
      icon: Icons.local_fire_department,
      subtitle: context.tr('reading_streak_desc'),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${data.totals.currentStreak}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    context.tr('current_streak'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 48, color: colorScheme.outlineVariant),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${data.totals.longestStreak}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Text(
                    context.tr('longest_streak'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.translate(
            languageCode,
            'today_read_pages',
            replacements: {'count': data.today.pageCount.toString()},
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _totalsCard(BuildContext context, ReadingSummary data) {
    final languageCode = Localizations.localeOf(context).languageCode;

    return _card(
      context,
      title: context.tr('reading_totals'),
      icon: Icons.stacked_bar_chart,
      children: [
        Row(
          children: [
            Expanded(
              child: _metric(
                context,
                value: data.totals.days.toString(),
                label: context.tr('days_read'),
              ),
            ),
            Expanded(
              child: _metric(
                context,
                value: data.totals.pages.toString(),
                label: context.tr('pages_read'),
              ),
            ),
            Expanded(
              child: _metric(
                context,
                value: AppLocalizations.translate(
                  languageCode,
                  'minutes_value',
                  replacements: {'minutes': data.totals.minutes.toString()},
                ),
                label: context.tr('time_read'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  /// The last seven days as bars — the shape of the current week.
  Widget _weekCard(BuildContext context, ReadingSummary data) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final byDay = {
      for (final day in data.days) ReadingProgressStore.keyFor(day.date): day,
    };

    final week = List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day - (6 - index));
      return byDay[ReadingProgressStore.keyFor(date)] ?? ReadingDay.empty(date);
    });
    final maxPages = week.fold<int>(
      1,
      (value, day) => day.pageCount > value ? day.pageCount : value,
    );

    return _card(
      context,
      title: context.tr('this_week'),
      icon: Icons.calendar_view_week,
      children: [
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in week)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${day.pageCount}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // The bar takes whatever height is left rather than a
                      // fixed 70: a hard-coded column adds up to more than the
                      // box the moment a font metric changes.
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: (day.pageCount / maxPages).clamp(
                            0.05,
                            1.0,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  day.pageCount == 0
                                      ? colorScheme.surfaceContainerHighest
                                      : colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      Text(
                        _weekdayLabel(context, day.date.weekday),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// A year of reading, one square per day.
  Widget _yearCard(BuildContext context, ReadingSummary data) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final byDay = {
      for (final day in data.days)
        ReadingProgressStore.keyFor(day.date): day.pageCount,
    };

    // 53 weeks ending this week, laid out in columns of 7 days.
    final start = DateTime(
      today.year,
      today.month,
      today.day - (52 * 7 + today.weekday % 7),
    );

    return _card(
      context,
      title: context.tr('reading_year'),
      icon: Icons.grid_on,
      subtitle: context.tr('reading_year_desc'),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 53 weeks is far wider than any phone, and the columns run oldest
          // first — so the view opened on a year of empty squares while every
          // day actually read sat off the far edge. Start at the recent end.
          reverse: true,
          child: Row(
            children: [
              for (var week = 0; week < 53; week++)
                Column(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Builder(
                        builder: (context) {
                          final date = DateTime(
                            start.year,
                            start.month,
                            start.day + week * 7 + weekday,
                          );
                          final pages =
                              byDay[ReadingProgressStore.keyFor(date)] ?? 0;
                          final isFuture = date.isAfter(today);
                          final isToday =
                              date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;

                          return Container(
                            width: 11,
                            height: 11,
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color:
                                  isFuture
                                      ? Colors.transparent
                                      : _heatColor(pages, colorScheme),
                              borderRadius: BorderRadius.circular(2),
                              // A ring on today, so the eye has somewhere to
                              // land in a field of identical squares.
                              border:
                                  isToday
                                      ? Border.all(
                                        color: colorScheme.secondary,
                                        width: 1.4,
                                      )
                                      : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _heatColor(int pages, ColorScheme scheme) {
    if (pages <= 0) {
      return scheme.surfaceContainerHighest;
    }
    if (pages < 3) {
      return scheme.primary.withValues(alpha: 0.35);
    }
    if (pages < 7) {
      return scheme.primary.withValues(alpha: 0.6);
    }
    if (pages < 15) {
      return scheme.primary.withValues(alpha: 0.8);
    }
    return scheme.primary;
  }

  Widget _planCard(
    BuildContext context,
    KhatmahPlan plan,
    ReadingSummary data,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final today = DateTime.now();

    return _card(
      context,
      title: context.tr('khatmah_plan'),
      icon: Icons.flag,
      children: [
        Text(
          AppLocalizations.translate(
            languageCode,
            'khatmah_progress',
            replacements: {
              'read': data.planPagesRead.toString(),
              'total': KhatmahPlan.totalPages.toString(),
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.translate(
            languageCode,
            'khatmah_day_of',
            replacements: {
              'day': plan.dayNumber(today).clamp(1, plan.days).toString(),
              'days': plan.days.toString(),
            },
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    const keys = [
      'day_mon',
      'day_tue',
      'day_wed',
      'day_thu',
      'day_fri',
      'day_sat',
      'day_sun',
    ];
    return context.tr(keys[(weekday - 1) % 7]);
  }
}
