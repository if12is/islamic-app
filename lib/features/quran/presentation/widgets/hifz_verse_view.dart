import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../data/services/quran_local_service.dart';

/// How much of the text is hidden while practising.
enum HifzMask {
  /// Everything visible — read it through.
  none,

  /// Only the first letter of each word: the classic memorisation crutch.
  firstLetters,

  /// Nothing but placeholders; tap a word to check yourself.
  hidden,
}

/// A passage with its words progressively hidden, tap to reveal.
///
/// Tapping a single word reveals just that word, so a stumble costs one word
/// rather than the whole page.
class HifzVerseView extends StatefulWidget {
  const HifzVerseView({
    super.key,
    required this.verses,
    required this.mask,
    this.fontSize = 24,
  });

  final List<QuranVerse> verses;
  final HifzMask mask;
  final double fontSize;

  @override
  State<HifzVerseView> createState() => _HifzVerseViewState();
}

class _HifzVerseViewState extends State<HifzVerseView> {
  /// Words the reader has uncovered, addressed as `verseKey#wordIndex`.
  final Set<String> _revealed = {};

  @override
  void didUpdateWidget(covariant HifzVerseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing the mask starts a fresh attempt.
    if (oldWidget.mask != widget.mask) {
      _revealed.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final verse in widget.verses) ...[
          ..._wordsOf(verse, colorScheme),
          _verseNumber(verse, colorScheme),
        ],
      ],
    );
  }

  List<Widget> _wordsOf(QuranVerse verse, ColorScheme colorScheme) {
    final words = verse.text.split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);

    return [
      for (var index = 0; index < words.length; index++)
        _word(verse, index, words[index], colorScheme),
    ];
  }

  Widget _word(
    QuranVerse verse,
    int index,
    String word,
    ColorScheme colorScheme,
  ) {
    final id = '${verse.key}#$index';
    final isRevealed = widget.mask == HifzMask.none || _revealed.contains(id);

    final display =
        isRevealed
            ? word
            : widget.mask == HifzMask.firstLetters
            ? _firstLetter(word)
            : '•' * _visualLength(word);

    return GestureDetector(
      onTap:
          widget.mask == HifzMask.none
              ? null
              : () => setState(() {
                if (!_revealed.add(id)) {
                  _revealed.remove(id);
                }
              }),
      child: Text(
        display,
        textDirection: TextDirection.rtl,
        style: AppTextStyles.quran(
          context,
          fontSize: widget.fontSize,
          color:
              isRevealed ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _verseNumber(QuranVerse verse, ColorScheme colorScheme) {
    return Text(
      '﴿${_arabicNumber(verse.numberInSurah)}﴾',
      style: AppTextStyles.quran(
        context,
        fontSize: widget.fontSize * 0.9,
        color: colorScheme.secondary,
      ),
    );
  }

  /// The first letter, keeping any diacritic attached to it.
  static String _firstLetter(String word) {
    final normalized = QuranLocalService.normalizeArabic(word);
    return normalized.isEmpty ? '•' : '${normalized[0]}…';
  }

  /// Dots roughly matching the word's length, so line breaks stay realistic.
  static int _visualLength(String word) {
    final normalized = QuranLocalService.normalizeArabic(word);
    return normalized.isEmpty ? 2 : normalized.length.clamp(2, 8);
  }

  static String _arabicNumber(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }
}
