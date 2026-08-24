import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/tajweed.dart';
import '../../domain/tajweed_palette.dart';

/// Turns a verse into coloured spans.
class TajweedText {
  TajweedText._();

  /// [text] split so each run carrying a rule takes that rule's colour and
  /// everything else keeps [baseStyle].
  ///
  /// The recognizer is attached to every run, so tapping a coloured letter
  /// selects the verse exactly like tapping an uncoloured one — a reader
  /// should not have to aim between the colours.
  static List<InlineSpan> spansFor({
    required String text,
    required TextStyle baseStyle,
    required TajweedPalette palette,
    GestureRecognizer? recognizer,
  }) {
    final rules = Tajweed.analyse(text);
    if (rules.isEmpty) {
      return [TextSpan(text: text, style: baseStyle, recognizer: recognizer)];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final span in rules) {
      if (span.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, span.start),
            style: baseStyle,
            recognizer: recognizer,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(span.start, span.end),
          style: baseStyle.copyWith(color: palette.of(span.rule)),
          recognizer: recognizer,
        ),
      );
      cursor = span.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: baseStyle,
          recognizer: recognizer,
        ),
      );
    }

    return spans;
  }
}

/// The colour key, and the honest note about what it does not cover.
class TajweedKeySheet extends StatelessWidget {
  const TajweedKeySheet({super.key, required this.isDarkGround});

  final bool isDarkGround;

  static Future<void> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TajweedKeySheet(isDarkGround: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = TajweedPalette.forGround(isDark: isDarkGround);

    return Directionality(
      textDirection: context.appTextDirection,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.94,
        minChildSize: 0.4,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                context.tr('tajweed_key'),
                style: AppTextStyles.display(
                  context,
                  fontSize: 19,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('tajweed_note'),
                style: AppTextStyles.caption(context, color: tokens.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final rule in TajweedPalette.keyOrder)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.of(rule),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    context.tr(rule.labelKey),
                                    style: AppTextStyles.body(
                                      context,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (rule.lengthAr != null) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.groundAlt,
                                      borderRadius: AppRadii.pillAll,
                                    ),
                                    child: Text(
                                      rule.lengthAr!,
                                      style: AppTextStyles.caption(
                                        context,
                                        color: tokens.inkFaint,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr(rule.descriptionKey),
                              style: AppTextStyles.caption(
                                context,
                                color: tokens.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: AppSpacing.xxl),
              Text(
                context.tr('tajweed_limits'),
                style: AppTextStyles.caption(context, color: tokens.inkMuted),
              ),
            ],
          );
        },
      ),
    );
  }
}
