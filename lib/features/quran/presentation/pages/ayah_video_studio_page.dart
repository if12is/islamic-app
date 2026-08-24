import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/ayah_video_exporter.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/video_export_result.dart';
import '../../domain/ayah_video_spec.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/ayah_video_frame.dart';

/// Compose a passage into a video or a card, then share it.
///
/// Everything is one composition seen at two sizes: the preview is the export
/// frame scaled down, so nothing can look right here and wrong in the file.
class AyahVideoStudioPage extends ConsumerStatefulWidget {
  const AyahVideoStudioPage({
    super.key,
    required this.surahNumber,
    required this.fromVerse,
    this.toVerse,
  });

  final int surahNumber;
  final int fromVerse;
  final int? toVerse;

  static Future<void> open(
    BuildContext context, {
    required int surahNumber,
    required int fromVerse,
    int? toVerse,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => AyahVideoStudioPage(
              surahNumber: surahNumber,
              fromVerse: fromVerse,
              toVerse: toVerse,
            ),
      ),
    );
  }

  @override
  ConsumerState<AyahVideoStudioPage> createState() =>
      _AyahVideoStudioPageState();
}

class _AyahVideoStudioPageState extends ConsumerState<AyahVideoStudioPage> {
  late AyahVideoSpec _spec;
  final ScreenshotController _shot = ScreenshotController();

  /// Cycles the lit verse in the preview so the effect is visible standing
  /// still. It paces itself, unlike the export, which follows the recitation.
  Timer? _previewTimer;
  int _previewIndex = 0;
  bool _previewRunning = false;

  VideoExportProgress? _progress;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    final verseCount =
        QuranLocalService.surahInfo(widget.surahNumber).versesCount;
    final from = widget.fromVerse.clamp(1, verseCount);
    final to = (widget.toVerse ?? widget.fromVerse + 2).clamp(from, verseCount);

    final settings = ref.read(readerSettingsProvider);
    _spec = AyahVideoSpec(
      surahNumber: widget.surahNumber,
      fromVerse: from,
      // Never open on a passage the studio would immediately refuse.
      toVerse: to.clamp(from, from + AyahVideoSpec.maxVerses - 1),
      // Only the verse-by-verse editions can be cut at the ayah; a whole-surah
      // recording has no seam, so the studio stays on the seven that do.
      reciterCode: QuranReciter.verseAudioCode(settings.reciterCode),
      fontFamily: settings.font.family,
    );
    _spec = _spec.copyWith(
      fontSize: AyahVideoSpec.suggestedFontSize(
        _verses.map((verse) => verse.text),
        aspect: _spec.aspect,
      ),
    );
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  List<QuranVerse> get _verses => [
    for (final number in _spec.verseNumbers)
      QuranLocalService.verse(_spec.surahNumber, number),
  ];

  int get _surahVerseCount =>
      QuranLocalService.surahInfo(_spec.surahNumber).versesCount;

  void _update(AyahVideoSpec next) {
    setState(() {
      _spec = next;
      _previewIndex = 0;
    });
  }

  // ---------------------------------------------------------------- preview

