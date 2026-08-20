import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/seasonal_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_scaffold.dart';

/// The seasonal opening: a short film that plays when the app starts in
/// Ramadan or on an Eid.
///
/// The film sits in a framed card on the app's own background rather than
/// filling the screen. A full-bleed landscape clip on a portrait phone means
/// heavy cropping and a hard edge between "video" and "app" — framed, with the
/// season's greeting above it and the app's wash behind, it reads as part of
/// the same product.
///
/// It is deliberately impatient about failing: if the file does not open,
/// [onFinished] fires immediately. A greeting must never be the reason someone
/// cannot check the prayer time.
class SeasonalIntroScreen extends StatefulWidget {
  const SeasonalIntroScreen({
    super.key,
    required this.assetPath,
    required this.event,
    required this.onFinished,
    this.maxDuration = const Duration(seconds: 16),
  });

  final String assetPath;
  final SeasonalEvent event;
  final VoidCallback onFinished;

  /// Hard stop, whatever the file's own length is.
  final Duration maxDuration;

  @override
  State<SeasonalIntroScreen> createState() => _SeasonalIntroScreenState();
}

class _SeasonalIntroScreenState extends State<SeasonalIntroScreen> {
  VideoPlayerController? _controller;
  Timer? _guard;
  bool _finished = false;
  bool _ready = false;
  bool _muted = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Whatever happens, the app moves on.
    _guard = Timer(widget.maxDuration, _finish);

    try {
      final controller = VideoPlayerController.asset(widget.assetPath);
      _controller = controller;

      // Six seconds, not three: a cold start on a slow device spends most of
      // that opening the file, and cutting it short was showing a blank frame
      // and then jumping to the home screen.
      await controller.initialize().timeout(const Duration(seconds: 6));
      if (!mounted) {
        return;
      }

      controller.addListener(_onTick);
      await controller.setVolume(1);
      await controller.play();

      setState(() => _ready = true);
    } on TimeoutException {
      AppLogger.warning('Seasonal intro timed out opening ${widget.assetPath}');
      _finish();
    } catch (e, stack) {
      AppLogger.error('Seasonal intro could not play', e, stack);
      _finish();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.hasError) {
      AppLogger.warning(
        'Seasonal intro error: ${controller.value.errorDescription}',
      );
      _finish();
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero) {
      final ratio = position.inMilliseconds / duration.inMilliseconds;
      if ((ratio - _progress).abs() > 0.01 && mounted) {
        setState(() => _progress = ratio.clamp(0.0, 1.0));
      }
      if (position >= duration) {
        _finish();
      }
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    setState(() => _muted = !_muted);
    await controller.setVolume(_muted ? 0 : 1);
  }

  void _finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _guard?.cancel();
    _controller?.pause();
    widget.onFinished();
  }

  @override
  void dispose() {
    _guard?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = _controller;
    final aspect =
        _ready && controller != null ? controller.value.aspectRatio : 16 / 9;

    return Directionality(
      textDirection: context.appTextDirection,
      child: MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            // A tap anywhere skips — no hunting for a button.
            onTap: _finish,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(),

                    Text(
                      context.tr(SeasonalTheme.greetingKey(widget.event)),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(
                        context,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr(SeasonalTheme.subtitleKey(widget.event)),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // The frame: the app's card shape, with the season's
                    // accent as a thin ring and a matching glow underneath.
                    AnimatedOpacity(
                      opacity: _ready ? 1 : 0.35,
                      duration: AppMotion.slow,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.lgAll,
                          border: Border.all(
                            color: tokens.gold.withValues(alpha: 0.55),
                            width: 1.4,
                          ),
                          boxShadow: AppShadows.glow(tokens.gold, alpha: 0.22),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.lg - 6),
                          child: AspectRatio(
                            aspectRatio: aspect,
                            child:
                                _ready && controller != null
                                    ? VideoPlayer(controller)
                                    : ColoredBox(
                                      color: tokens.groundAlt,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: tokens.gold,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: _ready ? _progress : null,
                        minHeight: 4,
                        backgroundColor: tokens.groundAlt,
                        valueColor: AlwaysStoppedAnimation(tokens.goldBright),
                      ),
                    ),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _pill(
                          context,
                          icon:
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                          onTap: _toggleMute,
                        ),
                        _pill(
                          context,
                          icon: Icons.arrow_forward_rounded,
                          label: context.tr('intro_skip'),
                          onTap: _finish,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    String label = '',
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return Material(
      color: tokens.surface,
      borderRadius: AppRadii.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? AppSpacing.md : AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tokens.inkMuted),
              if (label.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.caption(context, color: tokens.ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
