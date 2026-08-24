import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../shared/providers/app_providers.dart';
import '../pages/travel_mode_page.dart';
import '../providers/travel_provider.dart';

/// Notices that the phone has ended up a long way from where the prayer times
/// are being calculated, and says so once.
///
/// Once is the whole design. An app that raises this every time a fix wobbles
/// teaches people to dismiss it unread, which is exactly the habit that makes
/// it useless on the day it matters — so a place that has been mentioned is
/// not mentioned again until the user has gone somewhere genuinely different.
class CityChangeBanner extends ConsumerStatefulWidget {
  const CityChangeBanner({super.key});

  @override
  ConsumerState<CityChangeBanner> createState() => _CityChangeBannerState();
}

class _CityChangeBannerState extends ConsumerState<CityChangeBanner> {
  @override
  void initState() {
    super.initState();
    // Fill in a home the first time there is a location to take one from,
    // so the distance has something to be measured against.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(travelProvider.notifier).adoptHomeIfUnset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nudge = ref.watch(locationNudgeProvider);
    if (nudge == LocationNudge.none) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;
    final settings = ref.watch(travelProvider);
    final pinnedLabel = ref.watch(locationLabelProvider).value ?? '';

    final isPin = nudge == LocationNudge.pinnedElsewhere;
    final anchor =
        isPin
            ? (pinnedLabel.isEmpty
                ? context.tr('location_unknown')
                : pinnedLabel)
            : (settings.homeLabel.isEmpty
                ? context.tr('travel_home')
                : settings.homeLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        accent: tokens.gold.withValues(alpha: 0.13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPin
                      ? Icons.wrong_location_outlined
                      : Icons.flight_takeoff_rounded,
                  size: 19,
                  color: tokens.gold,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr('city_change_title'),
                    style: AppTextStyles.body(context, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPin
                  ? AppLocalizations.translate(
                    language,
                    'city_change_body',
                    replacements: {'home': anchor},
                  )
                  : AppLocalizations.translate(
                    language,
                    'travel_within_or_beyond_prompt',
                    replacements: {'home': anchor},
                  ),
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _dismiss,
                  child: Text(context.tr('city_change_dismiss')),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: isPin ? _adoptHere : _openTravel,
                  child: Text(
                    context.tr(isPin ? 'city_change_accept' : 'travel_mode'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Remember this place so the question is not put again while the user
  /// stays here — without changing anything they did not ask to change.
  Future<void> _dismiss() async {
    final device = ref.read(deviceCoordinatesProvider).value;
    if (device == null) {
      return;
    }
    await ref
        .read(travelProvider.notifier)
        .markAsked(device.latitude, device.longitude);
  }

  Future<void> _adoptHere() async {
    await _dismiss();
    await ref.read(travelProvider.notifier).adoptCurrentLocation();
  }

  Future<void> _openTravel() async {
    await _dismiss();
    if (mounted) {
      await TravelModePage.open(context);
    }
  }
}
