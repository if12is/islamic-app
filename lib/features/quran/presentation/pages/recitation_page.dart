import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/recitation_service.dart';
import '../../data/services/stt_model_catalogue.dart';
import '../../domain/entities/recitation_match.dart';
import 'surah_reader_page.dart';
import '../../domain/entities/verse_match.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/theme/design_tokens.dart';
import '../widgets/recitation_locale_sheet.dart';

/// Recite out loud and see, word by word, what came out.
///
/// Green means it matched, amber means it was close enough to be the
/// recogniser's spelling rather than a mistake, red means it was skipped or
/// something else was said. It is a mirror, not a judge — the screen says so.
class RecitationPage extends ConsumerStatefulWidget {
  const RecitationPage({
    super.key,
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
  }) : startInIdentifyMode = false;

  /// Open straight into "which verse is this?", with no passage in mind.
  ///
  /// This is the door from the search field: someone who half-remembers a
  /// verse has nothing to check themselves against, so asking them to pick a
  /// surah first would defeat the point.
  const RecitationPage.identify({super.key})
    : surahNumber = 1,
      fromAyah = 1,
      toAyah = 1,
      startInIdentifyMode = true;

  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final bool startInIdentifyMode;

  @override
  ConsumerState<RecitationPage> createState() => _RecitationPageState();
}

class _RecitationPageState extends ConsumerState<RecitationPage> {
  final RecitationService _service = RecitationService();

  RecitationResult _result = RecitationResult.empty;
  String _heard = '';
  bool _listening = false;
  String? _errorKey;

  /// Identify mode: recite anything and be told where it is in the Mushaf.
  bool _identify = false;
  List<VerseMatch> _matches = const [];

  /// The downloaded model that will listen, if the user chose one.
  SttModel? _offlineModel;

  List<QuranVerse> get _verses => [
    for (var ayah = widget.fromAyah; ayah <= widget.toAyah; ayah++)
      QuranLocalService.verse(widget.surahNumber, ayah),
  ];

  String get _expected => _verses.map((verse) => verse.text).join(' ');

  @override
  void initState() {
    super.initState();
    _identify = widget.startInIdentifyMode;
    _result = RecitationMatcher.compare(expected: _expected, heard: '');
    _loadEngine();
  }

  @override
  void dispose() {
    _service.cancel();
    _service.dispose();
    super.dispose();
  }

  /// Find out which engine will listen, so the screen can say so up front
  /// instead of leaving the user to guess after a download.
  Future<void> _loadEngine() async {
    final model = await RecitationService.preferredOfflineModel();
    if (mounted) {
      setState(() => _offlineModel = model);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _service.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() {
      _errorKey = null;
      _heard = '';
      _matches = const [];
      _result = RecitationMatcher.compare(expected: _expected, heard: '');
    });

    final failure = await _service.start(
      onResult: (text, isFinal) {
        if (!mounted) {
          return;
        }
        setState(() {
          _heard = text;
          if (_identify) {
            // Search on every partial: the answer usually arrives long before
            // the reciter stops, and waiting to show it helps nobody.
            _matches = VerseFinder.search(text);
          } else {
            _result = RecitationMatcher.compare(
              expected: _expected,
              heard: text,
            );
          }
          if (isFinal) {
            _listening = false;
          }
        });
      },
    );

    if (!mounted) {
      return;
    }

    if (failure != null) {
      setState(() {
        _listening = false;
        _errorKey = switch (failure) {
          RecitationFailure.permissionDenied => 'recite_no_permission',
          RecitationFailure.noArabicLocale => 'recite_no_arabic',
          RecitationFailure.unavailable => 'recite_unavailable',
          RecitationFailure.error => 'recite_failed',
        };
      });
      return;
    }

    setState(() => _listening = true);
  }

