import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../providers/reader_settings_provider.dart';

/// Pinch the page to make the Mushaf bigger or smaller.
///
/// The size of the script was reachable only through a settings sheet — a
/// menu, a slider, and a trip out of the page and back to see the result. That
/// is a long way round for the one adjustment people make most, and it is the
/// adjustment they make most because eyes differ and the default cannot suit
/// everyone. Two fingers on the page is the gesture everybody already knows
/// from photographs and maps, and it shows the result while it is happening.
///
/// It scales the type, not the pixels. A [Transform] would blur the script and
/// leave the lines running off the side; changing the font size reflows the
/// page, so the text stays sharp and every line still fits.
class ReaderZoom extends ConsumerStatefulWidget {
  const ReaderZoom({super.key, required this.child, this.onChanged});

  final Widget child;

  /// Called as the size changes, so the page can show what it is now.
  final ValueChanged<double>? onChanged;

  @override
  ConsumerState<ReaderZoom> createState() => _ReaderZoomState();
}

class _ReaderZoomState extends ConsumerState<ReaderZoom> {
  /// The size the pinch started from.
  double _startSize = 0;

  /// Below this the gesture is a scroll that happens to use two fingers.
  static const double _deadZone = 0.04;

  void _onStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) {
      return;
    }
    _startSize = ref.read(readerSettingsProvider).fontSize;
  }

  void _onUpdate(ScaleUpdateDetails details) {
    // One finger is a scroll, and swallowing it here would freeze the page.
    if (details.pointerCount < 2 || _startSize == 0) {
      return;
    }
    if ((details.scale - 1).abs() < _deadZone) {
      return;
    }

    final size = (_startSize * details.scale).clamp(18.0, 56.0).toDouble();
    final current = ref.read(readerSettingsProvider).fontSize;
    // Half a point is under the threshold of noticing, and writing every frame
    // means writing to disk on every frame.
    if ((size - current).abs() < 0.5) {
      return;
    }

    ref.read(readerSettingsProvider.notifier).setFontSize(size);
    widget.onChanged?.call(size);
  }

  void _onEnd(ScaleEndDetails details) {
    _startSize = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Scale gestures and the list's own drag both want the pointer. Deferring
      // to the child keeps one-finger scrolling exactly as it was; only a
      // second finger brings this to life.
      behavior: HitTestBehavior.deferToChild,
      onScaleStart: _onStart,
      onScaleUpdate: _onUpdate,
      onScaleEnd: _onEnd,
      child: widget.child,
    );
  }
}

/// The size, shown briefly while a pinch is happening.
///
/// Without it the page grows with no number attached, and someone who has gone
/// too far has nothing to aim back at.
class ZoomBadge extends StatelessWidget {
  const ZoomBadge({super.key, required this.fontSize, required this.visible});

  final double fontSize;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.fast,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: tokens.ink.withValues(alpha: 0.82),
            borderRadius: AppRadii.pillAll,
          ),
          child: Text(
            '${fontSize.round()}',
            style: AppTextStyles.display(
              context,
              fontSize: 18,
              color: tokens.surface,
            ),
          ),
        ),
      ),
    );
  }
}
