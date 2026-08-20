import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'islamic_icon.dart';
import 'motif_icon.dart';

/// One circle in a [StoryRail].
class StoryItem {
  const StoryItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.motif,
    this.svg,
    this.badge,
    this.highlighted = false,
  });

  final IconData icon;

  /// A drawn Islamic symbol, used instead of [icon] when given.
  final Motif? motif;

  /// A bundled vector icon; takes priority over both of the above.
  final IslamicIcon? svg;
  final String label;
  final VoidCallback onTap;

  /// A tiny count or state shown on the ring ("3", "•").
  final String? badge;

  /// Draws the gradient ring — used for the thing waiting to be resumed.
  final bool highlighted;
}

/// A row of circular shortcuts under the header.
///
/// The shortcuts people reach for five times a day should be one tap from the
/// first screen, and a rail of circles reads as "pick one" faster than a grid
/// of cards does.
class StoryRail extends StatelessWidget {
  const StoryRail({super.key, required this.items, this.height = 92});

  final List<StoryItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Centred when the row fits, scrolling when it does not — a rail pinned to
    // one edge on a wide phone reads as a layout mistake.
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final row = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                _Story(item: items[i]),
              ],
            ],
          );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - AppSpacing.sm,
              ),
              child: Center(child: row),
            ),
          );
        },
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.item});

  final StoryItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: item.onTap,
            child: Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    item.highlighted
                        ? LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [tokens.goldBright, tokens.brand],
                        )
                        : null,
                color: item.highlighted ? null : tokens.line,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.surface,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (item.svg != null)
                      AppIcon(
                        item.svg!,
                        size: 24,
                        color:
                            item.highlighted ? tokens.brand : tokens.inkMuted,
                      )
                    else if (item.motif != null)
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CustomPaint(
                          painter: MotifPainter(
                            motif: item.motif!,
                            color:
                                item.highlighted
                                    ? tokens.brand
                                    : tokens.inkMuted,
                          ),
                        ),
                      )
                    else
                      Icon(
                        item.icon,
                        size: 22,
                        color:
                            item.highlighted ? tokens.brand : tokens.inkMuted,
                      ),
                    if (item.badge != null)
                      PositionedDirectional(
                        end: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.gold,
                            borderRadius: AppRadii.pillAll,
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              fontFamily: AppTextStyles.bodyFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: tokens.onGold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              context,
              fontSize: 11,
              color: tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
