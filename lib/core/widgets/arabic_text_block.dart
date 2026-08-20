import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/quran_text_detector.dart';

/// Renders mixed Arabic text with the right face for each part.
///
/// Verses come out in the Mushaf face inside a tinted frame; du'a and dhikr
/// prose stays in the body face. That is the whole point: you should be able
/// to see where revelation starts without reading a word.
class ArabicTextBlock extends StatelessWidget {
  const ArabicTextBlock({
    super.key,
    required this.text,
    this.quranFontSize = 21,
    this.bodyFontSize = 17,
    this.color,
    this.textAlign = TextAlign.center,
    this.frameQuran = true,
  });

  final String text;
  final double quranFontSize;
  final double bodyFontSize;
  final Color? color;
  final TextAlign textAlign;

  /// Draw a tinted frame around Quranic runs.
  final bool frameQuran;

  @override
  Widget build(BuildContext context) {
    final segments = QuranTextDetector.segment(text);
    final colorScheme = Theme.of(context).colorScheme;

    // Nothing Quranic: a single plain paragraph, no decoration.
    if (!segments.any((segment) => segment.isQuran)) {
      return Text(
        text.trim(),
        textAlign: textAlign,
        textDirection: TextDirection.rtl,
        style: AppTextStyles.body(
          context,
          fontSize: bodyFontSize,
          color: color,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          if (segments[i].isQuran)
            _quranBlock(context, segments[i].text, colorScheme)
          else
            Text(
              segments[i].text,
              textAlign: textAlign,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.body(
                context,
                fontSize: bodyFontSize,
                color: color,
              ),
            ),
        ],
      ],
    );
  }

  Widget _quranBlock(
    BuildContext context,
    String verseText,
    ColorScheme colorScheme,
  ) {
    // Ornamental brackets mark revelation the way a Mushaf does — no rails,
    // no coloured bars, just the marks readers already know.
    final content = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '﴿ ',
            style: AppTextStyles.quran(
              context,
              fontSize: quranFontSize,
              color: colorScheme.secondary,
            ),
          ),
          TextSpan(text: verseText),
          TextSpan(
            text: ' ﴾',
            style: AppTextStyles.quran(
              context,
              fontSize: quranFontSize,
              color: colorScheme.secondary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: AppTextStyles.quran(
        context,
        fontSize: quranFontSize,
        color: color ?? colorScheme.onSurface,
      ),
    );

    if (!frameQuran) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}
