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
                _Artwork(size: math.max(art, 150), tokens: tokens, info: info),
                const SizedBox(height: AppSpacing.lg),
                // The name is on the plate now, so this line carries only what
                // the plate does not: how long the surah is.
                Text(
                  '${info.versesCount} ${context.tr('verses_short')}',
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
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
            style: AppTextStyles.caption(context, color: tokens.goldInk),
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

/// The cover: the surah's own name, set large on a soft wash.
///
/// It was an eight-pointed star, the same one on every surah — a picture of
/// nothing in particular, taking the largest area on the screen while the name
/// it stood for sat in small type underneath. A recitation's cover is its name,
/// so the name is the cover: it names what is playing at the size the screen
/// gives it, and it is different for all hundred and fourteen.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.size,
    required this.tokens,
    required this.info,
  });

  final double size;
  final AppTokens tokens;
  final QuranSurahInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.11),
        color: tokens.surface,
        border: Border.all(color: tokens.line, width: 1.4),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A brush of colour behind the lettering, and sprigs in two corners.
          // Ornament that frames the name rather than competing with it.
          Positioned.fill(
            child: CustomPaint(
              painter: _NamePlatePainter(
                wash: tokens.brand.withValues(alpha: 0.07),
                line: tokens.brand.withValues(alpha: 0.26),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    'سورة ${info.nameAr}',
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    style: AppTextStyles.display(
                      context,
                      // Sized off the plate, not fixed: the plate itself
                      // shrinks on a short screen, and type that did not
                      // shrink with it would run off the edge.
                      fontSize: size * 0.17,
                      color: tokens.ink,
                    ),
                  ),
                ),
                SizedBox(height: size * 0.05),
                Text(
                  info.nameEn,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkMuted,
                    fontSize: size * 0.055,
                  ),
                ),
                SizedBox(height: size * 0.015),
                Text(
                  'Quran : ${info.id}',
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkFaint,
                    fontSize: size * 0.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wash and the two corner sprigs behind the name.
class _NamePlatePainter extends CustomPainter {
  const _NamePlatePainter({required this.wash, required this.line});

  final Color wash;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // A soft brush stroke across the middle, drawn as one closed curve rather
    // than a rectangle so its edges stay irregular the way a brush is.
    final brush =
        Path()
          ..moveTo(w * 0.06, h * 0.34)
          ..quadraticBezierTo(w * 0.30, h * 0.22, w * 0.55, h * 0.30)
          ..quadraticBezierTo(w * 0.82, h * 0.38, w * 0.96, h * 0.30)
          ..lineTo(w * 0.96, h * 0.70)
          ..quadraticBezierTo(w * 0.70, h * 0.80, w * 0.44, h * 0.72)
          ..quadraticBezierTo(w * 0.18, h * 0.64, w * 0.06, h * 0.72)
          ..close();
    canvas.drawPath(brush, Paint()..color = wash);

    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.shortestSide * 0.006)
          ..strokeCap = StrokeCap.round
          ..color = line;

    _sprig(
      canvas,
      Offset(w * 0.11, h * 0.14),
      size.shortestSide * 0.19,
      1,
      stroke,
    );
    _sprig(
      canvas,
      Offset(w * 0.89, h * 0.86),
      size.shortestSide * 0.19,
      -1,
      stroke,
    );
  }

  /// A stem with leaves, growing away from the corner it starts in.
  void _sprig(
    Canvas canvas,
    Offset root,
    double length,
    double direction,
    Paint paint,
  ) {
    final tip = root + Offset(0, length * direction);
    canvas.drawPath(
      Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(
          root.dx + length * 0.22 * direction,
          root.dy + length * 0.5 * direction,
          tip.dx,
          tip.dy,
        ),
      paint,
    );

    for (final at in [0.3, 0.55, 0.8]) {
      final centre = Offset(
        root.dx + length * 0.13 * direction * at,
        root.dy + length * at * direction,
      );
      final leaf = length * 0.19;
      canvas.drawOval(
        Rect.fromCenter(
          center: centre + Offset(leaf * 0.8 * direction, 0),
          width: leaf * 1.7,
          height: leaf * 0.8,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: centre - Offset(leaf * 0.8 * direction, 0),
          width: leaf * 1.7,
          height: leaf * 0.8,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NamePlatePainter old) =>
      old.wash != wash || old.line != line;
}
