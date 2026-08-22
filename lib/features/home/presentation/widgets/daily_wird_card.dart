import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../azkar/presentation/pages/azkar_details_page.dart';
import '../../../quran/presentation/pages/surah_reader_page.dart';
import '../../../quran/presentation/providers/bookmarks_provider.dart';
import '../../../quran/presentation/providers/reading_progress_provider.dart';
import '../providers/daily_wird_provider.dart';

/// The day's portion in one card: Quran pages, morning and evening azkar,
/// and the tasbeeh — each tappable, each showing how far along it is.
class DailyWirdCard extends ConsumerWidget {
  const DailyWirdCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wird = ref.watch(dailyWirdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: wird.when(
        loading:
            () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
        error: (_, _) => Text(context.tr('wird_unavailable')),
        data: (data) => _content(context, ref, data),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, DailyWird wird) {
    final colorScheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              wird.isComplete ? Icons.verified : Icons.task_alt,
              color:
                  wird.isComplete ? colorScheme.primary : colorScheme.secondary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('daily_wird'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              AppLocalizations.translate(
                languageCode,
                'wird_done_of',
                replacements: {
                  'done': wird.completed.toString(),
                  'total': wird.total.toString(),
                },
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: wird.progress,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        for (final task in wird.tasks) _taskRow(context, ref, task),
      ],
    );
  }

  Widget _taskRow(BuildContext context, WidgetRef ref, WirdTask task) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context, ref, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              task.isComplete
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 20,
              color:
                  task.isComplete
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(task.titleKey),
                style:
                    task.dueNow
                        ? null
                        : TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // What is not due yet is dimmed and labelled, rather than shown as
            // a count someone is failing to reach.
            Text(
              task.dueNow
                  ? '${task.done}/${task.target}'
                  : context.tr('wird_not_due'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: task.dueNow ? null : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              context.isAppRtl
                  ? Icons.keyboard_arrow_left
                  : Icons.keyboard_arrow_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, WirdTask task) {
    final category = task.category;
    if (category != null) {
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => AzkarDetailsPage(category: category),
            ),
          )
          .then((_) => ref.invalidate(dailyWirdProvider));
      return;
    }

    // The Quran row resumes where the reader stopped.
    final lastRead = ref.read(lastReadProvider);
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder:
                (_) => SurahReaderPage(
                  surahNumber: lastRead?.surahNumber ?? 1,
                  initialVerse: lastRead?.verseNumber,
                ),
          ),
        )
        .then((_) {
          ref.read(readingProgressProvider.notifier).refresh();
          ref.invalidate(dailyWirdProvider);
        });
  }
}
