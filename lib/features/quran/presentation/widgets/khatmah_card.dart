import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/khatmah_plan.dart';
import '../pages/reading_stats_page.dart';
import '../providers/reading_progress_provider.dart';

/// The khatmah plan on the Quran tab: start one, or see where today stands.
///
/// The daily portion is re-spread over the days that are left, so a missed day
/// nudges tomorrow instead of leaving an impossible pile at the end.
class KhatmahCard extends ConsumerWidget {
  const KhatmahCard({super.key});

  static const List<int> _presets = [7, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(khatmahPlanProvider);
    final summary = ref.watch(readingProgressProvider).value;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child:
          plan == null
              ? _setup(context, ref)
              : _progress(context, ref, plan, summary),
    );
  }

  Widget _setup(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, context.tr('khatmah_plan')),
        const SizedBox(height: 6),
        Text(
          context.tr('khatmah_plan_desc'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in _presets)
              ActionChip(
                label: Text(
                  AppLocalizations.translate(
                    Localizations.localeOf(context).languageCode,
                    'khatmah_in_days',
                    replacements: {'days': days.toString()},
                  ),
                ),
                onPressed:
                    () => ref.read(khatmahPlanProvider.notifier).start(days),
              ),
            ActionChip(
              avatar: const Icon(Icons.edit, size: 16),
              label: Text(context.tr('khatmah_custom')),
              onPressed: () => _askForDays(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progress(
    BuildContext context,
    WidgetRef ref,
    KhatmahPlan plan,
    ReadingSummary? summary,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final pagesRead = summary?.planPagesRead ?? 0;
    final today = DateTime.now();
    final target = plan.todayTarget(today, pagesRead);
    final ahead = plan.pagesAhead(today, pagesRead);
    final todayPages = summary?.today.pageCount ?? 0;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _header(context, context.tr('khatmah_plan'))),
            IconButton(
              tooltip: context.tr('reading_stats'),
              icon: const Icon(Icons.insights),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReadingStatsPage(),
                    ),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (plan.isComplete) ...[
          Row(
            children: [
              Icon(Icons.emoji_events, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('khatmah_completed'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => ref.read(khatmahPlanProvider.notifier).cancel(),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.tr('khatmah_start_new')),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: plan.progress(pagesRead),
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.translate(
              languageCode,
              'khatmah_progress',
              replacements: {
                'read': pagesRead.toString(),
                'total': KhatmahPlan.totalPages.toString(),
              },
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  label: context.tr('today_portion'),
                  value: AppLocalizations.translate(
                    languageCode,
                    'pages_count',
                    replacements: {'count': target.toString()},
                  ),
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  label: context.tr('today_read'),
                  value: AppLocalizations.translate(
                    languageCode,
                    'pages_count',
                    replacements: {'count': todayPages.toString()},
                  ),
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  label: context.tr('days_left'),
                  value: plan.daysRemaining(today).toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                ahead >= 0 ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: ahead >= 0 ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ahead >= 0
                      ? AppLocalizations.translate(
                        languageCode,
                        'khatmah_ahead',
                        replacements: {'pages': ahead.toString()},
                      )
                      : AppLocalizations.translate(
                        languageCode,
                        'khatmah_behind',
                        replacements: {'pages': (-ahead).toString()},
                      ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed:
                    () => ref.read(khatmahPlanProvider.notifier).cancel(),
                child: Text(context.tr('khatmah_cancel')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, String title) {
    return Row(
      children: [
        Icon(
          Icons.menu_book,
          color: Theme.of(context).colorScheme.secondary,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ],
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  Future<void> _askForDays(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '30');
    final days = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('khatmah_custom')),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: dialogContext.tr('khatmah_days_label'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(
                      dialogContext,
                    ).pop(int.tryParse(controller.text.trim())),
                child: Text(dialogContext.tr('save')),
              ),
            ],
          ),
    );

    controller.dispose();
    if (days != null && days > 0) {
      await ref.read(khatmahPlanProvider.notifier).start(days);
    }
  }
}
