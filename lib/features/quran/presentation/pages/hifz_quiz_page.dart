import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/hifz_provider.dart';

/// "Finish the verse": one verse is shown, four continuations are offered.
///
/// Questions are drawn from what the reader is memorising when there is
/// anything in the list, and from short surahs otherwise — so the quiz is
/// useful on day one and sharper later.
class HifzQuizPage extends ConsumerStatefulWidget {
  const HifzQuizPage({super.key});

  @override
  ConsumerState<HifzQuizPage> createState() => _HifzQuizPageState();
}

class _HifzQuizPageState extends ConsumerState<HifzQuizPage> {
  static const int _questionCount = 10;

  final Random _random = Random();

  late List<_Question> _questions;
  int _index = 0;
  int _score = 0;
  int? _chosen;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  List<_Question> _buildQuestions() {
    final pool = <QuranVerse>[];

    for (final item in ref.read(hifzProvider).value ?? const []) {
      for (var ayah = item.fromAyah; ayah < item.toAyah; ayah++) {
        pool.add(QuranLocalService.verse(item.surahNumber, ayah));
      }
    }

    // Fall back to the last juz: short verses everyone half-knows.
    if (pool.length < 4) {
      for (var surah = 100; surah <= 114; surah++) {
        final verses = QuranLocalService.versesOfSurah(surah);
        for (var i = 0; i < verses.length - 1; i++) {
          pool.add(verses[i]);
        }
      }
    }

    pool.shuffle(_random);
    final chosen = pool.take(_questionCount).toList();

    return [
      for (final verse in chosen)
        _Question(
          prompt: verse,
          answer: QuranLocalService.verse(
            verse.surahNumber,
            verse.numberInSurah + 1,
          ),
          options: _optionsFor(verse),
        ),
    ];
  }

  /// The true continuation plus three plausible decoys.
  List<QuranVerse> _optionsFor(QuranVerse verse) {
    final answer = QuranLocalService.verse(
      verse.surahNumber,
      verse.numberInSurah + 1,
    );

    final decoys = <QuranVerse>{};
    var guard = 0;
    while (decoys.length < 3 && guard < 60) {
      guard++;
      final candidate = QuranLocalService.verseByGlobalNumber(
        1 + _random.nextInt(QuranLocalService.verseCount),
      );
      if (candidate.key != answer.key && candidate.key != verse.key) {
        decoys.add(candidate);
      }
    }

    final options = [answer, ...decoys]..shuffle(_random);
    return options;
  }

  void _choose(int optionIndex) {
    if (_chosen != null) {
      return;
    }

    final question = _questions[_index];
    final isCorrect = question.options[optionIndex].key == question.answer.key;

    setState(() {
      _chosen = optionIndex;
      if (isCorrect) {
        _score++;
      }
    });
  }

  void _next() {
    if (_index >= _questions.length - 1) {
      setState(() {
        _questions = _buildQuestions();
        _index = 0;
        _score = 0;
        _chosen = null;
      });
      return;
    }

    setState(() {
      _index++;
      _chosen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('hifz_quiz'))),
        body: Center(child: Text(context.tr('hifz_empty'))),
      );
    }

    final question = _questions[_index];

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('hifz_quiz'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Text(
                '${_index + 1}/${_questions.length}',
                style: AppTextStyles.caption(context),
              ),
              const Spacer(),
              Text(
                '${context.tr('quiz_score')}: $_score',
                style: AppTextStyles.caption(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Text(
                  context.tr('quiz_prompt'),
                  style: AppTextStyles.caption(context),
                ),
                const SizedBox(height: 10),
                Text(
                  question.prompt.text,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.quran(context, fontSize: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < question.options.length; i++)
            _option(context, question, i),
          const SizedBox(height: 18),
          if (_chosen != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  _index >= _questions.length - 1
                      ? context.tr('quiz_restart')
                      : context.tr('quiz_next'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, _Question question, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final option = question.options[index];
    final isAnswer = option.key == question.answer.key;
    final isChosen = _chosen == index;

    Color? background;
    if (_chosen != null) {
      if (isAnswer) {
        background = colorScheme.primary.withValues(alpha: 0.16);
      } else if (isChosen) {
        background = colorScheme.error.withValues(alpha: 0.14);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: background ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _chosen != null && isAnswer
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _choose(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              option.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.quran(context, fontSize: 19),
            ),
          ),
        ),
      ),
    );
  }
}

class _Question {
  const _Question({
    required this.prompt,
    required this.answer,
    required this.options,
  });

  final QuranVerse prompt;
  final QuranVerse answer;
  final List<QuranVerse> options;
}
