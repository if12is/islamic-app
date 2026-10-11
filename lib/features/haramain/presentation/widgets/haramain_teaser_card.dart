import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../domain/haramain_roster.dart';
import '../../domain/haramain_week.dart';
import '../pages/haramain_imams_page.dart';
import '../providers/haramain_provider.dart';

/// The way in to the imams page, from the recordings shelf.
///
/// Reads the stored week only, so showing the card never costs a request; the
/// page does the refreshing. With a week stored it previews who leads
/// Maghrib and Isha at al-Haram this week.
class HaramainTeaserCard extends ConsumerWidget {
  const HaramainTeaserCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final week = ref.watch(haramainCachedWeekProvider).asData?.value;
    final english = Localizations.localeOf(context).languageCode != 'ar';

    String name(HaramainPrayer prayer) {
      final entry = week?.haram[prayer];
      if (entry == null) {
        return '';
      }
      return english
          ? (haramainImamById(entry.rosterId)?.nameEn ?? entry.displayName)
          : entry.displayName;
    }

    final teaser =
        week == null
            ? context.tr('haramain_each_prayer')
            : '${context.tr('maghrib')}: ${name(HaramainPrayer.maghrib)}'
                '\n${context.tr('isha')}: ${name(HaramainPrayer.isha)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => HaramainImamsPage.open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(Icons.mosque_rounded, color: tokens.brand, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('haramain_title'),
                      style: AppTextStyles.display(context, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teaser,
                      style: AppTextStyles.body(
                        context,
                        fontSize: 15,
                        color: tokens.inkMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                context.isAppRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: tokens.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
