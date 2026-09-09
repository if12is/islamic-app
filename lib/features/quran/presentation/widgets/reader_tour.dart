import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/reader_tour_store.dart';

/// One thing the reading page can do.
class ReaderTourStep {
  const ReaderTourStep({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
}

/// What the reading page can do, one card at a time.
///
/// The page had grown a great deal it never mentioned: pinch to resize, colour
/// the tajweed, change the paper, tap a verse for its tools, read page by page.
/// A feature nobody is told about is a feature nobody has, and the usual answer
/// — a longer settings sheet — only moves the problem, because the reader has
/// to already suspect the thing exists to go looking for it.
///
/// Three ways out, all of them on the card: next until it ends, skip, or "I
/// know this" which stops it coming back. Anything that reappears without a way
/// to stop it teaches people to dismiss it unread.
class ReaderTour extends StatefulWidget {
  const ReaderTour({super.key});

  static const List<ReaderTourStep> steps = [
    ReaderTourStep(
      icon: Icons.pinch_rounded,
      titleKey: 'tour_zoom_title',
      bodyKey: 'tour_zoom_body',
    ),
    ReaderTourStep(
      icon: Icons.palette_outlined,
      titleKey: 'tour_tajweed_title',
      bodyKey: 'tour_tajweed_body',
    ),
    ReaderTourStep(
      icon: Icons.contrast_rounded,
      titleKey: 'tour_paper_title',
      bodyKey: 'tour_paper_body',
    ),
    ReaderTourStep(
      icon: Icons.touch_app_outlined,
      titleKey: 'tour_verse_title',
      bodyKey: 'tour_verse_body',
    ),
    ReaderTourStep(
      icon: Icons.headphones_outlined,
      titleKey: 'tour_listen_title',
      bodyKey: 'tour_listen_body',
    ),
  ];

  /// Show it if it is due, and record that it was shown.
  ///
  /// Returns without doing anything when it is not due, so the caller can call
  /// it on every open without asking the question itself.
  static Future<void> maybeShow(BuildContext context) async {
    if (!ReaderTourStore.shouldShow(appPreferences)) {
      return;
    }
    // Recorded before it is shown, not after. A reader who leaves the page
    // mid-tour has still been interrupted once, and showing it again on the
    // next open would be the interruption they just walked away from.
    await ReaderTourStore.markShown(appPreferences);
    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReaderTour(),
    );
  }

  @override
  State<ReaderTour> createState() => _ReaderTourState();
}

class _ReaderTourState extends State<ReaderTour> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final step = ReaderTour.steps[_index];
    final isLast = _index == ReaderTour.steps.length - 1;

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconTile(step.icon, role: AppIconRole.feature),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.tr(step.titleKey),
            style: AppTextStyles.display(context, fontSize: 19),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(step.bodyKey),
            style: AppTextStyles.body(context, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Where you are in the set, so "next" has a visible end.
          Row(
            children: [
              for (var i = 0; i < ReaderTour.steps.length; i++)
                AnimatedContainer(
                  duration: AppMotion.base,
                  margin: const EdgeInsetsDirectional.only(end: 5),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        i == _index
                            ? tokens.brand
                            : tokens.brand.withValues(alpha: 0.22),
                    borderRadius: AppRadii.pillAll,
                  ),
                ),
            ],
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      // Laid out by hand rather than left to the dialog's own bar, which puts
      // three buttons in a column when they will not fit on one line — and
      // three stacked buttons of equal weight give no clue which is the way
      // forward. The two that move through the cards share a row; the one that
      // ends it for good sits under them, quieter.
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('skip')),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (isLast) {
                    Navigator.of(context).pop();
                    return;
                  }
                  setState(() => _index++);
                },
                child: Text(context.tr(isLast ? 'done' : 'tour_next')),
              ),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: () async {
              await ReaderTourStore.dismissForever(appPreferences);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              context.tr('tour_never_again'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ),
        ),
      ],
    );
  }
}
