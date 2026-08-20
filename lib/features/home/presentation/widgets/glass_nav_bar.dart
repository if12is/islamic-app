import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/seasonal_decor.dart';

/// One destination in the floating bar.
class GlassNavItem {
  const GlassNavItem({
    required this.tabIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Which tab this slot opens.
  final int tabIndex;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A floating, frosted navigation bar with a raised centre.
///
/// The middle destination — home — sits in a circle that lifts above the bar,
/// so the thumb finds it without looking and the shape says "this is the way
/// back". The rest stay as quiet icons; the bar carries no labels, which is
/// what keeps five destinations comfortable on a narrow phone.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Slots in visual order. The middle one is drawn raised.
  final List<GlassNavItem> items;

  /// The tab currently open.
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// How far the centre button lifts above the bar.
  static const double raise = 22;

  @override
  Widget build(BuildContext context) {
    final centre = items.length ~/ 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, raise, 18, 10),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            GlassContainer(
              borderRadius: AppRadii.lg + 2,
              blur: 22,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The season's ribbon is the bar's own top edge, not
                  // something hovering above it.
                  SeasonalNavFlourish(event: SeasonalDecorScope.of(context)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child:
                                i == centre
                                    // The raised button is drawn above; this keeps its
                                    // slot in the row so the spacing stays even.
                                    ? const SizedBox(height: 46)
                                    : _FlatDestination(
                                      item: items[i],
                                      isSelected:
                                          items[i].tabIndex == selectedIndex,
                                      onTap:
                                          () => onSelected(items[i].tabIndex),
                                    ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -raise,
              child: _RaisedDestination(
                item: items[centre],
                isSelected: items[centre].tabIndex == selectedIndex,
                onTap: () => onSelected(items[centre].tabIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain icon slot.
class _FlatDestination extends StatelessWidget {
  const _FlatDestination({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 23,
                color: isSelected ? tokens.brand : tokens.inkFaint,
              ),
              const SizedBox(height: 5),
              // A dot marks the open tab; a label would crowd five slots.
              AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.enter,
                width: isSelected ? 16 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lifted circle in the middle of the bar.
class _RaisedDestination extends StatelessWidget {
  const _RaisedDestination({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Green into gold: the identity holding the accent, which is the
            // whole palette in one 62-pixel circle.
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors:
                  isSelected
                      ? [tokens.brand, tokens.goldBright]
                      : [tokens.brand, tokens.brandDeep],
            ),
            // A ring in the page colour separates the circle from the bar,
            // the way a notch would.
            border: Border.all(color: tokens.ground, width: 4),
            boxShadow: AppShadows.glow(
              tokens.brand,
              alpha: isSelected ? 0.5 : 0.24,
            ),
          ),
          child: Icon(
            isSelected ? item.selectedIcon : item.icon,
            size: 27,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
