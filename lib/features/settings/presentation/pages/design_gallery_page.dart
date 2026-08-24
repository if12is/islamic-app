import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/seasonal_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/arc_gauge.dart';
import '../../../../core/widgets/seasonal_art.dart';
import '../../../../core/widgets/seasonal_banner.dart';
import '../../../../core/widgets/ayah_block.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/islamic_icon.dart';
import '../../../../core/widgets/motif_icon.dart';
import '../../../../core/widgets/story_rail.dart';
import '../../../../shared/providers/app_providers.dart';

/// Every component in the library, on one screen.
///
/// A design system that can only be inspected by opening six real screens is a
/// design system nobody checks. Here each piece sits next to the others in
/// both moods and all four seasons, so a bad pairing shows up in seconds
/// instead of on the day it ships.
class DesignGalleryPage extends ConsumerStatefulWidget {
  const DesignGalleryPage({super.key});

  @override
  ConsumerState<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends ConsumerState<DesignGalleryPage> {
  final TextEditingController _search = TextEditingController();
  String _pill = 'surah';
  double _progress = 0.62;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final override = ref.watch(seasonalOverrideProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AppScaffold(
      title: 'design_gallery',
      showBack: true,
      body: ListView(
        padding: AppScaffold.scrollPadding,
        children: [
          Text(
            context.tr('design_gallery_desc'),
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Switch mood and season without leaving the page.
          Row(
            children: [
              Expanded(
                child: PillSelector<ThemeMode>(
                  scrollable: false,
                  compact: true,
                  value:
                      themeMode == ThemeMode.dark
                          ? ThemeMode.dark
                          : ThemeMode.light,
                  options: [
                    PillOption(
                      value: ThemeMode.light,
                      label: context.tr('light_mode'),
                      icon: Icons.light_mode,
                    ),
                    PillOption(
                      value: ThemeMode.dark,
                      label: context.tr('dark_mode_on'),
                      icon: Icons.dark_mode,
                    ),
                  ],
                  onChanged:
                      (mode) =>
                          ref.read(themeModeProvider.notifier).setTheme(mode),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _seasonChip(context, null, context.tr('seasonal_preview_auto')),
                for (final event in SeasonalEvent.values)
                  if (event != SeasonalEvent.none)
                    _seasonChip(
                      context,
                      event,
                      context.tr(SeasonalTheme.greetingKey(event)),
                    ),
              ],
            ),
          ),
          if (override != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: HintPill(
                text: context.tr('seasonal_preview_active'),
                icon: Icons.visibility_outlined,
                tone: HintTone.accent,
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          _label(context, 'Tokens'),
          _swatches(context, tokens),

          const SizedBox(height: AppSpacing.xl),
          _label(context, 'ArcGauge'),
          Center(
            child: ArcGauge(
              progress: _progress,
              headline: '٥:٤٨',
              caption: context.tr('maghrib'),
              startLabel: context.tr('asr'),
              startTime: '٣:٢٠',
              endLabel: context.tr('maghrib'),
              endTime: '٥:٤٨',
              footnote: 'دمنهور، البحيرة، مصر',
            ),
          ),
          Slider(
            value: _progress,
            onChanged: (value) => setState(() => _progress = value),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'StoryRail'),
          StoryRail(
            items: [
              StoryItem(
                icon: Icons.menu_book,
                label: context.tr('last_read'),
                onTap: () {},
                highlighted: true,
              ),
              StoryItem(
                icon: Icons.checklist_rtl,
                label: context.tr('daily_wird'),
                onTap: () {},
                badge: '٣',
              ),
              StoryItem(
                icon: Icons.explore_outlined,
                label: context.tr('qibla_direction'),
                onTap: () {},
              ),
              StoryItem(
                icon: Icons.radio_button_checked,
                label: context.tr('azkar_tasbeeh'),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'SeasonalBanner — one design per season'),
          for (final event in SeasonalEvent.values)
            if (event != SeasonalEvent.none)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SeasonalBanner(
                  event: event,
                  hijriDay: event == SeasonalEvent.ramadan ? 21 : null,
                ),
              ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'SeasonalHeroArt — onboarding only'),
          ClipRRect(
            borderRadius: AppRadii.lgAll,
            child: ColoredBox(
              color: tokens.brandDeep,
              child: SeasonalHeroArt(
                event: override ?? SeasonalEvent.ramadan,
                height: 220,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'AppCard + corners'),
          AppCard(
            corners: true,
            child: Text(
              'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.quran(context, fontSize: 24),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'HeroCard'),
          HeroCard(
            label: context.tr('last_read'),
            title: 'سورة البقرة',
            subtitle: 'الآية ٢٥٥ · صفحة ٤٢',
            actionLabel: context.tr('continue_reading'),
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          HeroCard(
            label: context.tr('season_ramadan_greeting'),
            title: 'رمضان كريم',
            subtitle: 'اليوم الحادي والعشرون',
            ornament: HeroOrnament.lantern,
            height: 118,
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'ProgressCard'),
          ProgressCard(
            title: context.tr('daily_wird'),
            subtitle: context.tr('wird_quran'),
            value: 0.4,
            trailingText: '٢/٥',
            icon: Icons.checklist_rtl,
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'SectionHeader + PillSelector'),
          SectionHeader(
            title: context.tr('quran'),
            trailing: PillSelector<String>(
              compact: true,
              value: _pill,
              options: [
                PillOption(value: 'surah', label: context.tr('surahs_tab')),
                PillOption(value: 'juz', label: context.tr('juz_tab')),
                PillOption(value: 'page', label: context.tr('pages_tab')),
              ],
              onChanged: (value) => setState(() => _pill = value),
            ),
          ),

          _label(context, 'AppListRow'),
          AppListRow(
            badge: '٠١',
            title: 'الفاتحة',
            meta: 'مكية · ٧ آيات',
            trailingText: 'ٱلْفَاتِحَة',
            onTap: () {},
          ),
          AppListRow(
            badge: '٠٢',
            title: 'البقرة',
            meta: 'مدنية · ٢٨٦ آية',
            trailingText: 'ٱلْبَقَرَة',
            selected: true,
            onTap: () {},
          ),

          const SizedBox(height: AppSpacing.md),
          _label(context, 'AyahBlock'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                AyahBlock(
                  numberLabel: '١:١',
                  arabic: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                  translation: 'In the name of Allah, the Entirely Merciful.',
                  actions: AyahBlock.defaultActions(
                    context,
                    onPlay: () {},
                    onBookmark: () {},
                    onShare: () {},
                    bookmarked: true,
                  ),
                ),
                AyahBlock(
                  numberLabel: '١:٢',
                  arabic: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
                  highlighted: true,
                  actions: AyahBlock.defaultActions(context, onPlay: () {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'HintPill'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              HintPill(text: 'أدر الهاتف ١٣٥° لليسار', icon: Icons.rotate_left),
              const HintPill(
                text: 'اتجاه القبلة صحيح',
                icon: Icons.check_circle,
                tone: HintTone.success,
              ),
              const HintPill(
                text: 'الليلة من العشر الأواخر',
                icon: Icons.nights_stay,
                tone: HintTone.accent,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Glass'),
          GlassSearchField(
            controller: _search,
            hintText: context.tr('search_surah_hint'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              context.tr('design_gallery_glass'),
              style: AppTextStyles.caption(context),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Icons — Tabler, MIT, bundled'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final icon in IslamicIcon.values)
                Column(
                  children: [
                    AppIconBadge(icon, size: 46),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 58,
                      child: Text(
                        icon.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(context, fontSize: 9.5),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Motifs — drawn, for large decoration'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final motif in Motif.values)
                Column(
                  children: [
                    MotifIcon(motif: motif, size: 52),
                    const SizedBox(height: 3),
                    Text(
                      motif.name,
                      style: AppTextStyles.caption(context, fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Buttons'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(onPressed: () {}, child: const Text('أساسي')),
              OutlinedButton(onPressed: () {}, child: const Text('ثانوي')),
              TextButton(onPressed: () {}, child: const Text('نصّي')),
              GhostIconButton(
                icon: Icons.play_arrow,
                tooltip: context.tr('play'),
                onTap: () {},
              ),
              GhostIconButton(
                icon: Icons.bookmark,
                tooltip: context.tr('bookmarks'),
                onTap: () {},
                active: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seasonChip(BuildContext context, SeasonalEvent? event, String label) {
    final tokens = context.tokens;
    final selected = ref.watch(seasonalOverrideProvider) == event;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => ref.read(seasonalOverrideProvider.notifier).set(event),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color:
                selected ? tokens.gold.withValues(alpha: 0.18) : tokens.surface,
            borderRadius: AppRadii.pillAll,
            boxShadow: AppShadows.soft(tokens.ink),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption(
              context,
              color: selected ? tokens.gold : tokens.inkMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppTextStyles.bodyFamily,
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: context.tokens.gold,
      ),
    ),
  );

  Widget _swatches(BuildContext context, AppTokens tokens) {
    final entries = <(String, Color)>[
      ('ground', tokens.ground),
      ('groundAlt', tokens.groundAlt),
      ('surface', tokens.surface),
      ('ink', tokens.ink),
      ('inkMuted', tokens.inkMuted),
      ('inkFaint', tokens.inkFaint),
      ('brand', tokens.brand),
      ('brandDeep', tokens.brandDeep),
      ('gold', tokens.gold),
      ('goldBright', tokens.goldBright),
      ('line', tokens.line),
      ('danger', tokens.danger),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (name, color) in entries)
          Column(
            children: [
              Container(
                width: 52,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadii.smAll,
                  border: Border.all(color: tokens.line),
                ),
              ),
              const SizedBox(height: 3),
              Text(name, style: AppTextStyles.caption(context, fontSize: 10)),
            ],
          ),
      ],
    );
  }
}
