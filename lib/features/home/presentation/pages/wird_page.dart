import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/custom_wird.dart';
import '../providers/custom_wird_provider.dart';
import '../widgets/daily_wird_card.dart';

/// The day's wird: the one everyone gets, and the one the reader built.
///
/// It took the Settings tab's place in the bar. There were three ways to reach
/// Settings from any screen and none at all to reach the wird, which had the
/// weight of the app exactly backwards: settings are visited a handful of
/// times ever, the wird is the thing the app exists to keep.
class WirdPage extends ConsumerWidget {
  const WirdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final custom = ref.watch(customWirdProvider);

    return AppScaffold(
      title: 'wird_title',
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          // The shared portion first: it is the same for everyone and it is
          // what a reader with an empty custom list still has to do today.
          const DailyWirdCard(),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: context.tr('wird_mine'),
            subtitle: context.tr('wird_mine_desc'),
          ),

          if (custom.isEmpty)
            const _EmptyWird()
          else ...[
            _Summary(custom: custom),
            const SizedBox(height: AppSpacing.md),
            for (final item in custom.items) ...[
              _WirdRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('wird_reset_note'),
              style: AppTextStyles.caption(
                context,
                color: tokens.inkFaint,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.custom});

  final CustomWird custom;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.translate(
                    language,
                    'wird_done_of',
                    replacements: {
                      'done': '${custom.completedCount}',
                      'total': '${custom.items.length}',
                    },
                  ),
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: AppRadii.pillAll,
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: custom.progress,
                    backgroundColor: tokens.brand.withValues(alpha: 0.11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WirdRow extends ConsumerWidget {
  const _WirdRow({required this.item});

  final CustomWirdItem item;

  static IconData iconFor(WirdKind kind) => switch (kind) {
    WirdKind.surah => Icons.menu_book_rounded,
    WirdKind.juz => Icons.auto_stories_rounded,
    WirdKind.hizb => Icons.bookmark_rounded,
    WirdKind.quarter => Icons.bookmarks_rounded,
    WirdKind.azkar => Icons.wb_twilight_rounded,
    WirdKind.tasbih => Icons.circle_outlined,
    WirdKind.dua => Icons.pan_tool_alt_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final custom = ref.watch(customWirdProvider);
    final done = custom.doneFor(item.id);
    final complete = custom.isComplete(item);
    final counted = item.target > 1;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      // A counted line advances by one per tap; a read line is done or not.
      onTap:
          () =>
              counted
                  ? ref.read(customWirdProvider.notifier).mark(item)
                  : ref.read(customWirdProvider.notifier).toggleComplete(item),
      child: Row(
        children: [
          AppIconTile(
            iconFor(item.kind),
            role: AppIconRole.row,
            tone: complete ? AppIconTone.brand : AppIconTone.neutral,
            selected: complete,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    context,
                    fontSize: 14,
                    color: complete ? tokens.inkMuted : tokens.ink,
                  ),
                ),
                if (counted) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$done / ${item.target}',
                    style: AppTextStyles.caption(context, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          if (counted && done > 0)
            IconButton(
              tooltip: context.tr('undo'),
              onPressed:
                  () => ref
                      .read(customWirdProvider.notifier)
                      .mark(item, undo: true),
              icon: Icon(
                Icons.remove_rounded,
                size: 18,
                color: tokens.inkFaint,
              ),
            ),
          IconButton(
            tooltip: context.tr('remove'),
            onPressed:
                () => ref.read(customWirdProvider.notifier).remove(item.id),
            icon: Icon(Icons.close_rounded, size: 18, color: tokens.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _EmptyWird extends StatelessWidget {
  const _EmptyWird();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('wird_empty'),
            style: AppTextStyles.body(context, fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Naming the places is the whole message: an empty state that only
          // says "nothing here" leaves the reader to hunt for the button.
          Text(
            context.tr('wird_empty_how'),
            style: AppTextStyles.caption(context),
          ),
        ],
      ),
    );
  }
}