  void _togglePreview() {
    if (_previewRunning) {
      _previewTimer?.cancel();
      setState(() {
        _previewRunning = false;
        _previewIndex = 0;
      });
      return;
    }

    setState(() => _previewRunning = true);
    _previewTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewIndex = (_previewIndex + 1) % _spec.verseCount;
      });
    });
  }

  // ----------------------------------------------------------------- export

  Future<Uint8List> _renderFrame(int? activeVerse) {
    return _shot.captureFromWidget(
      AyahVideoFrame(spec: _spec, verses: _verses, activeVerse: activeVerse),
      targetSize: Size(
        _spec.aspect.width.toDouble(),
        _spec.aspect.height.toDouble(),
      ),
      pixelRatio: 1,
      delay: const Duration(milliseconds: 120),
    );
  }

  Future<void> _exportVideo() async {
    if (_busy) {
      return;
    }
    if (!AyahVideoExporter.isSupported) {
      _toast(context.tr('video_export_unsupported'));
      return;
    }

    setState(() {
      _busy = true;
      _progress = const VideoExportProgress(VideoExportStage.preparing);
    });
    _previewTimer?.cancel();

    final stem = _spec.fileStem(
      _slug(QuranLocalService.surahInfo(_spec.surahNumber).nameEn),
    );

    final result = await AyahVideoExporter.export(
      spec: _spec,
      verseTexts: {
        for (final verse in _verses) verse.numberInSurah: verse.text,
      },
      renderFrame: _renderFrame,
      fileStem: stem,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _progress = null;
      _previewRunning = false;
    });

    if (!result.ok) {
      _showFailure(result);
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(result.filePath!, mimeType: 'video/mp4')]),
      );
    } catch (e, stack) {
      AppLogger.error('Sharing the video failed', e, stack);
      if (mounted) {
        _toast(context.tr('share_failed'));
      }
    }
  }

  Future<void> _exportImage() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _renderFrame(null);
      final name =
          '${_spec.fileStem(_slug(QuranLocalService.surahInfo(_spec.surahNumber).nameEn))}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: [name],
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Sharing the card failed', e, stack);
      if (mounted) {
        _toast(context.tr('share_failed'));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showFailure(VideoExportResult result) {
    final message = context.tr(result.failureKey ?? 'video_export_failed');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action:
              result.detail == null
                  ? null
                  : SnackBarAction(
                    label: context.tr('details'),
                    onPressed: () => _showDetail(message, result.detail!),
                  ),
        ),
      );
  }

  void _showDetail(String title, String detail) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: SelectableText(
                detail,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.tr('close')),
              ),
            ],
          ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  // -------------------------------------------------------------------- ui

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final verses = _verses;
    final active =
        _previewRunning && verses.isNotEmpty
            ? verses[_previewIndex.clamp(0, verses.length - 1)].numberInSurah
            : null;

    return AppScaffold(
      title: 'video_studio',
      showBack: true,
      actions: [
        IconButton(
          tooltip: context.tr('video_aspect'),
          onPressed: _busy ? null : _pickAspect,
          icon: Icon(_aspectIcon(_spec.aspect), color: tokens.ink, size: 20),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.sm,
              ),
              child: Center(
                child: _Preview(
                  frame: AyahVideoFrame(
                    spec: _spec,
                    verses: verses,
                    activeVerse: active,
                  ),
                  aspect: _spec.aspect,
                ),
              ),
            ),
          ),
          _previewNote(tokens),
          _controlBar(tokens),
        ],
      ),
    );
  }

  Widget _previewNote(AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: context.tr(_previewRunning ? 'pause' : 'video_preview'),
            onPressed: _busy ? null : _togglePreview,
            icon: Icon(
              _previewRunning
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              color: tokens.brand,
            ),
          ),
          Flexible(
            child: Text(
              context.tr('video_preview_note'),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBar(AppTokens tokens) {
    final progress = _progress;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  tokens,
                  icon: Icons.grid_on_rounded,
                  label: context.tr('video_pattern_${_spec.pattern.name}'),
                  onTap: _pickPattern,
                ),
                _chip(
                  tokens,
                  icon: Icons.format_list_numbered,
                  label: _rangeLabel(),
                  onTap: _pickRange,
                ),
                _chip(
                  tokens,
                  icon: Icons.format_size,
                  label: _spec.fontSize.round().toString(),
                  onTap: _pickTypography,
                ),
                _chip(
                  tokens,
                  icon: Icons.palette_outlined,
                  label: context.tr('video_palette_${_spec.palette.name}'),
                  swatch: VideoFrameTheme.of(_spec.palette).accent,
                  onTap: _pickPalette,
                ),
                _chip(
                  tokens,
                  icon: Icons.record_voice_over_outlined,
                  label: QuranReciter.byCode(_spec.reciterCode).nameAr,
                  onTap: _pickReciter,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (progress != null) ...[
            _progressRow(tokens, progress),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _exportVideo,
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: Text(context.tr('video_create')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _exportImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(context.tr('video_as_image')),
                ),
              ),
              if (_busy) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: context.tr('cancel'),
                  onPressed: AyahVideoExporter.cancel,
                  icon: Icon(Icons.stop_circle_outlined, color: tokens.danger),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressRow(AppTokens tokens, VideoExportProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(progress.labelKey),
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(context, color: tokens.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadii.pillAll,
          child: LinearProgressIndicator(
            value: progress.isIndeterminate ? null : progress.fraction,
            minHeight: 5,
            backgroundColor: tokens.groundAlt,
            valueColor: AlwaysStoppedAnimation(tokens.gold),
          ),
        ),
      ],
    );
  }

  Widget _chip(
    AppTokens tokens, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? swatch,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: tokens.groundAlt,
        borderRadius: AppRadii.pillAll,
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: AppRadii.pillAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatch,
                    ),
                  )
                else
                  Icon(icon, size: 16, color: tokens.inkMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.caption(context, color: tokens.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rangeLabel() =>
      _spec.fromVerse == _spec.toVerse
          ? '${_spec.fromVerse}'
          : '${_spec.fromVerse}–${_spec.toVerse}';

  /// The reading fonts are already named for the settings sheet; reusing those
  /// keys keeps one face from being called two different things in one app.
  static String _fontLabelKey(ReaderFont font) => switch (font) {
    ReaderFont.amiriQuran => 'font_amiri',
    ReaderFont.scheherazade => 'font_scheherazade',
    ReaderFont.cairo => 'font_cairo',
  };

  static IconData _aspectIcon(VideoAspect aspect) => switch (aspect) {
    VideoAspect.square => Icons.crop_square,
    VideoAspect.portrait => Icons.crop_portrait,
    VideoAspect.landscape => Icons.crop_landscape,
  };

  // ------------------------------------------------------------- the sheets

  Future<void> _pickPattern() async {
    final chosen = await _choose<VideoPattern>(
      titleKey: 'video_pattern',
      options: [
        for (final pattern in VideoPattern.values)
          (pattern, context.tr('video_pattern_${pattern.name}')),
      ],
      selected: _spec.pattern,
    );
    if (chosen != null) {
      _update(_spec.copyWith(pattern: chosen));
    }
  }

  Future<void> _pickPalette() async {
    final chosen = await _choose<VideoPalette>(
      titleKey: 'video_palette',
      options: [
        for (final palette in VideoPalette.values)
          (palette, context.tr('video_palette_${palette.name}')),
      ],
      selected: _spec.palette,
      swatch: (palette) => VideoFrameTheme.of(palette).accent,
    );
    if (chosen != null) {
      _update(_spec.copyWith(palette: chosen));
    }
  }

  Future<void> _pickAspect() async {
    final chosen = await _choose<VideoAspect>(
      titleKey: 'video_aspect',
      options: [
        for (final aspect in VideoAspect.values)
          (
            aspect,
            '${context.tr('video_aspect_${aspect.name}')} · '
                '${aspect.width}×${aspect.height}',
          ),
      ],
      selected: _spec.aspect,
    );
    if (chosen != null) {
      _update(
        _spec.copyWith(
          aspect: chosen,
          fontSize: AyahVideoSpec.suggestedFontSize(
            _verses.map((verse) => verse.text),
            aspect: chosen,
          ),
        ),
      );
    }
  }

  Future<void> _pickReciter() async {
    final chosen = await _choose<String>(
      titleKey: 'reciter',
      options: [
        for (final reciter in QuranReciter.all) (reciter.code, reciter.nameAr),
      ],
      selected: _spec.reciterCode,
    );
    if (chosen != null) {
      _update(_spec.copyWith(reciterCode: chosen));
    }
  }

  Future<void> _pickTypography() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Directionality(
                textDirection: sheetContext.appTextDirection,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheetContext.tr('video_typography'),
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final font in ReaderFont.values)
                              ChoiceChip(
                                selected: _spec.fontFamily == font.family,
                                onSelected: (_) {
                                  _update(
                                    _spec.copyWith(fontFamily: font.family),
                                  );
                                  setSheetState(() {});
                                },
                                label: Text(
                                  sheetContext.tr(_fontLabelKey(font)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(child: Text(sheetContext.tr('font_size'))),
                            Text('${_spec.fontSize.round()}'),
                          ],
                        ),
                        Slider(
                          value: _spec.fontSize,
                          min: AyahVideoSpec.minFontSize,
                          max: AyahVideoSpec.maxFontSize,
                          onChanged: (value) {
                            _update(_spec.copyWith(fontSize: value));
                            setSheetState(() {});
                          },
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _update(
                              _spec.copyWith(
                                fontSize: AyahVideoSpec.suggestedFontSize(
                                  _verses.map((verse) => verse.text),
                                  aspect: _spec.aspect,
                                ),
                              ),
                            );
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: Text(sheetContext.tr('video_font_auto')),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<void> _pickRange() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final last = _surahVerseCount.toDouble();
              return Directionality(
                textDirection: sheetContext.appTextDirection,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheetContext.tr('video_range'),
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppLocalizations.translate(
                            Localizations.localeOf(sheetContext).languageCode,
                            'video_range_limit',
                            replacements: {'max': '${AyahVideoSpec.maxVerses}'},
                          ),
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        RangeSlider(
                          values: RangeValues(
                            _spec.fromVerse.toDouble(),
                            _spec.toVerse.toDouble().clamp(
                              _spec.fromVerse.toDouble(),
                              last,
                            ),
                          ),
                          min: 1,
                          max: last,
                          divisions:
                              _surahVerseCount > 1 ? _surahVerseCount - 1 : 1,
                          labels: RangeLabels(
                            '${_spec.fromVerse}',
                            '${_spec.toVerse}',
                          ),
                          onChanged: (values) {
                            final from = values.start.round();
                            // Clamping here rather than refusing later means
                            // the slider simply will not go past the limit.
                            final to = values.end.round().clamp(
                              from,
                              from + AyahVideoSpec.maxVerses - 1,
                            );
                            _update(
                              _spec.copyWith(fromVerse: from, toVerse: to),
                            );
                            setSheetState(() {});
                          },
                        ),
                        Center(
                          child: Text(
                            '${sheetContext.tr('ayah_word')} '
                            '${_spec.fromVerse} – ${_spec.toVerse}',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  /// One list sheet for every "pick one of these" control on this screen.
  Future<T?> _choose<T>({
    required String titleKey,
    required List<(T, String)> options,
    required T selected,
    Color Function(T value)? swatch,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Directionality(
            textDirection: sheetContext.appTextDirection,
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      sheetContext.tr(titleKey),
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                  ),
                  for (final (value, label) in options)
                    ListTile(
                      leading:
                          swatch == null
                              ? null
                              : Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: swatch(value),
                                ),
                              ),
                      title: Text(label),
                      trailing:
                          value == selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                      onTap: () => Navigator.of(sheetContext).pop(value),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}

/// The export frame, shrunk to whatever room the screen has.
class _Preview extends StatelessWidget {
  const _Preview({required this.frame, required this.aspect});

  final Widget frame;
  final VideoAspect aspect;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect.ratio,
      child: ClipRRect(
        borderRadius: AppRadii.mdAll,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: aspect.width.toDouble(),
            height: aspect.height.toDouble(),
            child: frame,
          ),
        ),
      ),
    );
  }
}
