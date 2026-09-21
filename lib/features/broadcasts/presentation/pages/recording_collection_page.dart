import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../quran/presentation/providers/quran_audio_provider.dart';
import '../../domain/recording.dart';
import '../providers/recordings_provider.dart';

/// The files of one curated collection, and the player for them.
class RecordingCollectionPage extends ConsumerStatefulWidget {
  const RecordingCollectionPage({super.key, required this.collection});

  final RecordingCollection collection;

  static Future<void> open(
    BuildContext context,
    RecordingCollection collection,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingCollectionPage(collection: collection),
      ),
    );
  }

  @override
  ConsumerState<RecordingCollectionPage> createState() =>
      _RecordingCollectionPageState();
}

class _RecordingCollectionPageState
    extends ConsumerState<RecordingCollectionPage> {
  late final Future<String?> _lastTrackId = RecordingsController.lastTrackId(
    widget.collection.id,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final collection = widget.collection;
    final tracksAsync = ref.watch(recordingTracksProvider(collection.id));
    final playback = ref.watch(recordingsProvider);
    final isThisCollection = playback.collection?.id == collection.id;

    ref.listen<RecordingsState>(recordingsProvider, (previous, next) {
      final key = next.errorKey;
      if (key == null || key == previous?.errorKey) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.tr(key))));
        ref.read(recordingsProvider.notifier).clearError();
      });
    });

    return AppScaffold(
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: tracksAsync.when(
              loading:
                  () => Column(
                    children: [
                      _Header(collection: collection),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ],
                  ),
              error: (_, _) => _failed(tokens, collection),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return _failed(tokens, collection);
                }
                return _TrackList(
                  collection: collection,
                  tracks: tracks,
                  lastTrackId: _lastTrackId,
                  playback: playback,
                );
              },
            ),
          ),
          if (isThisCollection) _PlayerBar(state: playback),
        ],
      ),
    );
  }

  Widget _failed(AppTokens tokens, RecordingCollection collection) {
    return Column(
      children: [
        _Header(collection: collection),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('recording_list_failed'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      color: tokens.inkMuted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed:
                        () => ref.invalidate(
                          recordingTracksProvider(collection.id),
                        ),
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collection, this.trackCount});

  final RecordingCollection collection;
  final int? trackCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizeDigits(context, collection.reciterAr),
            style: AppTextStyles.display(context, fontSize: 22),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizeDigits(context, collection.titleAr),
            style: AppTextStyles.body(context, fontSize: 15),
          ),
          if (collection.subtitleAr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              localizeDigits(context, collection.subtitleAr),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
          ],
          if (collection.noteAr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizeDigits(context, collection.noteAr),
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ],
          if (trackCount != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.translate(
                language,
                'recordings_count',
                replacements: {'count': localizeDigits(context, '$trackCount')},
              ),
              style: AppTextStyles.caption(context, color: tokens.brand),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({
    required this.collection,
    required this.tracks,
    required this.lastTrackId,
    required this.playback,
  });

  final RecordingCollection collection;
  final List<RecordingTrack> tracks;
  final Future<String?> lastTrackId;
  final RecordingsState playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: lastTrackId,
      builder: (context, snapshot) {
        // Not while this collection is already the one playing: the button
        // would name a place the player has moved on from, and pressing it
        // would jump back there.
        final loaded = playback.collection?.id == collection.id;
        final resumeId = loaded ? null : snapshot.data;
        final resumeIndex =
            resumeId == null
                ? -1
                : tracks.indexWhere((track) => track.id == resumeId);

        return ListView.builder(
          padding: AppScaffold.scrollPadding,
          itemCount: tracks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(collection: collection, trackCount: tracks.length),
                  if (resumeIndex >= 0) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            () => ref
                                .read(recordingsProvider.notifier)
                                .play(collection, tracks, resumeIndex),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(context.tr('recordings_continue')),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              );
            }

            final at = index - 1;
            final track = tracks[at];
            final previous = at == 0 ? null : tracks[at - 1];
            final showGroup =
                track.group != null && track.group != previous?.group;
            final isCurrent =
                playback.collection?.id == collection.id &&
                playback.current?.id == track.id;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showGroup)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      localizeDigits(context, track.group!),
                      style: AppTextStyles.display(
                        context,
                        fontSize: 16,
                        color: context.tokens.brand,
                      ),
                    ),
                  ),
                AppListRow(
                  title: localizeDigits(context, track.titleAr),
                  meta:
                      track.subtitleAr.isEmpty
                          ? null
                          : localizeDigits(context, track.subtitleAr),
                  trailingText:
                      track.duration == null
                          ? null
                          : _formatRecordingClock(context, track.duration!),
                  selected: isCurrent,
                  leading: AppIconTile(
                    isCurrent && playback.playing
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    role: AppIconRole.row,
                    tone: isCurrent ? AppIconTone.brand : AppIconTone.neutral,
                    selected: isCurrent,
                  ),
                  onTap:
                      () => ref
                          .read(recordingsProvider.notifier)
                          .play(collection, tracks, at),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({required this.state});

  final RecordingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final controller = ref.read(recordingsProvider.notifier);
    final current = state.current;
    if (current == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: tokens.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
          boxShadow: AppShadows.lift(tokens.ink),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizeDigits(
                  context,
                  RecordingsController.displayTitle(current),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context, fontSize: 15),
              ),
              _SeekBar(onSeek: controller.seek),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: context.tr('previous'),
                    onPressed:
                        state.hasPrevious ? () => controller.previous() : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    tooltip: context.tr('recordings_back_30'),
                    onPressed:
                        () => controller.skip(const Duration(seconds: -30)),
                    icon: const Icon(Icons.replay_30_rounded),
                  ),
                  _PlayPause(state: state, onToggle: controller.toggle),
                  IconButton(
                    tooltip: context.tr('recordings_forward_30'),
                    onPressed:
                        () => controller.skip(const Duration(seconds: 30)),
                    icon: const Icon(Icons.forward_30_rounded),
                  ),
                  IconButton(
                    tooltip: context.tr('next'),
                    onPressed: state.hasNext ? () => controller.next() : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPause extends StatelessWidget {
  const _PlayPause({required this.state, required this.onToggle});

  final RecordingsState state;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final onBrand = Theme.of(context).colorScheme.onPrimary;

    return Semantics(
      button: true,
      label: context.tr(state.playing ? 'pause' : 'play'),
      child: IconButton(
        tooltip: context.tr(state.playing ? 'pause' : 'play'),
        onPressed: onToggle,
        style: IconButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: onBrand,
          disabledForegroundColor: onBrand,
          minimumSize: const Size(64, 64),
          maximumSize: const Size(72, 72),
          iconSize: 36,
        ),
        icon:
            state.loading
                ? SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: onBrand,
                  ),
                )
                : Icon(
                  state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
      ),
    );
  }
}

