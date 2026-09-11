import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../data/reading_history_store.dart';
import '../../data/services/quran_local_service.dart';
import '../pages/surah_reader_page.dart';
import '../providers/reading_history_provider.dart';

/// Every place the reader has read from, one tap from carrying on.
///
/// The pinned line — the reader's own wird — sits first whatever its age, so
/// the khatmah is always the first thing under the thumb even after a week of
/// looking verses up.
class ReadingHistorySheet extends ConsumerWidget {
  const ReadingHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => Directionality(
            textDirection: sheetContext.appTextDirection,
            child: const ReadingHistorySheet(),
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final marks = [...ref.watch(readingHistoryProvider)]..sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('history_title'),
                style: AppTextStyles.display(context, fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr('history_desc'),
                style: AppTextStyles.caption(context, color: tokens.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              if (marks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    context.tr('history_empty'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      fontSize: 14,
                      color: tokens.inkMuted,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final mark in marks) _MarkRow(mark: mark),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkRow extends ConsumerWidget {
  const _MarkRow({required this.mark});

  final ReadingMark mark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = Localizations.localeOf(context).languageCode;
    final info = QuranLocalService.surahInfo(mark.surah);
    final name = language == 'ar' ? info.nameAr : info.nameEn;

    final title = AppLocalizations.translate(
      language,
      'history_mark_title',
      replacements: {
        'surah': name,
        'verse': localizeDigits(context, '${mark.verse}'),
      },
    );
    final span =
        mark.page > mark.startPage
            ? AppLocalizations.translate(
              language,
              'history_pages',
              replacements: {
                'from': localizeDigits(context, '${mark.startPage}'),
                'to': localizeDigits(context, '${mark.page}'),
              },
            )
            : AppLocalizations.translate(
              language,
              'history_page',
              replacements: {'page': localizeDigits(context, '${mark.page}')},
            );
    final meta = [
      if (mark.pinned) context.tr('history_pinned'),
      span,
      _when(context, mark.updatedAt),
    ].join(' · ');

    return AppListRow(
      leading: AppIconTile(
        mark.pinned ? Icons.push_pin : Icons.auto_stories_outlined,
        role: AppIconRole.row,
        tone: mark.pinned ? AppIconTone.accent : AppIconTone.neutral,
        selected: mark.pinned,
      ),
      title: title,
      meta: meta,
      selected: mark.pinned,
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(
          MaterialPageRoute<void>(
            builder:
                (_) => SurahReaderPage(
                  surahNumber: mark.surah,
                  initialVerse: mark.verse,
                  historyId: mark.id,
                ),
          ),
        );
      },
      trailing: MenuAnchor(
        builder:
            (context, controller, _) => IconButton(
              tooltip: context.tr('history_options'),
              icon: const Icon(Icons.more_vert),
              onPressed:
                  () => controller.isOpen ? controller.close() : controller.open(),
            ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: Icon(
              mark.pinned ? Icons.push_pin_outlined : Icons.push_pin,
              size: 18,
            ),
            onPressed:
                () => ref
                    .read(readingHistoryProvider.notifier)
                    .setPinned(mark.id, pinned: !mark.pinned),
            child: Text(
              context.tr(mark.pinned ? 'history_unpin' : 'history_pin'),
            ),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.delete_outline, size: 18),
            onPressed:
                () => ref.read(readingHistoryProvider.notifier).remove(mark.id),
            child: Text(context.tr('history_remove')),
          ),
        ],
      ),
    );
  }

  /// "اليوم · ٩:١٠ م", "أمس", "الجمعة", or a date for anything older.
  static String _when(BuildContext context, DateTime time) {
    final language = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    // Calendar days in UTC: two local midnights either side of a clock
    // change are 23 hours apart, which `inDays` counts as the same day.
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = DateTime.utc(time.year, time.month, time.day);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) {
      return '${context.tr('today')} ${NotificationPlanner.formatClock(time, language)}';
    }
    if (daysAgo == 1) {
      return context.tr('yesterday');
    }
    if (daysAgo < 7) {
      return context.tr(_weekdayKeys[time.weekday - 1]);
    }
    return localizeDigits(context, '${time.day}/${time.month}');
  }

  static const List<String> _weekdayKeys = [
    'weekday_monday',
    'weekday_tuesday',
    'weekday_wednesday',
    'weekday_thursday',
    'weekday_friday',
    'weekday_saturday',
    'weekday_sunday',
  ];
}
