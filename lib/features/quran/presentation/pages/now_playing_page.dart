import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/reciter_catalogue.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/surah_audio_provider.dart';
import '../widgets/reciter_picker_sheet.dart';
import 'downloads_page.dart';

/// The full player: one recitation, and every control it needs.
///
/// The mini bar on the Quran screen is a summary of this, not a separate
/// player — both read [surahAudioProvider], so a speed set here is the speed
/// there and closing this screen does not stop anything.
class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.base,
        reverseTransitionDuration: AppMotion.base,
        pageBuilder: (_, animation, _) => const NowPlayingPage(),
        transitionsBuilder: (_, animation, _, child) {
          // Rises from the bar it was tapped on, and drops back onto it.
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: AppMotion.enter),
            ),
            child: child,
          );
        },
      ),
    );
  }

  static const List<int> _sleepMinutes = [15, 30, 45, 60];
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final state = ref.watch(surahAudioProvider);
    final controller = ref.read(surahAudioProvider.notifier);
    final player = ref.read(quranAudioPlayerProvider);

    final surah = state.surahNumber;
    if (surah == null) {
      // Playback ended while this was open. Fall back rather than show a
      // player with nothing in it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      });
      return const AppScaffold(body: SizedBox.shrink());
    }

    final info = QuranLocalService.surahInfo(surah);

    return AppScaffold(
      title: 'now_playing',
      leading: IconButton(
        tooltip: context.tr('offline_downloads'),
        icon: Icon(Icons.cloud_download_outlined, color: tokens.ink, size: 22),
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
            ),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('close'),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: tokens.ink,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The artwork gives up its room first on a short screen, so the
          // controls never slide under the edge.
          final art = math.min(
            constraints.maxWidth - AppSpacing.page * 2,
            constraints.maxHeight * 0.4,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                _Artwork(size: math.max(art, 140), tokens: tokens),
                const SizedBox(height: AppSpacing.xl),
                _title(context, tokens, info),
                const SizedBox(height: AppSpacing.sm),
                _reciterRow(context, ref, state, tokens),
                const SizedBox(height: AppSpacing.xl),
                _Seekbar(player: player, onSeek: controller.seek),
                const SizedBox(height: AppSpacing.md),
                _transport(context, state, controller, tokens),
                const SizedBox(height: AppSpacing.lg),
                _extras(context, ref, state, controller, tokens),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _title(BuildContext context, AppTokens tokens, QuranSurahInfo info) {
    return Column(
      children: [
        Text(
          info.nameAr,
          textAlign: TextAlign.center,
          style: AppTextStyles.display(
            context,
            fontSize: 27,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${info.nameEn} · ${info.versesCount} '
          '${context.tr('verses_short')}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(context, color: tokens.inkFaint),
        ),
      ],
    );
  }

  Widget _reciterRow(
    BuildContext context,
    WidgetRef ref,
    SurahPlaybackState state,
    AppTokens tokens,
  ) {
    return FutureBuilder<List<ReciterVoice>>(
      future: ReciterCatalogue.load(),
      builder: (context, snapshot) {
        final voices = snapshot.data ?? ReciterCatalogue.bundled;
        final voice = ReciterCatalogue.byId(state.reciterId, voices);
        final name =
            voice?.nameAr ?? QuranReciter.byCode(state.reciterId).nameAr;
        final style = voice?.styleAr ?? '';

        return Material(
          color: tokens.groundAlt,
          borderRadius: AppRadii.pillAll,
          child: InkWell(
            borderRadius: AppRadii.pillAll,
            onTap: () async {
              final chosen = await ReciterPickerSheet.show(
                context,
                state.reciterId,
              );
              if (chosen == null) {
                return;
              }
              ref.read(readerSettingsProvider.notifier).setReciter(chosen.id);
              await ref.read(surahAudioProvider.notifier).setReciter(chosen.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 17,
                    color: tokens.brand,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            context,
                            color: tokens.ink,
                            fontSize: 13,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (style.isNotEmpty)
                          Text(
                            style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(
                              context,
                              color: tokens.inkFaint,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: tokens.inkFaint,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _transport(
    BuildContext context,
    SurahPlaybackState state,
    SurahAudioController controller,
    AppTokens tokens,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _round(
          context,
          icon: Icons.skip_previous_rounded,
          tooltipKey: 'previous_surah',
          onTap: controller.previousSurah,
          tokens: tokens,
        ),
        _round(
          context,
          icon: Icons.replay_10_rounded,
          tooltipKey: 'back_ten',
          onTap: () => controller.skip(const Duration(seconds: -10)),
          tokens: tokens,
        ),
        _PlayButton(
          playing: state.playing,
          loading: state.loading,
          onTap: controller.toggle,
          tokens: tokens,
        ),
        _round(
          context,
          icon: Icons.forward_10_rounded,
          tooltipKey: 'forward_ten',
          onTap: () => controller.skip(const Duration(seconds: 10)),
          tokens: tokens,
        ),
        _round(
          context,
          icon: Icons.skip_next_rounded,
          tooltipKey: 'next_surah',
          onTap: controller.nextSurah,
          tokens: tokens,
        ),
      ],
    );
  }

  Widget _round(
    BuildContext context, {
    required IconData icon,
    required String tooltipKey,
    required VoidCallback onTap,
    required AppTokens tokens,
  }) {
    return Semantics(
      button: true,
      label: context.tr(tooltipKey),
      child: IconButton(
        tooltip: context.tr(tooltipKey),
        onPressed: onTap,
        iconSize: 30,
        icon: Icon(icon, color: tokens.inkMuted),
      ),
    );
  }

  Widget _extras(
    BuildContext context,
    WidgetRef ref,
    SurahPlaybackState state,
    SurahAudioController controller,
    AppTokens tokens,
  ) {
    final remaining = state.sleepTimerRemaining;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _toggle(
              context,
              tokens,
              icon: Icons.repeat_rounded,
              labelKey: 'repeat_surah',
              active: state.repeatSurah,
              onTap: () => controller.setRepeatSurah(!state.repeatSurah),
            ),
            _toggle(
              context,
              tokens,
              icon: Icons.bedtime_outlined,
              labelKey: 'sleep_timer',
              active: state.hasSleepTimer,
              onTap: () => _sleepSheet(context, state, controller),
            ),
            _toggle(
              context,
              tokens,
              icon: Icons.speed_rounded,
              labelKey: 'playback_speed',
              label: '${state.speed.toStringAsFixed(2)}×',
              active: state.speed != 1.0,
              onTap: () => _speedSheet(context, state, controller),
            ),
            _toggle(
              context,
              tokens,
              icon: Icons.stop_circle_outlined,
              labelKey: 'stop',
              active: false,
              onTap: controller.stop,
            ),
          ],
        ),
        if (remaining != null || state.stopAtEnd) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            state.stopAtEnd
                ? context.tr('end_of_passage')
                : '${context.tr('sleep_timer')}: '
                    '${remaining!.inMinutes + 1} '
                    '${context.tr('minutes_short')}',
            style: AppTextStyles.caption(context, color: tokens.gold),
          ),
        ],
      ],
    );
  }

  Widget _toggle(
    BuildContext context,
    AppTokens tokens, {
    required IconData icon,
    required String labelKey,
    required bool active,
    required VoidCallback onTap,
    String? label,
  }) {
    final colour = active ? tokens.brand : tokens.inkFaint;

    return Semantics(
      button: true,
      toggled: active,
      label: context.tr(labelKey),
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: colour),
              const SizedBox(height: 4),
              Text(
                label ?? context.tr(labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(
                  context,
                  color: colour,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sleepSheet(
    BuildContext context,
    SurahPlaybackState state,
    SurahAudioController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Directionality(
            textDirection: sheetContext.appTextDirection,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(sheetContext.tr('minutes_off')),
                    trailing:
                        state.hasSleepTimer
                            ? null
                            : const Icon(Icons.check_rounded),
                    onTap: () {
                      controller.setSleepTimer(null);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  for (final minutes in _sleepMinutes)
                    ListTile(
                      title: Text(
                        AppLocalizations.translate(
                          Localizations.localeOf(sheetContext).languageCode,
                          'minutes_value',
                          replacements: {'minutes': '$minutes'},
                        ),
                      ),
                      onTap: () {
                        controller.setSleepTimer(Duration(minutes: minutes));
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ListTile(
                    title: Text(sheetContext.tr('end_of_passage')),
                    trailing:
                        state.stopAtEnd
                            ? const Icon(Icons.check_rounded)
                            : null,
                    onTap: () {
                      controller.stopAtEndOfSurah();
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _speedSheet(
    BuildContext context,
    SurahPlaybackState state,
    SurahAudioController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Directionality(
            textDirection: sheetContext.appTextDirection,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final speed in _speeds)
                    ListTile(
                      title: Text('${speed.toStringAsFixed(2)}×'),
                      trailing:
                          (state.speed - speed).abs() < 0.01
                              ? const Icon(Icons.check_rounded)
                              : null,
                      onTap: () {
                        controller.setSpeed(speed);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }
}

/// The big play control, with the buffering state inside it rather than beside
/// it — a spinner next to a play button leaves you unsure which one is live.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.onTap,
    required this.tokens,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr(playing ? 'pause' : 'play'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.brand,
            boxShadow: AppShadows.glow(tokens.brand),
          ),
          child:
              loading
                  ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(tokens.ground),
                    ),
                  )
                  : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 40,
                    color: tokens.ground,
                  ),
        ),
      ),
    );
  }
}

/// Position, duration, and a bar you can drag.
///
/// It holds the value being dragged locally: reading straight from the stream
/// makes the thumb snap back under the finger every time a position event
/// arrives, which feels like the drag is being fought.
class _Seekbar extends StatefulWidget {
  const _Seekbar({required this.player, required this.onSeek});

  final AudioPlayer player;
  final Future<void> Function(Duration position) onSeek;

  @override
  State<_Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snapshot) {
        final duration = widget.player.duration ?? Duration.zero;
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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: tokens.brand,
                inactiveTrackColor: tokens.groundAlt,
                thumbColor: tokens.brand,
              ),
              child: Slider(
                value: value.toDouble(),
                max: max <= 0 ? 1 : max,
                // Nothing loaded yet: a bar that can be dragged but does
                // nothing is worse than one that plainly cannot.
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
                    formatDuration(Duration(milliseconds: value.round())),
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                    ),
                  ),
                  Text(
                    duration > Duration.zero
                        ? formatDuration(duration)
                        : '--:--',
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

  /// `05:48`, or `1:05:48` once it passes the hour.
  static String formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// The cover: an eight-pointed rosette in the brand colours.
///
/// Drawn rather than shipped as an image, so it takes the season's accent and
/// the dark theme without a second asset.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.size, required this.tokens});

  final double size;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.11),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [tokens.brandDeep, tokens.brand],
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: CustomPaint(painter: _RosettePainter(colour: tokens.gold)),
    );
  }
}

class _RosettePainter extends CustomPainter {
  const _RosettePainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.006
          ..color = colour.withValues(alpha: 0.55);

    for (final scale in [0.42, 0.3, 0.18]) {
      canvas.drawPath(
        _star(centre, size.shortestSide * scale),
        paint..color = colour.withValues(alpha: 0.2 + scale),
      );
    }

    canvas.drawCircle(
      centre,
      size.shortestSide * 0.07,
      Paint()..color = colour.withValues(alpha: 0.85),
    );
  }

  Path _star(Offset centre, double radius) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.44;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_RosettePainter old) => old.colour != colour;
}
