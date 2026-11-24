import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/tilawa_engine.dart';
import '../../domain/entities/passage_progress.dart';
import '../../domain/entities/tilawa_event.dart';
import 'surah_reader_page.dart';

enum _Phase { loading, ready, listening, failed }

/// Recite out loud and watch the Mushaf follow you, word by word.
///
/// Listening is done by [TilawaEngine]: entirely on the phone, no audio leaves
/// it. Two ways in:
///
///  * a known passage — each word lights up as it is recited and slips
///    (a wrong, missed or extra word, a skipped verse) are marked live;
///  * free recitation (the search field's door) — recite anything and the page
///    names the verse you are at.
class RecitationPage extends ConsumerStatefulWidget {
  const RecitationPage({
    super.key,
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
  }) : startInIdentifyMode = false;

  /// Open straight into "which verse is this?", with no passage in mind.
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
  TilawaEngine? _engine;
  StreamSubscription<TilawaEvent>? _sub;

  _Phase _phase = _Phase.loading;
  double _loadFraction = 0;
  bool _downloading = false;
  String? _errorKey;
  double _levelDb = -90;

  bool _identify = false;
  late PassageProgress _progress;

  /// Free recitation: the verses heard, newest last.
  final List<(int, int)> _trail = [];
  List<TilawaMistake>? _finalMistakes;

