import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/adhan_sound.dart';
import '../../../../core/services/adhan_library.dart';
import '../../../../core/services/adhan_preview_player.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_scaffold.dart';

enum _LibraryFilter { all, fajr, rare }

/// Adhans from around the Muslim world, one tap to hear and one to keep.
///
/// The page does not know which prayer it was opened for. The caller hands in
/// the current selection and [onSelected] for that scope (all prayers, or
/// Fajr alone), so choosing here lands exactly where an imported file would —
/// no second set of preferences to keep in step.
class AdhanLibraryPage extends StatefulWidget {
  const AdhanLibraryPage({
    super.key,
    required this.current,
    required this.onSelected,
    this.forFajr = false,
  });

  final AdhanSoundSelection current;

  /// Saves the chosen selection for the scope the user came from.
  final Future<void> Function(AdhanSoundSelection selection) onSelected;

  /// Opens on the Fajr filter, since those are the adhans that include
  /// «الصلاة خير من النوم» and suit only that prayer.
  final bool forFajr;

  @override
  State<AdhanLibraryPage> createState() => _AdhanLibraryPageState();
}

class _AdhanLibraryPageState extends State<AdhanLibraryPage> {
  late final Future<void> _loaded = AdhanLibrary.load();
  late AdhanSoundSelection _current = widget.current;
  late _LibraryFilter _filter =
      widget.forFajr ? _LibraryFilter.fajr : _LibraryFilter.all;

