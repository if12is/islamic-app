import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Frosted-glass surface used by the nav bar, search fields, and floating bars.
///
/// The blur is what makes it read as glass, so the widget must sit above
/// something — a scrolling list, an image — rather than a flat background.
/// Tints and borders are derived from the theme, so light and dark both look
/// deliberate instead of one being an inversion of the other.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.lg,
    this.blur = 18,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.opacity,
    this.showBorder = true,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// Tint strength; defaults to what suits the current brightness.
  final double? opacity;

  final bool showBorder;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(borderRadius);

    // The tint comes from the tokens so seasonal dressing reaches the glass
    // too, and so light glass never turns muddy over the warm ground.
    final tint =
        opacity == null
            ? tokens.glassTint
            : tokens.glassTint.withValues(alpha: opacity!);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ? AppShadows.lift(tokens.ink) : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: radius,
              border:
                  showBorder
                      ? Border.all(color: tokens.glassEdge, width: 1)
                      : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass search field, so search looks the same everywhere it appears.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GlassContainer(
      borderRadius: AppRadii.pill,
      blur: 14,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: tokens.ink, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: tokens.inkFaint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: tokens.inkFaint, size: 20),
          suffixIcon:
              controller.text.isEmpty
                  ? null
                  : IconButton(
                    icon: Icon(Icons.close, color: tokens.inkFaint, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onClear?.call();
                    },
                  ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
