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
import '../../data/services/audio_download_service.dart';
import '../../data/services/tilawa_engine.dart';
import '../../data/services/tilawa_store.dart';
import '../../domain/entities/passage_progress.dart';
import '../../domain/entities/tilawa_event.dart';
import 'surah_reader_page.dart';

enum _Phase {
  checking,
  needsDownload,
  downloading,
  loading,
  ready,
  listening,
  failed,
}

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

  _Phase _phase = _Phase.checking;
  double _loadFraction = 0;
  double _downloadFraction = 0;
  StreamSubscription<TilawaDownloadProgress>? _download;
  String? _errorKey;

  /// The engine's own words for what went wrong, shown small under the
  /// message so a failure on a phone can be reported precisely.
  String? _errorDetail;
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
    unawaited(_prepare());
  }

  /// Load the listener if everything is already on the phone; otherwise ask
  /// before downloading it.
  Future<void> _prepare() async {
    final tier = await TilawaStore.installedTier();
    if (!mounted) {
      return;
    }
    if (tier != null) {
      setState(() => _phase = _Phase.loading);
      await _engine?.load(tier);
    } else {
      setState(() => _phase = _Phase.needsDownload);
    }
  }

  /// Fetch every file the listener needs, once.
  void _startDownload(TilawaTier tier) {
    setState(() {
      _phase = _Phase.downloading;
      _downloadFraction = 0;
      _errorKey = null;
    });
    _download = TilawaStore.download(tier).listen((progress) {
      if (!mounted) {
        return;
      }
      switch (progress.state) {
        case TilawaDownloadState.downloading:
          setState(() => _downloadFraction = progress.ratio);
        case TilawaDownloadState.installed:
          unawaited(_prepare());
        case TilawaDownloadState.failed:
          setState(() {
            _phase = _Phase.needsDownload;
            _errorKey = 'recite_download_failed';
          });
        case TilawaDownloadState.cancelled:
          setState(() => _phase = _Phase.needsDownload);
      }
    });
  }

  @override
  void dispose() {
    if (_phase == _Phase.downloading) {
      TilawaStore.cancel();
    }
    unawaited(_download?.cancel());
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
    _errorDetail = '${failure.stage} · ${failure.name}: ${failure.message}';
    final denied =
        failure.name == 'MicrophoneError' &&
        failure.message.toLowerCase().contains('denied');
    _errorKey = switch (failure.stage) {
      'load' => 'recite_failed',
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
    _errorDetail = null;
  }

  Future<void> _retryLoad() async {
    setState(() {
      _phase = _Phase.checking;
      _errorKey = null;
      _loadFraction = 0;
    });
    await _prepare();
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
              if (_phase == _Phase.needsDownload ||
                  _phase == _Phase.downloading)
                _downloadCard(context),
              if (_phase == _Phase.loading) _loading(context),
              if (_errorKey != null) _error(context, colorScheme),
              if (_phase == _Phase.ready || _phase == _Phase.listening) ...[
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
        ],
      ),
    );
  }

  /// The one-time download of everything the listener needs.
  Widget _downloadCard(BuildContext context) {
    String size(TilawaTier tier) =>
        AudioDownloadService.formatBytes(TilawaStore.totalBytesFor(tier));
    final downloading = _phase == _Phase.downloading;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('recite_download_title'),
              style: AppTextStyles.display(context, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('recite_download_desc'),
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: AppSpacing.md),
            if (downloading) ...[
              LinearProgressIndicator(
                value: _downloadFraction > 0 ? _downloadFraction : null,
                minHeight: 6,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(_downloadFraction * 100).round()}%',
                      style: AppTextStyles.caption(context),
                    ),
                  ),
                  TextButton(
                    onPressed: TilawaStore.cancel,
                    child: Text(context.tr('recite_download_cancel')),
                  ),
                ],
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () => _startDownload(TilawaTier.full),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  context
                      .tr('recite_download_full')
                      .replaceAll('{size}', size(TilawaTier.full)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _startDownload(TilawaTier.lite),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  context
                      .tr('recite_download_lite')
                      .replaceAll('{size}', size(TilawaTier.lite)),
                ),
              ),
            ],
          ],
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(_errorKey!),
                  style: AppTextStyles.caption(
                    context,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                if (_errorDetail != null)
                  SelectableText(
                    _errorDetail!,
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.caption(
                      context,
                      fontSize: 10,
                      color: colorScheme.onErrorContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
              ],
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
    final reached = _progress.heardCount;
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
                color: switch (_progress.statusAt(i)) {
                  WordStatus.pending ||
                  WordStatus.tentative => colorScheme.onSurfaceVariant,
                  _ => colorScheme.onSurface,
                },
              ),
            ),
          ),
      ],
    );
  }

  Color _colourFor(WordStatus status, ColorScheme colorScheme) =>
      switch (status) {
        WordStatus.pending => Colors.transparent,
        // Heard, but the engine has not moved on enough to be sure.
        WordStatus.tentative => colorScheme.primary.withValues(alpha: 0.08),
        WordStatus.recited => colorScheme.primary.withValues(alpha: 0.22),
        WordStatus.unverified => colorScheme.secondary.withValues(alpha: 0.22),
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
        item(
          colorScheme.secondary.withValues(alpha: 0.45),
          'recite_legend_unverified',
        ),
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
