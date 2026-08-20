import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/seasonal_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';

/// The seasonal opening: a short film that plays when the app starts in
/// Ramadan or on an Eid.
///
/// It is deliberately impatient about failing. If the video does not load
/// within a couple of seconds, or errors, [onFinished] fires immediately —
/// a greeting must never be the reason someone cannot check the prayer time.
class SeasonalIntroScreen extends StatefulWidget {
  const SeasonalIntroScreen({
    super.key,
    required this.assetPath,
    required this.event,
    required this.onFinished,
    this.maxDuration = const Duration(seconds: 12),
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

      await controller.initialize().timeout(const Duration(seconds: 3));
      if (!mounted) {
        return;
      }

      controller.addListener(_onTick);
      await controller.setVolume(1);
      await controller.play();

      setState(() => _ready = true);
    } catch (e, stack) {
      AppLogger.warning('Seasonal intro skipped: $e');
      AppLogger.debug(stack.toString());
      _finish();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.hasError) {
      _finish();
      return;
    }
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      _finish();
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
    final palette = SeasonalTheme.paletteFor(widget.event);
    final background = palette?.bannerColors.last ?? Colors.black;
    final controller = _controller;

    return Scaffold(
      backgroundColor: background,
      body: GestureDetector(
        // A tap anywhere skips — no hunting for a button.
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && controller != null)
              // Cover, so a landscape film still fills a portrait phone.
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: CircularProgressIndicator(
                  color: palette?.accent ?? Colors.white,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _pill(
                      context,
                      icon: _muted ? Icons.volume_off : Icons.volume_up,
                      label: '',
                      onTap: _toggleMute,
                    ),
                    _pill(
                      context,
                      icon: Icons.skip_next,
                      label: context.tr('intro_skip'),
                      onTap: _finish,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 10 : 14,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.caption(context, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
