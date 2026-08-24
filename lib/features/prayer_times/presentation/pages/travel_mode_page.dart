import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/travel.dart';
import '../providers/travel_provider.dart';

/// Travel mode: what changes about the prayers, and where the times are for.
///
/// The app measures the distance and says what it measured. It does not decide
/// that someone is a traveller — that turns on the intention to travel and the
/// intention to stay, neither of which a phone can read, and both of which
/// change the ruling. So the switch stays in the user's hand and the screen's
/// job is to give them the two facts they need to work it: how far they are,
/// and what shortening actually means.
class TravelModePage extends ConsumerWidget {
  const TravelModePage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TravelModePage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final settings = ref.watch(travelProvider);
    final assessment = ref.watch(travelAssessmentProvider);
    final language = Localizations.localeOf(context).languageCode;
    final here = ref.watch(locationLabelProvider).value ?? '';

    return AppScaffold(
      title: 'travel_mode',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.navClearance,
        ),
        children: [
          _DistanceCard(assessment: assessment, here: here),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.travelling,
                  onChanged:
                      (value) => ref
                          .read(travelProvider.notifier)
                          .setTravelling(value),
                  title: Text(
                    context.tr('travel_switch'),
                    style: AppTextStyles.body(context, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    context.tr('travel_switch_desc'),
                    style: AppTextStyles.caption(context),
                  ),
                ),
                if (settings.travelling && (settings.daysAway ?? 0) >= 4) ...[
                  const SizedBox(height: AppSpacing.sm),
                  // Not an instruction to stop shortening — the four days run
                  // from an intention to reside, and someone still moving is
                  // still travelling. It is a question worth putting, because
                  // a switch left on is a switch nobody thinks about again.
                  HintPill(
                    icon: Icons.schedule_rounded,
                    tone: HintTone.accent,
                    text: AppLocalizations.translate(
                      language,
                      'travel_days_note',
                      replacements: {'days': '${settings.daysAway}'},
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: context.tr('travel_home'),
            subtitle: context.tr('travel_home_desc'),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_rounded, size: 20, color: tokens.brand),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        settings.homeLabel.isEmpty
                            ? context.tr('travel_home_unset')
                            : settings.homeLabel,
                        style: AppTextStyles.body(context, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed:
                        () =>
                            ref
                                .read(travelProvider.notifier)
                                .setHomeToCurrent(),
                    icon: const Icon(Icons.my_location_rounded, size: 17),
                    label: Text(context.tr('travel_set_home')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: context.tr('travel_threshold'),
            subtitle: context.tr('travel_threshold_desc'),
          ),
          PillSelector<double>(
            value: settings.thresholdKm,
            onChanged:
                (value) =>
                    ref.read(travelProvider.notifier).setThreshold(value),
            options: [
              for (final km in TravelDistance.choices)
                PillOption(
                  value: km,
                  label: '${_km(km)} ${context.tr('unit_km')}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: context.tr('travel_what_changes')),
          const _RulingCard(),
          const SizedBox(height: AppSpacing.lg),

          Text(
            context.tr('travel_disclaimer'),
            style: AppTextStyles.caption(context, color: tokens.inkFaint),
          ),
        ],
      ),
    );
  }

  static String _km(double value) =>
      value == value.roundToDouble()
          ? '${value.round()}'
          : value.toStringAsFixed(1);
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.assessment, required this.here});

  final TravelAssessment assessment;
  final String here;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;

    if (!assessment.hasHome) {
      return AppCard(
        child: Text(
          context.tr('travel_no_home_yet'),
          style: AppTextStyles.body(context, fontSize: 13.5),
        ),
      );
    }

    final distance = assessment.distanceKm;
    final beyond = assessment.beyondThreshold;

    return AppCard(
      // A tint, not the solid gold: `accent` replaces the card colour outright,
      // and the ink on this card is sized for a surface, not for a gold field.
      accent: beyond ? tokens.gold.withValues(alpha: 0.14) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            here.isEmpty ? context.tr('travel_current_place') : here,
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                distance < 10
                    ? distance.toStringAsFixed(1)
                    : '${distance.round()}',
                style: AppTextStyles.display(context, fontSize: 32),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.tr('travel_km_from_home'),
                style: AppTextStyles.caption(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          HintPill(
            icon:
                beyond
                    ? Icons.flight_takeoff_rounded
                    : Icons.home_work_outlined,
            tone: beyond ? HintTone.accent : HintTone.neutral,
            text:
                beyond
                    ? context.tr('travel_beyond_threshold')
                    : AppLocalizations.translate(
                      language,
                      'travel_within_threshold',
                      replacements: {
                        'remaining':
                            assessment.remainingKm < 10
                                ? assessment.remainingKm.toStringAsFixed(1)
                                : '${assessment.remainingKm.round()}',
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// What shortening and joining mean, prayer by prayer.
class _RulingCard extends StatelessWidget {
  const _RulingCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in PrayerIds.obligatory) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    context.tr(id),
                    style: AppTextStyles.body(context, fontSize: 13.5),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    _rakaatText(context, id),
                    style: AppTextStyles.caption(
                      context,
                      color:
                          TravelRuling.changeFor(id) ==
                                  TravelPrayerChange.shortened
                              ? tokens.brand
                              : tokens.inkFaint,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    _joinText(context, id),
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            if (id != PrayerIds.obligatory.last)
              Divider(height: AppSpacing.lg, color: tokens.line),
          ],
        ],
      ),
    );
  }

  static String _rakaatText(BuildContext context, String id) {
    final home = TravelRuling.rakaatAtHome(id);
    final away = TravelRuling.rakaatTravelling(id);
    final unit = context.tr('rakaat');

    if (home == away) {
      return '$home $unit · ${context.tr('travel_unchanged')}';
    }
    return '$home → $away $unit';
  }

  static String _joinText(BuildContext context, String id) {
    final partner = TravelRuling.joinPartner(id);
    if (partner == null) {
      return context.tr('travel_no_join');
    }
    return '${context.tr('travel_joins_with')} ${context.tr(partner)}';
  }
}
