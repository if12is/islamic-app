import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../domain/broadcast.dart';
import '../providers/radio_provider.dart';

/// One television channel, playing while this page is open.
///
/// It stops on the way out rather than carrying on in the background: video
/// nobody is looking at is only a flat battery, and unlike the radio there is
/// nothing to listen to with the screen off.
class LiveTvPage extends ConsumerStatefulWidget {
  const LiveTvPage({super.key, required this.channel});

  final Broadcast channel;

  static Future<void> open(BuildContext context, Broadcast channel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LiveTvPage(channel: channel)),
    );
  }

  @override
  ConsumerState<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends ConsumerState<LiveTvPage> {
  VideoPlayerController? _controller;
  String? _errorKey;
  String? _errorDetail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // A channel and a station at once is nobody's intention.
    ref.read(radioProvider.notifier).stop();
    _start();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _errorDetail = null;
    });

    for (final source in widget.channel.sources) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(source));
      try {
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        await controller.play();
        await WakelockPlus.enable();
        setState(() {
          _controller = controller;
          _loading = false;
        });
        return;
      } catch (e, stack) {
        await controller.dispose();
        AppLogger.warning('Channel source failed ($source): $e');
        if (source == widget.channel.sources.last) {
          AppLogger.error('Live TV failed', e, stack);
          if (mounted) {
            setState(() {
              _loading = false;
              _errorKey = 'broadcast_channel_down';
              _errorDetail = e.toString();
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = _controller;

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        widget.channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.display(context, fontSize: 17, color: tokens.ink),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child:
              _loading
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator.adaptive(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        context.tr('broadcast_connecting'),
                        style: AppTextStyles.caption(
                          context,
                          color: tokens.inkFaint,
                        ),
                      ),
                    ],
                  )
                  : controller != null
                  ? _player(tokens, controller)
                  : _failure(tokens),
        ),
      ),
    );
  }

  Widget _player(AppTokens tokens, VideoPlayerController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: AppRadii.mdAll,
          child: AspectRatio(
            aspectRatio:
                controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: context.tr(
                controller.value.isPlaying ? 'pause' : 'play',
              ),
              iconSize: 44,
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: tokens.brand,
              ),
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            IconButton(
              tooltip: context.tr(
                controller.value.volume == 0 ? 'unmute' : 'mute',
              ),
              iconSize: 26,
              icon: Icon(
                controller.value.volume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: tokens.inkMuted,
              ),
              onPressed: () async {
                await controller.setVolume(
                  controller.value.volume == 0 ? 1 : 0,
                );
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _failure(AppTokens tokens) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 44, color: tokens.inkFaint),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr(_errorKey ?? 'broadcast_failed'),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(context, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('broadcast_channel_down_desc'),
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(context, color: tokens.inkFaint),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('retry')),
            ),
            if (_errorDetail != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (dialogContext) => AlertDialog(
                            title: Text(dialogContext.tr('details')),
                            content: SingleChildScrollView(
                              child: SelectableText(
                                _errorDetail!,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(dialogContext).pop(),
                                child: Text(dialogContext.tr('close')),
                              ),
                            ],
                          ),
                    ),
                child: Text(context.tr('details')),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