  String? _installingId;
  String? _previewId;
  bool _previewLoading = false;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    AdhanPreviewPlayer.playing.addListener(_onPlayingChanged);
  }

  @override
  void dispose() {
    AdhanPreviewPlayer.playing.removeListener(_onPlayingChanged);
    _stateSub?.cancel();
    // A preview left running would keep singing after the page is gone.
    unawaited(AdhanPreviewPlayer.stop());
    super.dispose();
  }

  void _onPlayingChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (AdhanPreviewPlayer.playingId != _previewId) {
        _previewId = null;
        _previewLoading = false;
      }
    });
  }

  String _previewKey(AdhanVoice voice) => 'library_${voice.id}';

  Future<void> _preview(AdhanVoice voice) async {
    final key = _previewKey(voice);
    final stopping = AdhanPreviewPlayer.playingId == key;
    if (!stopping) {
      setState(() {
        _previewId = key;
        _previewLoading = true;
      });
      // The player reports buffering itself; the spinner follows it rather
      // than guessing how long a remote file takes to start.
      _stateSub ??= AdhanPreviewPlayer.stateStream.listen((state) {
        if (!mounted || _previewId == null) {
          return;
        }
        final loading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        if (loading != _previewLoading) {
          setState(() => _previewLoading = loading);
        }
      });
    }

    // The id is per voice: a shared custom id would make a second voice look
    // like the one already playing and stop it instead of switching.
    final result = await AdhanPreviewPlayer.toggle(
      AdhanSoundSelection(id: key, uri: voice.url, title: voice.nameAr),
    );
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      AdhanPreviewResult.unavailable => context.tr('preview_unavailable'),
      AdhanPreviewResult.failed => context.tr('preview_failed'),
      AdhanPreviewResult.started || AdhanPreviewResult.stopped => null,
    };
    if (message != null) {
      setState(() {
        _previewId = null;
        _previewLoading = false;
      });
      _toast(message);
    }
  }

  Future<void> _choose(AdhanVoice voice) async {
    if (_installingId != null) {
      return;
    }
    setState(() => _installingId = voice.id);
    try {
      final selection = await AdhanLibrary.install(voice);
      if (!mounted) {
        return;
      }
      await widget.onSelected(selection);
      if (!mounted) {
        return;
      }
      setState(() => _current = selection);
      _toast(
        context
            .tr('adhan_library_chosen')
            .replaceAll('{name}', voice.name(_lang)),
      );
    } on AdhanLibraryException catch (error) {
      AppLogger.warning('Adhan library choose failed: $error');
      if (mounted) {
        _toast(
          context.tr(switch (error.reason) {
            'network' => 'adhan_library_err_network',
            'unsupported' => 'adhan_library_err_unsupported',
            _ => 'adhan_library_err_install',
          }),
        );
      }
    } catch (error, stack) {
      // A full disk or a write the system refused: still say it did not
      // work, rather than let the spinner simply stop.
      AppLogger.error('Adhan library choose failed', error, stack);
      if (mounted) {
        _toast(context.tr('adhan_library_err_install'));
      }
    } finally {
      if (mounted) {
        setState(() => _installingId = null);
      }
    }
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _matches(AdhanVoice voice) => switch (_filter) {
    _LibraryFilter.all => true,
    _LibraryFilter.fajr => voice.fajr,
    _LibraryFilter.rare => voice.rare,
  };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBack: true,
      titleWidget: Text(context.tr('adhan_library_title')),
      body: FutureBuilder<void>(
        future: _loaded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return _list(context);
        },
      ),
    );
  }

  Widget _list(BuildContext context) {
    final tokens = context.tokens;
    final selected = AdhanLibrary.voiceFor(_current);
    final children = <Widget>[
      Wrap(
        spacing: 8,
        children: [
          for (final filter in _LibraryFilter.values)
            ChoiceChip(
              label: Text(context.tr('adhan_filter_${filter.name}')),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
        ],
      ),
    ];

    var any = false;
    for (final region in AdhanRegion.values) {
      final voices = [
        for (final voice in AdhanLibrary.voices)
          if (voice.region == region && _matches(voice)) voice,
      ];
      if (voices.isEmpty) {
        continue;
      }
      any = true;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            context.tr('adhan_region_${region.name}'),
            style: AppTextStyles.display(context, fontSize: 18),
          ),
        ),
      );
      for (final voice in voices) {
        children.add(_row(context, voice, isSelected: voice == selected));
      }
    }
    if (!any) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(context.tr('adhan_library_empty'))),
        ),
      );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          context.tr('adhan_library_note'),
          style: AppTextStyles.caption(
            context,
          ).copyWith(color: tokens.inkMuted),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: children,
    );
  }

  Widget _row(
    BuildContext context,
    AdhanVoice voice, {
    required bool isSelected,
  }) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final installing = _installingId == voice.id;
    final previewing = _previewId == _previewKey(voice);
    final size = localizeDigits(
      context,
      (voice.bytes / (1024 * 1024)).toStringAsFixed(1),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child:
                  previewing && _previewLoading
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                      : IconButton(
                        tooltip: context.tr('preview_sound'),
                        iconSize: 30,
                        icon: Icon(
                          previewing
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                          color: previewing ? scheme.primary : null,
                        ),
                        onPressed: () => _preview(voice),
                      ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.name(_lang),
                    style: AppTextStyles.body(
                      context,
                      fontSize: 17,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    voice.place(_lang),
                    style: AppTextStyles.caption(context),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (voice.fajr) _chip(context, 'adhan_chip_fajr'),
                      if (voice.rare) _chip(context, 'adhan_chip_rare'),
                      Text(
                        context.tr('adhan_size_mb').replaceAll('{n}', size),
                        style: AppTextStyles.caption(context),
                      ),
                      if (AdhanLibrary.isInstalled(voice))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_done,
                              size: 14,
                              color: tokens.inkMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              context.tr('adhan_installed'),
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (installing)
              const SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (isSelected)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('adhan_selected'),
                    style: AppTextStyles.caption(
                      context,
                    ).copyWith(color: scheme.primary),
                  ),
                ],
              )
            else
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                onPressed: _installingId == null ? () => _choose(voice) : null,
                child: Text(context.tr('adhan_choose')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String key) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.brandSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.tr(key),
          style: AppTextStyles.caption(context).copyWith(color: tokens.brand),
        ),
      ),
    );
  }
}
