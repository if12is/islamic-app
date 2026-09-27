import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/arabic_numerals.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../data/services/mushaf_service.dart';
import '../../domain/entities/riwaya.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import 'recitation_picker_sheet.dart';
import 'tajweed_text.dart';

/// The reading control panel: typography, surface, motion, and reciter.
///
/// Everything here previews live against the verse sample at the top, so the
/// reader can see the effect before closing the sheet.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final palette = settings.paletteFor(context);

    return Directionality(
      textDirection: context.appTextDirection,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                context.tr('reader_settings'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const _RiwayaSection(),
              const SizedBox(height: 24),
              _preview(context, settings, palette),
              const SizedBox(height: 24),

              if (!context.isAppRtl) ...[
                _label(context, 'quran_verse_language'),
                SegmentedButton<VerseLanguage>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: VerseLanguage.arabic,
                      label: Text(context.tr('quran_verse_arabic')),
                    ),
                    ButtonSegment(
                      value: VerseLanguage.english,
                      label: Text(context.tr('quran_verse_english')),
                    ),
                  ],
                  selected: {settings.verseLanguage},
                  onSelectionChanged:
                      (value) => notifier.setVerseLanguage(value.first),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('quran_verse_english_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
              ],

              _label(context, 'reader_view_mode'),
              SegmentedButton<ReaderViewMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ReaderViewMode.continuous,
                    icon: const Icon(Icons.view_stream, size: 18),
                    label: Text(context.tr('view_continuous')),
                  ),
                  ButtonSegment(
                    value: ReaderViewMode.pages,
                    icon: const Icon(Icons.auto_stories, size: 18),
                    label: Text(context.tr('view_pages')),
                  ),
                ],
                selected: {settings.viewMode},
                onSelectionChanged:
                    (value) => notifier.setViewMode(value.first),
              ),
              const SizedBox(height: 20),

              _label(context, 'reader_font'),
              SegmentedButton<ReaderFont>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ReaderFont.amiriQuran,
                    label: Text(context.tr('font_amiri')),
                  ),
                  ButtonSegment(
                    value: ReaderFont.scheherazade,
                    label: Text(context.tr('font_scheherazade')),
                  ),
                  ButtonSegment(
                    value: ReaderFont.cairo,
                    label: Text(context.tr('font_cairo')),
                  ),
                ],
                selected: {settings.font},
                onSelectionChanged: (value) => notifier.setFont(value.first),
              ),
              const SizedBox(height: 20),

              _slider(
                context,
                labelKey: 'font_size',
                value: settings.fontSize,
                min: 18,
                max: 56,
                divisions: 19,
                display: settings.fontSize.round().toString(),
                onChanged: notifier.setFontSize,
              ),
              _slider(
                context,
                labelKey: 'line_spacing',
                value: settings.lineHeight,
                min: 1.6,
                max: 3.4,
                divisions: 18,
                display: settings.lineHeight.toStringAsFixed(1),
                onChanged: notifier.setLineHeight,
              ),
              _slider(
                context,
                labelKey: 'page_margins',
                value: settings.horizontalPadding,
                min: 8,
                max: 48,
                divisions: 10,
                display: settings.horizontalPadding.round().toString(),
                onChanged: notifier.setHorizontalPadding,
              ),

              const SizedBox(height: 8),
              _label(context, 'reading_theme'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final theme in ReaderTheme.values)
                    _themeSwatch(context, ref, settings, theme),
                ],
              ),
              const SizedBox(height: 20),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: settings.showVerseNumbers,
                onChanged: notifier.setShowVerseNumbers,
                title: Text(context.tr('show_verse_numbers')),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: settings.showTajweed,
                onChanged: notifier.setShowTajweed,
                title: Text(context.tr('show_tajweed')),
                subtitle: Text(context.tr('show_tajweed_desc')),
              ),
              if (settings.showTajweed)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed:
                        () => TajweedKeySheet.show(
                          context,
                          isDark: settings.paletteFor(context).isDark,
                        ),
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    label: Text(context.tr('tajweed_key')),
                  ),
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: settings.keepScreenOn,
                onChanged: notifier.setKeepScreenOn,
                title: Text(context.tr('keep_screen_on')),
                subtitle: Text(context.tr('keep_screen_on_desc')),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: settings.brightnessOverride != null,
                onChanged:
                    (value) =>
                        notifier.setBrightnessOverride(value ? 0.6 : null),
                title: Text(context.tr('lock_brightness')),
              ),
              if (settings.brightnessOverride != null)
                _slider(
                  context,
                  labelKey: 'brightness',
                  value: settings.brightnessOverride!,
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  display: '${(settings.brightnessOverride! * 100).round()}%',
                  onChanged: notifier.setBrightnessOverride,
                ),

              const Divider(height: 32),
              _slider(
                context,
                labelKey: 'auto_scroll_speed',
                value: settings.autoScrollSpeed,
                min: 0.2,
                // The top of the old range was still a crawl on a long surah.
                max: 8.0,
                divisions: 39,
                display: '${settings.autoScrollSpeed.toStringAsFixed(1)}×',
                onChanged: notifier.setAutoScrollSpeed,
              ),

              const SizedBox(height: 8),
              ReciterChooser(
                selectedId: settings.reciterCode,
                edition: settings.edition,
                onSelected: (voice) {
                  notifier.setReciter(voice.id);
                  ref.read(quranAudioProvider.notifier).setReciter(voice.id);
                },
              ),

              const SizedBox(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: notifier.resetToDefaults,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(context.tr('reset_defaults')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _preview(
    BuildContext context,
    ReaderSettings settings,
    ReaderPalette palette,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: settings.horizontalPadding,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        'وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِلْمُؤْمِنِينَ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: settings.font.family,
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: palette.text,
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        context.tr(key),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String labelKey,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required void Function(double value) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(labelKey),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(display, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _themeSwatch(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
    ReaderTheme theme,
  ) {
    final palette = settings.copyWith(theme: theme).paletteFor(context);
    final selected = settings.theme == theme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => ref.read(readerSettingsProvider.notifier).setTheme(theme),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              'الٓمٓ',
              style: TextStyle(
                fontFamily: ReaderFont.amiriQuran.family,
                fontSize: 20,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('reading_theme_${theme.name}'),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many of a fetched mushaf's 114 surahs are already on this device.
String _mushafOnDeviceLine(BuildContext context, int done) {
  return AppLocalizations.translate(
    Localizations.localeOf(context).languageCode,
    'mushaf_on_device',
    replacements: {
      'done': localizeDigits(context, '$done'),
      'total': localizeDigits(context, '114'),
    },
  );
}

/// The reading switch. It sits above font and spacing because it changes
/// the words on the page, not only how they look.
class _RiwayaSection extends ConsumerStatefulWidget {
  const _RiwayaSection();

  @override
  ConsumerState<_RiwayaSection> createState() => _RiwayaSectionState();
}

class _RiwayaSectionState extends ConsumerState<_RiwayaSection> {
  int? _cached;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCount());
  }

  Future<void> _refreshCount() async {
    final edition = ref.read(readerSettingsProvider).edition;
    if (!MushafService.supports(edition)) {
      if (mounted) {
        setState(() => _cached = null);
      }
      return;
    }
    try {
      final count = await MushafService.cachedCount(edition);
      if (mounted) {
        setState(() => _cached = count);
      }
    } catch (e) {
      AppLogger.warning('Could not count cached mushaf surahs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final tokens = context.tokens;

    ref.listen<MushafEdition>(
      readerSettingsProvider.select((value) => value.edition),
      (previous, next) => _refreshCount(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            context.tr('riwaya'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final edition in MushafEdition.values) ...[
          _RiwayaCard(
            edition: edition,
            selected: settings.edition == edition,
            onTap: () => notifier.setEdition(edition),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (MushafService.supports(settings.edition) && _cached != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _mushafOnDeviceLine(context, _cached!),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _RiwayaCard extends StatelessWidget {
  const _RiwayaCard({
    required this.edition,
    required this.selected,
    required this.onTap,
  });

  final MushafEdition edition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Keyed off the edition's own id so adding a reading is one enum value and
    // one string, not another branch in a conditional that quietly shows the
    // wrong note for anything it has not been taught.
    final note = context.tr('riwaya_${edition.id}_note');

    return Semantics(
      selected: selected,
      child: AppCard(
        raised: selected,
        accent: selected ? tokens.brandSoft : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 28,
                color: selected ? tokens.brand : tokens.inkFaint,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      edition.nameAr,
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.body(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      note,
                      style: AppTextStyles.caption(
                        context,
                        fontSize: 14,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
