import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../domain/azkar_share_copy.dart';
import '../widgets/azkar_share_card.dart';

/// Pick a design, see the card, then share or save the PNG.
class AzkarSharePage extends StatefulWidget {
  const AzkarSharePage({super.key, required this.period});

  final AzkarSharePeriod period;

  @override
  State<AzkarSharePage> createState() => _AzkarSharePageState();
}

class _AzkarSharePageState extends State<AzkarSharePage> {
  final GlobalKey _boundaryKey = GlobalKey();
  AzkarShareDesign _design = AzkarShareDesign.mist;
  bool _busy = false;

  String get _fileName {
    final period = widget.period.name;
    return 'azkar_${period}_${_design.name}.png';
  }

  Future<void> _share() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) {
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: _fileName),
          ],
          fileNameOverrides: [_fileName],
        ),
      );
    } catch (error, stack) {
      AppLogger.error('Could not share the azkar card', error, stack);
      _showKey('share_failed');
    }
  }

  Future<void> _save() async {
    final bytes = await _capture();
    if (bytes == null || !mounted) {
      return;
    }
    try {
      final directory = await _saveDirectory();
      final folder = Directory('${directory.path}/azkar_cards');
      await folder.create(recursive: true);
      final file = File('${folder.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      AppLogger.info('Saved azkar card to ${file.path}');
      if (!mounted) {
        return;
      }
      _showKey('azkar_share_saved');
    } catch (error, stack) {
      AppLogger.error('Could not save the azkar card', error, stack);
      if (!mounted) {
        return;
      }
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'image/png', name: _fileName),
            ],
            fileNameOverrides: [_fileName],
          ),
        );
      } catch (shareError, shareStack) {
        AppLogger.error(
          'Could not share the azkar card',
          shareError,
          shareStack,
        );
        _showKey('share_failed');
      }
    }
  }

  Future<Directory> _saveDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    } catch (error) {
      AppLogger.warning('Downloads folder is not available: $error');
    }
    return getApplicationDocumentsDirectory();
  }

  Future<ui.Image?> _raster() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    return boundary.toImage(pixelRatio: 1);
  }

  Future<Uint8List?> _capture() async {
    if (_busy) {
      return null;
    }
    setState(() => _busy = true);
    try {
      final image = await _raster();
      if (image == null) {
        _showKey('share_failed');
        return null;
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = data?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        _showKey('share_failed');
        return null;
      }
      return bytes;
    } catch (error, stack) {
      AppLogger.error('Could not draw the azkar card', error, stack);
      _showKey('share_failed');
      return null;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showKey(String key) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(key)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return AppScaffold(
      title: 'azkar_share_title',
      showBack: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg + bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('choose_card_style'),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final design in AzkarShareDesign.values)
                  _DesignChoice(
                    design: design,
                    selected: design == _design,
                    onTap:
                        _busy ? null : () => setState(() => _design = design),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: AzkarShareCard(
                      period: widget.period,
                      design: _design,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _share,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: _ActionLabel(
                      busy: _busy,
                      icon: Icons.ios_share,
                      label: context.tr('share_image'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: _ActionLabel(
                      busy: _busy,
                      icon: Icons.download_outlined,
                      label: context.tr('azkar_share_save'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.busy,
    required this.icon,
    required this.label,
  });

  final bool busy;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _DesignChoice extends StatelessWidget {
  const _DesignChoice({
    required this.design,
    required this.selected,
    required this.onTap,
  });

  final AzkarShareDesign design;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = switch (design) {
      AzkarShareDesign.mist => AzkarSharePalette.mist,
      AzkarShareDesign.garden => AzkarSharePalette.garden,
      AzkarShareDesign.night => AzkarSharePalette.night,
      AzkarShareDesign.parchment => AzkarSharePalette.parchment,
    };
    final label = switch (design) {
      AzkarShareDesign.mist => context.tr('azkar_share_mist'),
      AzkarShareDesign.garden => context.tr('azkar_share_garden'),
      AzkarShareDesign.night => context.tr('card_style_night'),
      AzkarShareDesign.parchment => context.tr('card_style_parchment'),
    };

    return Material(
      color: selected ? tokens.brandSoft : tokens.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Swatch(design: design, palette: palette),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.body(
                    context,
                    fontSize: 14,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.design, required this.palette});

  final AzkarShareDesign design;
  final AzkarSharePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 36,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              design == AzkarShareDesign.parchment
                  ? palette.accent
                  : palette.ink.withValues(alpha: 0.2),
        ),
      ),
      child: switch (design) {
        AzkarShareDesign.mist => Center(
          child: Container(
            width: 16,
            height: 6,
            decoration: BoxDecoration(
              color: palette.badge,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        AzkarShareDesign.garden => Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(width: 4, color: palette.accent),
        ),
        AzkarShareDesign.night => Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent),
            ),
          ),
        ),
        AzkarShareDesign.parchment => const SizedBox.shrink(),
      },
    );
  }
}
