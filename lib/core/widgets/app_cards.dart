import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/design_tokens.dart';
import 'islamic_ornaments.dart';

/// The plain card everything else is built on: a surface, a big radius, and a
/// soft shadow. No border — space and elevation separate, not rules.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.raised = false,
    this.radius = AppRadii.lg,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Sits on top of another card.
  final bool raised;
  final double radius;

  /// Tints the surface, for "this one is live".
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ?? (raised ? tokens.surfaceRaised : tokens.surface),
        borderRadius: borderRadius,
        boxShadow: AppShadows.soft(tokens.ink),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The gold card that opens a screen.
///
/// One per screen at most. It is the only place a large block of accent colour
/// is allowed, which is exactly why it pulls the eye. Text on it is deep ink,
/// never white: gold and white fail contrast in daylight.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.onTap,
    this.actionLabel,
    this.ornament = HeroOrnament.mosque,
    this.height = 132,
  });

  /// The small line above the title ("Last read").
  final String label;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? actionLabel;
  final HeroOrnament ornament;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.lgAll,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: tokens.heroGradient,
        ),
        boxShadow: AppShadows.lift(tokens.ink),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // A minimum, never a maximum: the card grows for a long surah name
            // or a second line of Arabic rather than clipping it.
            constraints: BoxConstraints(minHeight: height),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -10,
                  bottom: -6,
                  top: 6,
                  width: 190,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HeroOrnamentPainter(
                        ornament: ornament,
                        color: tokens.onGold.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.caption(
                          context,
                          color: tokens.onGold.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(
                          context,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: tokens.onGold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption(
                            context,
                            color: tokens.onGold.withValues(alpha: 0.82),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      if (actionLabel != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.onGold.withValues(alpha: 0.14),
                            borderRadius: AppRadii.pillAll,
                          ),
                          child: Text(
                            actionLabel!,
                            style: TextStyle(
                              fontFamily: AppTextStyles.bodyFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.onGold,
                            ),
                          ),
                        ),
                      ],
                    ],
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

enum HeroOrnament { mosque, lantern, book, crescent }

class _HeroOrnamentPainter extends CustomPainter {
  const _HeroOrnamentPainter({required this.ornament, required this.color});

  final HeroOrnament ornament;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    switch (ornament) {
      case HeroOrnament.mosque:
        _mosque(canvas, size, paint);
      case HeroOrnament.lantern:
        IslamicOrnaments.lantern(
          canvas,
          top: Offset(size.width * 0.34, -4),
          width: 46,
          cordLength: 26,
          color: color,
        );
        IslamicOrnaments.lantern(
          canvas,
          top: Offset(size.width * 0.62, -4),
          width: 34,
          cordLength: 52,
          color: color,
        );
      case HeroOrnament.book:
        _book(canvas, size, paint);
      case HeroOrnament.crescent:
        IslamicOrnaments.crescent(
          canvas,
          Offset(size.width * 0.5, size.height * 0.44),
          size.height * 0.30,
          color,
        );
    }
  }

  /// A skyline: one dome, two minarets, an arcade of arches.
  void _mosque(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * 0.86;
    final centre = size.width * 0.5;
    final domeRadius = size.height * 0.20;

    canvas.drawCircle(
      Offset(centre, baseY - domeRadius * 1.6),
      domeRadius,
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        centre - domeRadius,
        baseY - domeRadius * 1.6,
        centre + domeRadius,
        baseY,
      ),
      paint,
    );
    IslamicOrnaments.crescent(
      canvas,
      Offset(centre, baseY - domeRadius * 3.2),
      domeRadius * 0.42,
      color,
    );

    for (final dx in [-1.0, 1.0]) {
      final x = centre + dx * domeRadius * 2.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 7, baseY - size.height * 0.55, x + 7, baseY),
          const Radius.circular(7),
        ),
        paint,
      );
    }

    for (var i = -2; i <= 2; i++) {
      final x = centre + i * 26.0;
      final rect = Rect.fromLTRB(x - 9, baseY - 26, x + 9, baseY);
      canvas.drawPath(IslamicOrnaments.archPath(rect, pointHeight: 0.5), paint);
    }
  }

  /// An open book, for reading progress.
  void _book(Canvas canvas, Size size, Paint paint) {
    final centre = Offset(size.width * 0.5, size.height * 0.56);
    final width = size.width * 0.34;
    final height = size.height * 0.32;

    for (final side in [-1.0, 1.0]) {
      final path =
          Path()
            ..moveTo(centre.dx, centre.dy - height * 0.7)
            ..quadraticBezierTo(
              centre.dx + side * width * 0.6,
              centre.dy - height,
              centre.dx + side * width,
              centre.dy - height * 0.55,
            )
            ..lineTo(centre.dx + side * width, centre.dy + height * 0.55)
            ..quadraticBezierTo(
              centre.dx + side * width * 0.6,
              centre.dy + height * 0.2,
              centre.dx,
              centre.dy + height * 0.5,
            )
            ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroOrnamentPainter old) =>
      old.ornament != ornament || old.color != color;
}

/// A habit card: what it is, how far along, and how many are left.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.trailingText,
    this.icon = Icons.check_circle_outline,
    this.onTap,
    this.accent,
  });

  final String title;
  final String subtitle;

  /// 0 to 1.
  final double value;

  /// "6/30" — the same information as the bar, for people who want the number.
  final String trailingText;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colour = accent ?? tokens.brand;
    final ratio = value.clamp(0.0, 1.0);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.14),
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, size: 19, color: colour),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.display(
                        context,
                        fontSize: 16,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailingText,
                style: AppTextStyles.display(
                  context,
                  fontSize: 15,
                  color: colour,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: AppMotion.slow,
              curve: AppMotion.enter,
              builder:
                  (context, animated, _) => LinearProgressIndicator(
                    value: animated,
                    minHeight: 8,
                    backgroundColor: tokens.groundAlt,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one row every list in the app uses.
///
/// Before this existed the surah row, the juz row, the dhikr row and the
/// download row were four pieces of code doing the same job, which meant four
/// places to change and four ways to drift apart.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.badge,
    this.leading,
    this.meta,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.selected = false,
    this.dense = false,
  });

  /// The small number in a rounded square (surah index, juz number).
  final String? badge;

  /// Used instead of [badge] when an icon fits better.
  final Widget? leading;

  final String title;

  /// "Meccan · 7 verses".
  final String? meta;

  final Widget? trailing;

  /// A short string on the far side — often the Arabic name of a surah.
  final String? trailingText;

  final VoidCallback? onTap;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        accent: selected ? tokens.brand.withValues(alpha: 0.10) : null,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: dense ? AppSpacing.sm + 2 : AppSpacing.md,
        ),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (badge != null)
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? tokens.brand.withValues(alpha: 0.16)
                          : tokens.groundAlt,
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  badge!,
                  style: AppTextStyles.display(
                    context,
                    fontSize: 14,
                    color: selected ? tokens.brand : tokens.inkMuted,
                  ),
                ),
              ),
            if (leading != null || badge != null)
              const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.display(
                      context,
                      fontSize: 15.5,
                      color: tokens.ink,
                    ),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingText != null)
              ConstrainedBox(
                // A long Uthmani name would push the row apart otherwise.
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.quran(
                    context,
                    fontSize: 19,
                    height: 1.4,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
