import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/design_tokens.dart';

/// The vector icons the app draws from, bundled rather than fetched.
///
/// Material's icon font has no mosque, no lantern and no crescent-with-stars,
/// so those come from Tabler Icons (MIT, `assets/icons/LICENSE.md`) — plain
/// stroked SVGs that take the app's own colour and stay crisp at any size.
/// Nothing is downloaded at run time: the whole set is a few kilobytes.
enum IslamicIcon {
  mosque('building-mosque'),
  crescentStars('moon-stars'),
  moon('moon-2'),
  quran('book'),
  star('star'),
  sunrise('sunrise'),
  sunset('sunset'),
  sun('sun'),
  compass('compass'),
  confetti('confetti'),
  lantern('lamp-2'),
  gift('gift'),
  calendar('calendar-month'),
  bell('bell-ringing'),
  drop('droplet-half-2'),
  beads('circle-dot'),
  sparkles('sparkles'),
  flame('flame'),
  tent('tent');

  const IslamicIcon(this.file);

  /// File name under `assets/icons/`, without the extension.
  final String file;

  String get path => 'assets/icons/$file.svg';
}

/// One bundled vector icon, coloured from the tokens.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth,
  });

  final IslamicIcon icon;
  final double size;
  final Color? color;

  /// Tabler draws at stroke 2 on a 24 grid; thinner reads better at small
  /// sizes beside Cairo's light strokes.
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.tokens.inkMuted;

    return SvgPicture.asset(
      icon.path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      theme: SvgTheme(currentColor: tint),
    );
  }
}

/// A vector icon inside a soft circle — the shape used in rails and rows.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge(
    this.icon, {
    super.key,
    this.size = 44,
    this.color,
    this.background,
  });

  final IslamicIcon icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tint = color ?? tokens.brand;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: AppIcon(icon, size: size * 0.48, color: tint),
    );
  }
}
