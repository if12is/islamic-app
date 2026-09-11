import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../data/services/quran_local_service.dart';
import '../pages/surah_reader_page.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/reading_history_provider.dart';
import 'reading_history_sheet.dart';

/// "Continue where you left off."
///
/// Reads the live position rather than a snapshot taken when the screen was
/// built, so it is right even if the reader was closed a second ago — and it
/// shows how far into the surah that position is.
class LastReadCard extends ConsumerWidget {
  const LastReadCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRead = ref.watch(lastReadProvider);
    final history = ref.watch(readingHistoryProvider);
    if (lastRead == null) {
      return const SizedBox.shrink();
    }
    final resume = resumeForLastRead(lastRead, history);

    final colorScheme = Theme.of(context).colorScheme;
    final surah = QuranLocalService.surahInfo(lastRead.surahNumber);
    final verse = lastRead.verseNumber.clamp(1, surah.versesCount);
    final progress = verse / surah.versesCount;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('last_read'),
                      style: AppTextStyles.caption(
                        context,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${context.tr('surah_word')} ${surah.nameAr}',
            style: AppTextStyles.display(
              context,
              fontSize: 24,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.translate(
              languageCode,
              'last_read_position',
              replacements: {
                'verse': localizeDigits(context, '$verse'),
                'total': localizeDigits(context, '${surah.versesCount}'),
                'page': localizeDigits(
                  context,
                  '${QuranLocalService.verse(lastRead.surahNumber, verse).page}',
                ),
              },
            ),
            style: AppTextStyles.caption(
              context,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.onPrimaryContainer.withValues(
                alpha: 0.15,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => SurahReaderPage(
                              surahNumber: lastRead.surahNumber,
                              initialVerse: verse,
                              historyId: resume?.historyId,
                            ),
                      ),
                    ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(context.tr('continue_reading')),
              ),
              // "Last read" is only ever the last place. Everywhere before it
              // — the khatmah left for a verse looked up in a search — is one
              // tap further, not gone.
              if (history.length > 1)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () => ReadingHistorySheet.show(context),
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(context.tr('history_open')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
