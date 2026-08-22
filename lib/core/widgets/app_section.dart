import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';

/// A section title with an optional control on the far side.
///
/// Every list in the app is introduced the same way, so the eye learns where
/// to look once instead of on every screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
    this.trailingLabel,
  });

  final String title;
  final String? subtitle;

  /// A control — usually a [PillSelector] — shown opposite the title.
  final Widget? trailing;

  /// A plain text action ("see all") used when [trailing] is absent.
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A text action belongs at the far edge of the row, not tucked
          // against the title — so the title takes every pixel it is not
          // using and pushes "see all" out to the margin. A pill selector is
          // different: it needs to share the width, so it stays Flexible.
          _TitleSlot(
            expand: trailing == null && trailingLabel != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(
                    context,
                    fontSize: 19,
                    color: tokens.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            // Flexible, not raw: a horizontally scrolling child would
            // otherwise demand its whole intrinsic width from the row.
            Flexible(child: trailing!)
          else if (trailingLabel != null)
            TextButton(
              onPressed: onTrailingTap,
              style: TextButton.styleFrom(
                // Sit flush with the section's own margin rather than floating
                // a button's worth of padding in from it.
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(trailingLabel!),
            ),
        ],
      ),
    );
  }
}

/// Holds the title: greedy when a text action must be pushed to the edge,
/// content-sized when a control has to share the row.
class _TitleSlot extends StatelessWidget {
  const _TitleSlot({required this.expand, required this.child});

  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      expand ? Expanded(child: child) : Flexible(child: child);
}

/// One option in a [PillSelector].
class PillOption<T> {
  const PillOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// The filter control: a track of pills where the chosen one lifts.
///
/// The selected pill is a raised surface rather than a block of accent colour.
/// That is the whole trick behind how calm the reference designs feel — the
/// selection reads through elevation, so the accent stays free for things that
/// are actually live.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.scrollable = true,
  });

  final List<PillOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;

  /// Lets a long set of filters scroll instead of squeezing.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final track = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.groundAlt,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _Pill(
              option: option,
              selected: option.value == value,
              compact: compact,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );

    if (!scrollable) {
      return track;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: track,
    );
  }
}

class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.option,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final PillOption<T> option;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? tokens.surfaceRaised : Colors.transparent,
        borderRadius: AppRadii.pillAll,
        boxShadow: selected ? AppShadows.soft(tokens.ink) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.lg,
              vertical: compact ? 6 : AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 15,
                    color: selected ? tokens.brand : tokens.inkFaint,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: AppTextStyles.bodyFamily,
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? tokens.ink : tokens.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single sentence telling the user what to do next.
///
/// Used where a number alone is not an instruction — the compass being the
/// clearest case: "257°" means nothing, "turn 135° left" means everything.
class HintPill extends StatelessWidget {
  const HintPill({
    super.key,
    required this.text,
    this.icon,
    this.tone = HintTone.neutral,
  });

  final String text;
  final IconData? icon;
  final HintTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final (background, foreground) = switch (tone) {
      HintTone.neutral => (tokens.surface, tokens.inkMuted),
      HintTone.accent => (
        tokens.gold.withValues(alpha: 0.16),
        tokens.isDark ? tokens.goldBright : tokens.gold,
      ),
      HintTone.success => (tokens.brand.withValues(alpha: 0.16), tokens.brand),
    };

    return AnimatedContainer(
      duration: AppMotion.base,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillAll,
        boxShadow:
            tone == HintTone.neutral ? AppShadows.soft(tokens.ink) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.bodyFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum HintTone { neutral, accent, success }

/// A borderless icon action, for rows of verse tools.
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.size = 18,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final button = Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: size,
            color: active ? tokens.brand : tokens.inkFaint,
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