class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.onSeek});

  final Future<void> Function(Duration position) onSeek;

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = ref.watch(quranAudioPlayerProvider);

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final max = duration.inMilliseconds.toDouble();
        final value = (_dragging ?? position.inMilliseconds.toDouble()).clamp(
          0,
          max <= 0 ? 1 : max,
        );

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: tokens.brand,
                inactiveTrackColor: tokens.groundAlt,
                thumbColor: tokens.brand,
              ),
              child: Slider(
                value: value.toDouble(),
                max: max <= 0 ? 1 : max,
                onChanged:
                    max <= 0 ? null : (raw) => setState(() => _dragging = raw),
                onChangeEnd: (raw) async {
                  await widget.onSeek(Duration(milliseconds: raw.round()));
                  if (mounted) {
                    setState(() => _dragging = null);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatRecordingClock(
                      context,
                      Duration(milliseconds: value.round()),
                    ),
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                    ),
                  ),
                  Text(
                    duration > Duration.zero
                        ? _formatRecordingClock(context, duration)
                        : localizeDigits(context, '0:00'),
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `h:mm:ss` past an hour, otherwise `m:ss`. Digits follow the locale.
String _formatRecordingClock(BuildContext context, Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final raw =
      hours > 0
          ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
          : '$minutes:$seconds';
  return localizeDigits(context, raw);
}
