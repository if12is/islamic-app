import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'islamic_icon.dart';
import 'motif_icon.dart';

/// One tile in a [ShortcutGrid].
class ShortcutItem {
  const ShortcutItem({
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

  /// A tiny count or state shown on the tile ("3", "•").
  final String? badge;

  /// Draws the gradient ring — used for the thing waiting to be resumed.
  final bool highlighted;
}

/// The shortcuts people reach for daily, all of them on screen at once.
///
/// This was a rail that scrolled sideways. Six shortcuts, four and a half of
/// them visible, the last one sliced off at the edge — and a sideways drag
/// inside a page that already drags downwards is close to the least discovered
/// gesture there is. Someone who does not know to swipe simply has four
/// shortcuts, and has no way of finding out otherwise.
///
/// A grid cannot hide anything. Three to a row, wrapping as many rows as it
/// takes, every tile the same size and nothing at the edge to suggest there is
/// more. The labels grew with the tiles: they were 11px under a rail sized for
/// how many circles would fit, and the grid has room for a word people can
/// actually read.
class ShortcutGrid extends StatelessWidget {
  const ShortcutGrid({super.key, required this.items, this.perRow = 3});

  final List<ShortcutItem> items;

  /// How many tiles share a row before it wraps.
  final int perRow;

  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _Shortcut(item: item)),
          ],
        );
      },
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.item});

  final ShortcutItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = item.highlighted ? tokens.brand : tokens.inkMuted;

    return Semantics(
      button: true,
      label: item.badge == null ? item.label : '${item.label} — ${item.badge}',
      child: ExcludeSemantics(
        child: Material(
          color: tokens.surface,
          borderRadius: AppRadii.mdAll,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: AppRadii.mdAll,
            child: Container(
              // The whole tile is the target, not the circle inside it.
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.mdAll,
                border: Border.all(
                  color: item.highlighted ? tokens.gold : tokens.line,
                  width: item.highlighted ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (item.svg != null)
                        AppIcon(item.svg!, size: 26, color: tint)
                      else if (item.motif != null)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(
                            painter: MotifPainter(
                              motif: item.motif!,
                              color: tint,
                            ),
                          ),
                        )
                      else
                        Icon(item.icon, size: 26, color: tint),
                      if (item.badge != null)
                        PositionedDirectional(
                          end: -12,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.onGold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
