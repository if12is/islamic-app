import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'app_section.dart';

/// One verse: a number, the text, what it means, and the tools.
///
/// There is no rule between verses and no frame around them — the separation
/// is space. That is a deliberate rejection of the boxed-verse look: a page of
/// bordered cards reads as a form to fill in, while a page of well-spaced text
/// reads as something to sit with.
class AyahBlock extends StatelessWidget {
  const AyahBlock({
    super.key,
    required this.numberLabel,
    required this.arabic,
    this.translation,
    this.footnote,
    this.actions = const [],
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.fontSize = 26,
    this.textAlign = TextAlign.center,
  });

  /// "١:١" or just the verse number.
  final String numberLabel;

  final String arabic;

  /// Translation or tafsir line under the verse.
  final String? translation;

  /// A small line under everything — a note, a bookmark label.
  final String? footnote;

  final List<Widget> actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The verse currently being recited or searched for.
  final bool highlighted;

  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AnimatedContainer(
      duration: AppMotion.base,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color:
            highlighted
                ? tokens.gold.withValues(alpha: 0.13)
                : Colors.transparent,
        borderRadius: AppRadii.mdAll,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadii.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.groundAlt,
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      numberLabel,
                      style: TextStyle(
                        fontFamily: AppTextStyles.bodyFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.inkFaint,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ...actions,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                arabic,
                textAlign: textAlign,
                textDirection: TextDirection.rtl,
                style: AppTextStyles.quran(
                  context,
                  fontSize: fontSize,
                  color: tokens.ink,
                ),
              ),
              if (translation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  translation!,
                  style: AppTextStyles.body(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
              if (footnote != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  footnote!,
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The usual trio under a verse.
  ///
  /// [context] is required rather than optional so the three buttons are named
  /// for a screen reader — an unlabelled icon is a button that announces
  /// itself as "button" and nothing else.
  static List<Widget> defaultActions(
    BuildContext context, {
    VoidCallback? onPlay,
    VoidCallback? onBookmark,
    VoidCallback? onShare,
    bool bookmarked = false,
  }) => [
    if (onPlay != null)
      GhostIconButton(
        icon: Icons.play_circle_outline,
        tooltip: context.tr('play'),
        onTap: onPlay,
      ),
    if (onBookmark != null)
      GhostIconButton(
        icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
        tooltip: context.tr(bookmarked ? 'remove_bookmark' : 'add_bookmark'),
        onTap: onBookmark,
        active: bookmarked,
      ),
    if (onShare != null)
      GhostIconButton(
        icon: Icons.ios_share,
        tooltip: context.tr('share_text'),
        onTap: onShare,
      ),
  ];
}
