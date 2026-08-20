import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';

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
              _preview(context, settings, palette),
              const SizedBox(height: 24),

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
                max: 3.0,
                divisions: 14,
                display: '${settings.autoScrollSpeed.toStringAsFixed(1)}×',
                onChanged: notifier.setAutoScrollSpeed,
              ),

              const SizedBox(height: 8),
              _label(context, 'reciter'),
              DropdownButtonFormField<String>(
                initialValue: settings.reciterCode,
                isExpanded: true,
                items: [
                  for (final reciter in QuranReciter.all)
                    DropdownMenuItem(
                      value: reciter.code,
                      child: Text(
                        context.isAppRtl ? reciter.nameAr : reciter.nameEn,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  notifier.setReciter(value);
                  ref.read(quranAudioProvider.notifier).setReciter(value);
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