  @override
  void initState() {
    super.initState();
    _identify = widget.startInIdentifyMode;
    _progress = _buildProgress();
    if (!TilawaEngine.isSupported) {
      _phase = _Phase.failed;
      _errorKey = 'recite_unavailable';
      return;
    }
    final engine = TilawaEngine();
    _engine = engine;
    _sub = engine.events.listen(_onEvent);
    unawaited(engine.load());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_engine?.dispose());
    super.dispose();
  }

  PassageProgress _buildProgress() => PassageProgress(
    surah: widget.surahNumber,
    words: {
      for (var ayah = widget.fromAyah; ayah <= widget.toAyah; ayah++)
        ayah: PassageProgress.splitWords(
          QuranLocalService.verse(widget.surahNumber, ayah).text,
        ),
    },
  );

  void _onEvent(TilawaEvent event) {
    if (!mounted) {
      return;
    }
    setState(() {
      switch (event) {
        case TilawaProgress():
          _loadFraction = event.fraction;
          _downloading = !event.fromCache;
        case TilawaReady():
          _phase = _Phase.ready;
        case TilawaListening():
          _phase = _Phase.listening;
        case TilawaLevel():
          _levelDb = event.db;
        case TilawaPosition():
          if (_identify) {
            final at = event.observed;
            if (at != null &&
                (_trail.isEmpty || _trail.last != (at.surah, at.ayah))) {
              _trail.add((at.surah, at.ayah));
            }
          } else {
            _progress.apply(event);
          }
        case TilawaChecker():
          if (!_identify) {
            _progress.apply(event);
          }
        case TilawaDone():
          _phase = _Phase.ready;
          _finalMistakes = event.mistakes;
        case TilawaFailure():
          _fail(event);
        case TilawaBooted():
          break;
      }
    });
  }

  void _fail(TilawaFailure failure) {
    final denied =
        failure.name == 'MicrophoneError' &&
        failure.message.toLowerCase().contains('denied');
    _errorKey = switch (failure.stage) {
      'load' =>
        failure.name == 'TilawaLoadError' || failure.name == 'BootError'
            ? 'recite_offline_first'
            : 'recite_failed',
      _ => denied ? 'recite_no_permission' : 'recite_failed',
    };
    // A failed load leaves nothing to listen with; anything else can be
    // retried straight away.
    _phase = failure.stage == 'load' ? _Phase.failed : _Phase.ready;
  }

  void _reset() {
    _progress = _buildProgress();
    _trail.clear();
    _finalMistakes = null;
    _errorKey = null;
  }

  Future<void> _retryLoad() async {
    setState(() {
      _phase = _Phase.loading;
      _errorKey = null;
      _loadFraction = 0;
    });
    await _engine?.load();
  }

  Future<void> _toggle() async {
    final engine = _engine;
    if (engine == null) {
      return;
    }
    if (_phase == _Phase.listening) {
      await engine.stop();
      return;
    }
    if (_phase != _Phase.ready) {
      return;
    }
    setState(_reset);
    final granted = await engine.start(
      surah: _identify ? null : widget.surahNumber,
      fromAyah: widget.fromAyah,
      toAyah: widget.toAyah,
    );
    if (!granted && mounted) {
      setState(() => _errorKey = 'recite_no_permission');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surah = QuranLocalService.surahInfo(widget.surahNumber);
    final listening = _phase == _Phase.listening;

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('recite_title'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          _phase == _Phase.ready || listening
              ? FloatingActionButton.extended(
                onPressed: _toggle,
                backgroundColor:
                    listening ? colorScheme.error : colorScheme.primary,
                icon: Icon(listening ? Icons.stop : Icons.mic),
                label: Text(
                  listening
                      ? context.tr('recite_stop')
                      : context.tr('recite_start'),
                ),
              )
              : null,
      body: Stack(
        children: [
          // The engine's WebView has to be alive to listen; it draws nothing.
          if (_engine != null)
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: IgnorePointer(child: _engine!.view),
            ),
          ListView(
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
              const SizedBox(height: 2),
              Text(
                context.tr('recite_privacy'),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(context),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!widget.startInIdentifyMode)
                Center(
                  child: PillSelector<bool>(
                    compact: true,
                    scrollable: false,
                    value: _identify,
                    onChanged:
                        (value) => setState(() {
                          if (_phase == _Phase.listening) {
                            return;
                          }
                          _identify = value;
                          _reset();
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
              if (_phase == _Phase.loading) _loading(context),
              if (_errorKey != null) _error(context, colorScheme),
              if (_phase != _Phase.loading && _phase != _Phase.failed) ...[
                if (listening) _listeningBar(context),
                if (_identify)
                  _identifyResults(context)
                else ...[
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
                  if (_finalMistakes != null) _mistakeList(context),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            context.tr('recite_loading'),
            style: AppTextStyles.display(context, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: _loadFraction > 0 ? _loadFraction : null,
            minHeight: 6,
          ),
          if (_downloading) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('recite_first_download'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listeningBar(BuildContext context) {
    final tokens = context.tokens;
    // -60 dBFS is near silence, -10 is loud speech.
    final level = ((_levelDb + 60) / 50).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 18, color: tokens.brand),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.tr('recite_listening'),
            style: AppTextStyles.caption(context, color: tokens.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: level, minHeight: 4),
            ),
          ),
        ],
      ),
    );
  }

  /// Which verse the reciter is at, and the ones before it.
  Widget _identifyResults(BuildContext context) {
    final tokens = context.tokens;

    if (_trail.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(
              _phase == _Phase.listening ? Icons.graphic_eq : Icons.search,
              size: 28,
              color: tokens.inkFaint,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _phase == _Phase.listening
                  ? context.tr('recite_finding')
                  : context.tr('recite_identify_hint'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context),
            ),
          ],
        ),
      );
    }

    final newestFirst = _trail.reversed.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < newestFirst.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _verseCard(
              context,
              surahNumber: newestFirst[i].$1,
              ayah: newestFirst[i].$2,
              current: i == 0,
            ),
          ),
      ],
    );
  }

  Widget _verseCard(
    BuildContext context, {
    required int surahNumber,
    required int ayah,
    required bool current,
  }) {
    final tokens = context.tokens;
    final verse = QuranLocalService.verse(surahNumber, ayah);
    return AppCard(
      // Tapping opens the reader exactly there.
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => SurahReaderPage(
                    surahNumber: surahNumber,
                    initialVerse: ayah,
                  ),
            ),
          ),
      child: Opacity(
        opacity: current ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${QuranLocalService.surahInfo(surahNumber).nameAr}'
                    ' · $ayah',
                    style: AppTextStyles.display(context, fontSize: 15),
                  ),
                ),
                if (current)
                  Text(
                    context.tr('recite_position'),
                    style: AppTextStyles.caption(
                      context,
                      fontSize: 11,
                      color: tokens.brand,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              verse.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.quran(context, fontSize: 20),
            ),
          ],
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
          if (_phase == _Phase.failed && _engine != null)
            TextButton(
              onPressed: _retryLoad,
              child: Text(context.tr('recite_retry')),
            ),
        ],
      ),
    );
  }

  Widget _scoreBar(BuildContext context, ColorScheme colorScheme) {
    final total = _progress.length;
    final reached = _progress.reached;
    final value = total == 0 ? 0.0 : reached / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr('recite_progress')}: $reached/$total',
          style: AppTextStyles.caption(context),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
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
        for (var i = 0; i < _progress.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _colourFor(_progress.statusAt(i), colorScheme),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _progress.textAt(i),
              textDirection: TextDirection.rtl,
              style: AppTextStyles.quran(
                context,
                fontSize: 22,
                color:
                    _progress.statusAt(i) == WordStatus.pending
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  Color _colourFor(WordStatus status, ColorScheme colorScheme) =>
      switch (status) {
        WordStatus.pending => Colors.transparent,
        WordStatus.recited => colorScheme.primary.withValues(alpha: 0.22),
        WordStatus.wrong => colorScheme.error.withValues(alpha: 0.24),
      };

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
        item(colorScheme.error.withValues(alpha: 0.45), 'recite_legend_wrong'),
      ],
    );
  }

  /// The slips the engine confirmed, once the session has ended.
  Widget _mistakeList(BuildContext context) {
    final mistakes = _finalMistakes!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              mistakes.isEmpty
                  ? context.tr('recite_no_mistakes')
                  : context.tr('recite_mistakes'),
              style: AppTextStyles.display(context, fontSize: 15),
            ),
            for (final m in mistakes)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '${context.tr(switch (m.kind) {
                    MistakeKind.wrongWord => 'recite_err_wrong_word',
                    MistakeKind.omittedWord => 'recite_err_omitted_word',
                    MistakeKind.addedWord => 'recite_err_added_word',
                    MistakeKind.skippedPassage => 'recite_err_skipped_passage',
                  })} · ${m.location.ayah}:${m.location.word}',
                  style: AppTextStyles.caption(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
