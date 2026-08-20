import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/qibla_math.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/providers/app_providers.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/qibla_compass.dart';

/// The qibla, on its own screen.
///
/// Everything here answers one question, so nothing else competes for the
/// space: which way to turn. The place is named at the top — a prayer
/// direction computed from coordinates the user cannot read is a direction
/// they cannot check.
class QiblaPage extends ConsumerWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final coordinatesAsync = ref.watch(currentLocationCoordinatesProvider);
    final label = ref.watch(locationLabelProvider).value ?? '';

    return AppScaffold(
      title: 'qibla_direction',
      showBack: true,
      body: coordinatesAsync.when(
        loading: () => const Center(child: CustomLoader()),
        error:
            (_, _) => Center(
              child: Text(
                context.tr('location_unknown'),
                style: AppTextStyles.body(context),
              ),
            ),
        data: (coordinates) {
          final bearing = QiblaMath.bearingTo(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          );
          final distance = QiblaMath.distanceToKaabaKm(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          );

          return ListView(
            padding: AppScaffold.scrollPadding,
            children: [
              Center(
                child: _LocationChip(
                  label: label.isEmpty ? context.tr('location_unknown') : label,
                  onTap: () => LocationPickerSheet.show(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: QiblaCompass(
                  qiblaBearing: bearing,
                  alignedText: context.tr('qibla_correct_direction'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _Fact(
                      icon: Icons.explore_outlined,
                      label: context.tr('qibla_bearing'),
                      value: '${bearing.round()}°',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Fact(
                      icon: Icons.straighten,
                      label: context.tr('qibla_distance'),
                      value:
                          '${distance.round()} '
                          '${context.tr('kilometre_short')}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr('qibla_precision_desc'),
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(context, color: tokens.inkFaint),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: AppRadii.pillAll,
          boxShadow: AppShadows.soft(tokens.ink),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 16, color: tokens.brand),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  context,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.expand_more, size: 16, color: tokens.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.inkFaint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkFaint,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.display(context, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
