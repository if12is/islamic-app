import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/quran_local_service.dart';
import '../../domain/entities/hifz_item.dart';
import '../providers/hifz_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/hifz_verse_view.dart';
import 'recitation_page.dart';

/// Works through the passages due today, one at a time.
///
/// The text starts hidden; you recall it, reveal what you missed, then grade
/// yourself. The grade decides when the passage comes back.
class HifzReviewPage extends ConsumerStatefulWidget {
  const HifzReviewPage({super.key, required this.items});

  final List<HifzItem> items;

  @override
  ConsumerState<HifzReviewPage> createState() => _HifzReviewPageState();
}

class _HifzReviewPageState extends ConsumerState<HifzReviewPage> {
  int _index = 0;
  HifzMask _mask = HifzMask.firstLetters;

  HifzItem get _current => widget.items[_index];

  bool get _isLast => _index >= widget.items.length - 1;

  List<QuranVerse> get _verses => [
    for (var ayah = _current.fromAyah; ayah <= _current.toAyah; ayah++)
      QuranLocalService.verse(_current.surahNumber, ayah),
  ];

  Future<void> _grade(HifzGrade grade) async {
    await ref.read(hifzProvider.notifier).grade(_current, grade);

    if (!mounted) {
      return;
    }
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _mask = HifzMask.firstLetters;
    });
  }

  Future<void> _listen() async {
    final settings = ref.read(readerSettingsProvider);
    await ref
        .read(quranAudioProvider.notifier)
        .playRange(
          _verses,
          fromIndex: 0,
          toIndex: _verses.length - 1,
          repeatCount: 3,
          reciterCode: QuranReciter.verseAudioCode(settings.reciterCode),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = QuranLocalService.surahInfo(_current.surahNumber);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        '${context.tr('hifz_review')} ${_index + 1}/${widget.items.length}',
        style: AppTextStyles.display(context, fontSize: 17),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('listen'),
          icon: const Icon(Icons.headphones),
          onPressed: _listen,
        ),
        IconButton(
          tooltip: context.tr('recite_title'),
          icon: const Icon(Icons.mic_none),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => RecitationPage(
                        surahNumber: _current.surahNumber,
                        fromAyah: _current.fromAyah,
                        toAyah: _current.toAyah,
                      ),
                ),
              ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '${context.tr('surah_word')} ${surah.nameAr} · '
            '${_current.fromAyah}-${_current.toAyah}',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(context, fontSize: 18),
          ),
          const SizedBox(height: 16),
          SegmentedButton<HifzMask>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: HifzMask.hidden,
                label: Text(context.tr('hifz_mask_hidden')),
              ),
              ButtonSegment(
                value: HifzMask.firstLetters,
                label: Text(context.tr('hifz_mask_letters')),
              ),
              ButtonSegment(
                value: HifzMask.none,
                label: Text(context.tr('hifz_mask_none')),
              ),
            ],
            selected: {_mask},
            onSelectionChanged: (value) => setState(() => _mask = value.first),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('hifz_tap_word'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: HifzVerseView(verses: _verses, mask: _mask),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('hifz_how_was_it'),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _gradeButton(
                  context,
                  grade: HifzGrade.again,
                  labelKey: 'hifz_grade_again',
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _gradeButton(
                  context,
                  grade: HifzGrade.good,
                  labelKey: 'hifz_grade_good',
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _gradeButton(
                  context,
                  grade: HifzGrade.easy,
                  labelKey: 'hifz_grade_easy',
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _nextIntervalHint(context),
              style: AppTextStyles.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeButton(
    BuildContext context, {
    required HifzGrade grade,
    required String labelKey,
    required Color color,
  }) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => _grade(grade),
      child: Text(context.tr(labelKey)),
    );
  }

  /// Shows what each grade will do, so the choice is not a guess.
  String _nextIntervalHint(BuildContext context) {
    final again = _current.review(HifzGrade.again).dueDate;
    final good = _current.review(HifzGrade.good).dueDate;
    final easy = _current.review(HifzGrade.easy).dueDate;
    final now = DateTime.now();

    int days(DateTime date) =>
        DateTime(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;

    return '${context.tr('hifz_grade_again')} ${days(again)} · '
        '${context.tr('hifz_grade_good')} ${days(good)} · '
        '${context.tr('hifz_grade_easy')} ${days(easy)} '
        '${context.tr('days_read')}';
  }
}
