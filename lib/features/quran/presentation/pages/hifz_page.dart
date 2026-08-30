import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/quran_local_service.dart';
import '../../domain/entities/hifz_item.dart';
import '../providers/hifz_provider.dart';
import 'hifz_quiz_page.dart';
import 'hifz_review_page.dart';
import 'surah_reader_page.dart';

/// The memorisation desk: what is due today, everything being memorised, and
/// a way to add a new passage.
class HifzPage extends ConsumerWidget {
  const HifzPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(hifzProvider);
    final due = ref.watch(hifzDueProvider);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('hifz'),
        style: AppTextStyles.display(context, fontSize: 19),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('hifz_quiz'),
          icon: const Icon(Icons.quiz_outlined),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HifzQuizPage()),
              ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPassage(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('hifz_add')),
      ),
      body: items.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (all) {
          if (all.isEmpty) {
            return _empty(context);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _dueCard(context, ref, due),
              const SizedBox(height: 20),
              Text(
                context.tr('hifz_all'),
                style: AppTextStyles.display(context, fontSize: 17),
              ),
              const SizedBox(height: 10),
              for (final item in all) _itemTile(context, ref, item),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('hifz_empty'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueCard(BuildContext context, WidgetRef ref, List<HifzItem> due) {
    final tokens = context.tokens;

    return AppCard(
      // A tint, not primaryContainer: the card is the app's own surface with
      // the brand washed over it when there is something due, which is how
      // every other "this one is live" card in the app is marked.
      accent: due.isEmpty ? null : tokens.brand.withValues(alpha: 0.09),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(
                due.isEmpty ? Icons.check_circle_outline : Icons.event_repeat,
                role: AppIconRole.card,
                selected: due.isNotEmpty,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  context.tr('hifz_due_today'),
                  style: AppTextStyles.display(context, fontSize: 17),
                ),
              ),
              AppIconCount(count: '${due.length}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            due.isEmpty
                ? context.tr('hifz_nothing_due')
                : context.tr('hifz_due_desc'),
            style: AppTextStyles.caption(context),
          ),
          if (due.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HifzReviewPage(items: due),
                      ),
                    ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(context.tr('hifz_start_review')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemTile(BuildContext context, WidgetRef ref, HifzItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = QuranLocalService.surahInfo(item.surahNumber);
    final isDue = item.isDue(DateTime.now());

    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => ref.read(hifzProvider.notifier).remove(item),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          // The brand wash for "due now", the plain surface otherwise. It was
          // a border that changed colour, which is a hairline the eye has to
          // hunt for; every other list in the app marks state with a fill.
          accent: isDue ? context.tokens.brand.withValues(alpha: 0.09) : null,
          child: Row(
            children: [
              AppIconTile(
                Icons.psychology_alt_outlined,
                role: AppIconRole.row,
                selected: isDue,
                tone: isDue ? AppIconTone.brand : AppIconTone.neutral,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('surah_word')} ${surah.nameAr} · '
                      '${item.fromAyah}-${item.toAyah}',
                      style: AppTextStyles.display(context, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDue
                          ? context.tr('hifz_due_now')
                          : '${context.tr('hifz_next_review')}: '
                              '${item.dueDate.day}/${item.dueDate.month}',
                      style: AppTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
              _strengthBar(context, item),
              IconButton(
                tooltip: context.tr('open_in_reader'),
                icon: const Icon(Icons.menu_book, size: 20),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => SurahReaderPage(
                              surahNumber: item.surahNumber,
                              initialVerse: item.fromAyah,
                            ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strengthBar(BuildContext context, HifzItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.strength,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.reviews}',
            style: AppTextStyles.caption(context, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Pick a surah and a verse range to memorise.
  Future<void> _addPassage(BuildContext context, WidgetRef ref) async {
    var surahNumber = 78;
    var fromAyah = 1;
    var toAyah = 5;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final surah = QuranLocalService.surahInfo(surahNumber);
            final maxAyah = surah.versesCount;

            return Directionality(
              textDirection: context.appTextDirection,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('hifz_add'),
                      style: AppTextStyles.display(context, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: surahNumber,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('surah_word'),
                      ),
                      items: [
                        for (final item in QuranLocalService.surahs())
                          DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.id}. ${item.nameAr}'),
                          ),
                      ],
                      onChanged:
                          (value) => setSheetState(() {
                            surahNumber = value ?? surahNumber;
                            fromAyah = 1;
                            toAyah = QuranLocalService.surahInfo(
                              surahNumber,
                            ).versesCount.clamp(1, 5);
                          }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${context.tr('range_from')}: $fromAyah',
                      style: AppTextStyles.caption(context),
                    ),
                    Slider(
                      value: fromAyah.toDouble().clamp(1, maxAyah.toDouble()),
                      min: 1,
                      max: maxAyah.toDouble(),
                      divisions: maxAyah > 1 ? maxAyah - 1 : 1,
                      onChanged:
                          (value) => setSheetState(() {
                            fromAyah = value.round();
                            if (toAyah < fromAyah) {
                              toAyah = fromAyah;
                            }
                          }),
                    ),
                    Text(
                      '${context.tr('range_to')}: $toAyah',
                      style: AppTextStyles.caption(context),
                    ),
                    Slider(
                      value: toAyah.toDouble().clamp(1, maxAyah.toDouble()),
                      min: 1,
                      max: maxAyah.toDouble(),
                      divisions: maxAyah > 1 ? maxAyah - 1 : 1,
                      onChanged:
                          (value) => setSheetState(() {
                            toAyah = value.round();
                            if (fromAyah > toAyah) {
                              fromAyah = toAyah;
                            }
                          }),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: Text(context.tr('save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (added == true) {
      await ref
          .read(hifzProvider.notifier)
          .add(surahNumber: surahNumber, fromAyah: fromAyah, toAyah: toAyah);
    }
  }
}
