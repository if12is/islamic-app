import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/quran_local_service.dart';
import '../pages/surah_reader_page.dart';
import '../providers/bookmarks_provider.dart';

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
    if (lastRead == null) {
      return const SizedBox.shrink();
    }

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
                'verse': verse.toString(),
                'total': surah.versesCount.toString(),
                'page':
                    QuranLocalService.verse(
                      lastRead.surahNumber,
                      verse,
                    ).page.toString(),
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => SurahReaderPage(
                            surahNumber: lastRead.surahNumber,
                            initialVerse: verse,
                          ),
                    ),
                  ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(context.tr('continue_reading')),
            ),
          ),
        ],
      ),
    );
  }
}
