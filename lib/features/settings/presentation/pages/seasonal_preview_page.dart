import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/seasonal_intro_service.dart';
import '../../../../core/services/seasonal_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/seasonal_banner.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../onboarding/presentation/pages/seasonal_intro_screen.dart';

/// Wear any season on any day, so the seasonal dressing can be checked before
/// the day it actually arrives.
///
/// Each season is picked one at a time and the whole app changes with it —
/// colours, banner, ornaments — and its opening film can be played on demand.
/// The choice survives a restart on purpose, so it can be tested on a real
/// device; the home screen shows a strip whenever it is on so it cannot be
/// forgotten.
class SeasonalPreviewPage extends ConsumerWidget {
  const SeasonalPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(seasonalOverrideProvider);
    final active = ref.watch(seasonalEventProvider);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('seasonal_preview'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            context.tr('seasonal_preview_desc'),
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: 18),
          _option(
            context,
            ref,
            event: null,
            selected: override == null,
            title: context.tr('seasonal_preview_auto'),
            subtitle:
                active == SeasonalEvent.none
                    ? context.tr('seasonal_preview_auto_none')
                    : context.tr(SeasonalTheme.greetingKey(active)),
          ),
          for (final event in SeasonalEvent.values)
            if (event != SeasonalEvent.none)
              _option(
                context,
                ref,
                event: event,
                selected: override == event,
                title: context.tr(SeasonalTheme.greetingKey(event)),
                subtitle:
                    SeasonalIntroService.assetFor(event) == null
                        ? context.tr('seasonal_preview_no_intro')
                        : context.tr('seasonal_preview_has_intro'),
              ),
          const SizedBox(height: 24),
          Text(
            context.tr('seasonal_preview_live'),
            style: AppTextStyles.display(context, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SeasonalBanner(event: active, hijriDay: 21),
          if (active == SeasonalEvent.none) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('seasonal_preview_auto_none'),
              style: AppTextStyles.caption(context),
            ),
          ],
          const SizedBox(height: 20),
          _swatches(context, active),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    WidgetRef ref, {
    required SeasonalEvent? event,
    required bool selected,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = event == null ? null : SeasonalTheme.paletteFor(event);
    final hasIntro =
        event != null && SeasonalIntroService.assetFor(event) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            selected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => ref.read(seasonalOverrideProvider.notifier).set(event),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    palette == null
                        ? null
                        : LinearGradient(colors: palette.bannerColors),
                color:
                    palette == null
                        ? colorScheme.surfaceContainerHighest
                        : null,
                border: Border.all(
                  color: palette?.ornament ?? colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child:
                  palette == null
                      ? Icon(
                        Icons.auto_mode,
                        size: 20,
                        color: colorScheme.primary,
                      )
                      : null,
            ),
            title: Text(
              title,
              style: AppTextStyles.display(context, fontSize: 16),
            ),
            subtitle: Text(subtitle, style: AppTextStyles.caption(context)),
            trailing:
                selected
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : null,
          ),
          if (hasIntro)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 16,
                bottom: 12,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => _playIntro(context, event),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(context.tr('seasonal_preview_play')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The colours this season pushes into the theme, so a bad pairing shows up
  /// here rather than on the day itself.
  Widget _swatches(BuildContext context, SeasonalEvent event) {
    final palette = SeasonalTheme.paletteFor(event);
    if (palette == null) {
      return const SizedBox.shrink();
    }

    final entries = <(String, Color)>[
      ('accent', palette.accent),
      ('bright', palette.accentBright),
      ('hero 1', palette.heroGradient.first),
      ('hero 2', palette.heroGradient.last),
      ('bg 1', palette.bannerColors.first),
      ('bg 2', palette.bannerColors.last),
      ('ornament', palette.ornament),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, color) in entries)
          Column(
            children: [
              Container(
                width: 54,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.caption(context, fontSize: 11)),
            ],
          ),
      ],
    );
  }

  void _playIntro(BuildContext context, SeasonalEvent event) {
    final asset = SeasonalIntroService.assetFor(event);
    if (asset == null) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder:
            (routeContext, animation, _) => FadeTransition(
              opacity: animation,
              child: SeasonalIntroScreen(
                assetPath: asset,
                event: event,
                onFinished: () => Navigator.of(routeContext).maybePop(),
              ),
            ),
      ),
    );
  }
}
