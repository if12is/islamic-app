import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../shared/providers/app_text_scale_provider.dart';

/// Three sizes for the app's own text, each drawn at the size it sets.
///
/// A slider would be worse here even though it offers more: it asks for a
/// steady drag from the hand least able to give one, and it never says what
/// any position means. Three large buttons say what they do by being it — the
/// word "أكبر" is set larger than the word "كبير", so the choice is legible
/// before it is made rather than after.
class AppTextScaleCard extends ConsumerWidget {
  const AppTextScaleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final current = ref.watch(appTextScaleProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded, color: tokens.brand, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('app_text_size'),
                  style: AppTextStyles.display(context, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr('app_text_size_desc'),
            style: AppTextStyles.caption(context, color: tokens.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final scale in AppTextScale.values) ...[
                if (scale != AppTextScale.values.first)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ScaleChoice(
                    scale: scale,
                    selected: scale == current,
                    onTap:
                        () =>
                            ref.read(appTextScaleProvider.notifier).set(scale),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScaleChoice extends StatelessWidget {
  const _ScaleChoice({
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final AppTextScale scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: context.tr(scale.labelKey),
      child: Material(
        color: selected ? tokens.brand : tokens.groundAlt,
        borderRadius: AppRadii.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: Container(
            // Tall enough to be hit without aiming, which is the whole point
            // of the control.
            constraints: const BoxConstraints(minHeight: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Text(
              context.tr(scale.labelKey),
              textAlign: TextAlign.center,
              maxLines: 1,
              // Its own size, not the app's: this button is a sample of what
              // choosing it does. Scaling it again with the setting it sets
              // would make the row jump about as the reader tried each one.
              textScaler: TextScaler.noScaling,
              style: AppTextStyles.display(
                context,
                fontSize: 14 * scale.factor,
                color:
                    selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : tokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