  /// Pick, switch, or download a voice pack.
  Future<void> _openLocalePicker() async {
    await _service.stop();
    if (!mounted) {
      return;
    }
    setState(() => _listening = false);

    final changed = await RecitationLocaleSheet.show(context, _service);
    if (changed == true && mounted) {
      // The choice moved; the engine resolved last time no longer applies.
      _service.invalidateLocale();
      setState(() => _errorKey = null);
      await _loadEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = QuranLocalService.surahInfo(widget.surahNumber);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('recite_title'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('recite_voice_pack'),
          icon: const Icon(Icons.record_voice_over_outlined, size: 20),
          onPressed: _openLocalePicker,
        ),
      ],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleListening,
        backgroundColor: _listening ? colorScheme.error : colorScheme.primary,
        icon: Icon(_listening ? Icons.stop : Icons.mic),
        label: Text(
          _listening ? context.tr('recite_stop') : context.tr('recite_start'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (!widget.startInIdentifyMode)
            Text(
              '${context.tr('surah_word')} ${surah.nameAr} · '
              '${widget.fromAyah}-${widget.toAyah}',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(context, fontSize: 17),
            ),
          const SizedBox(height: 6),
          Text(
            context.tr('recite_experimental'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: _engineChip(context)),
          const SizedBox(height: 16),
          if (!widget.startInIdentifyMode)
            Center(
              child: PillSelector<bool>(
                compact: true,
                scrollable: false,
                value: _identify,
                onChanged:
                    (value) => setState(() {
                      _identify = value;
                      _matches = const [];
                      _heard = '';
                    }),
                options: [
                  PillOption(
                    value: false,
                    label: context.tr('recite_mode_check'),
                  ),
                  PillOption(
                    value: true,
                    label: context.tr('recite_mode_identify'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_errorKey != null) _error(context, colorScheme),
          if (_identify) ...[
            _identifyResults(context),
          ] else ...[
            _scoreBar(context, colorScheme),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: _colouredText(context, colorScheme),
            ),
            const SizedBox(height: 16),
            _legend(context, colorScheme),
          ],
          if (_heard.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('recite_heard'),
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: 6),
            Text(_heard, style: AppTextStyles.body(context, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  /// What was recited, and where it sits in the Mushaf.
  Widget _identifyResults(BuildContext context) {
    final tokens = context.tokens;

    if (_matches.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(
              _listening ? Icons.graphic_eq : Icons.search,
              size: 28,
              color: tokens.inkFaint,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _heard.isEmpty
                  ? context.tr('recite_identify_hint')
                  : context.tr('recite_identify_none'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final match in _matches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              // Tapping opens the reader exactly there.
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => SurahReaderPage(
                            surahNumber: match.surahNumber,
                            initialVerse: match.verseNumber,
                          ),
                    ),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${QuranLocalService.surahInfo(match.surahNumber).nameAr}'
                          ' · ${match.verseNumber}',
                          style: AppTextStyles.display(context, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              match.isConfident
                                  ? tokens.brand.withValues(alpha: 0.16)
                                  : tokens.groundAlt,
                          borderRadius: AppRadii.pillAll,
                        ),
                        child: Text(
                          '${(match.score * 100).round()}%',
                          style: AppTextStyles.caption(
                            context,
                            fontSize: 11,
                            color:
                                match.isConfident
                                    ? tokens.brand
                                    : tokens.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    match.text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTextStyles.quran(context, fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Which engine is listening, stated before anyone presses the microphone.
  ///
  /// Someone who has just downloaded a model has no way to tell whether it is
  /// being used. This is that way: tap it to change the choice.
  Widget _engineChip(BuildContext context) {
    final tokens = context.tokens;
    final model = _offlineModel;
    final offline = model != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openLocalePicker,
        borderRadius: AppRadii.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color:
                offline
                    ? tokens.brand.withValues(alpha: 0.12)
                    : tokens.groundAlt,
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                offline ? Icons.offline_bolt_rounded : Icons.record_voice_over,
                size: 15,
                color: offline ? tokens.brand : tokens.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  offline
                      ? '${context.tr('recite_engine_offline')} · '
                          '${context.tr(model.nameKey)}'
                      : context.tr('recite_engine_device'),
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 11,
                    color: offline ? tokens.brand : tokens.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.tune_rounded, size: 13, color: tokens.inkFaint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_off, color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(_errorKey!),
              style: AppTextStyles.caption(
                context,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          // Naming the problem is not enough when the fix is two taps away.
          if (_errorKey == 'recite_no_arabic')
            TextButton(
              onPressed: _openLocalePicker,
              child: Text(context.tr('recite_download_pack')),
            ),
        ],
      ),
    );
  }

  Widget _scoreBar(BuildContext context, ColorScheme colorScheme) {
    final progress =
        _result.words.isEmpty ? 0.0 : _result.reached / _result.words.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${context.tr('recite_progress')}: '
                '${_result.reached}/${_result.words.length}',
                style: AppTextStyles.caption(context),
              ),
            ),
            Text(
              '${(_result.accuracy * 100).round()}%',
              style: AppTextStyles.display(
                context,
                fontSize: 18,
                color:
                    _result.accuracy > 0.8
                        ? colorScheme.primary
                        : colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _colouredText(BuildContext context, ColorScheme colorScheme) {
    return Wrap(
      alignment: WrapAlignment.center,
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final word in _result.words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _colourFor(word.status, colorScheme),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              word.text,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.quran(
                context,
                fontSize: 22,
                color:
                    word.status == RecitationWordStatus.pending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  Color _colourFor(RecitationWordStatus status, ColorScheme colorScheme) {
    switch (status) {
      case RecitationWordStatus.pending:
        return Colors.transparent;
      case RecitationWordStatus.correct:
        return colorScheme.primary.withValues(alpha: 0.22);
      case RecitationWordStatus.near:
        return colorScheme.secondary.withValues(alpha: 0.28);
      case RecitationWordStatus.wrong:
        return colorScheme.error.withValues(alpha: 0.24);
    }
  }

  Widget _legend(BuildContext context, ColorScheme colorScheme) {
    Widget item(Color color, String labelKey) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(context.tr(labelKey), style: AppTextStyles.caption(context)),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item(colorScheme.primary.withValues(alpha: 0.4), 'recite_legend_ok'),
        item(
          colorScheme.secondary.withValues(alpha: 0.5),
          'recite_legend_near',
        ),
        item(colorScheme.error.withValues(alpha: 0.45), 'recite_legend_wrong'),
      ],
    );
  }
}
