import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/tafsir_service.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/tafsir_provider.dart';

/// Tafsir for a single verse, with a switcher across editions.
///
/// The first time a surah is opened online its tafsir is cached permanently,
/// so re-reading it later works offline.
class TafsirSheet extends ConsumerWidget {
  const TafsirSheet({super.key, required this.verse});

  final QuranVerse verse;

  static Future<void> show(BuildContext context, QuranVerse verse) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TafsirSheet(verse: verse),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editionId = ref.watch(tafsirEditionProvider);
    final settings = ref.watch(readerSettingsProvider);
    final tafsir = ref.watch(
      tafsirTextProvider(
        TafsirRequest(
          editionId: editionId,
          surahNumber: verse.surahNumber,
          verseNumber: verse.numberInSurah,
        ),
      ),
    );

    return Directionality(
      textDirection: context.appTextDirection,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                '${context.tr('tafsir')} · ${context.tr('surah_word')} '
                '${verse.surahNameAr} ${verse.numberInSurah}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  verse.text,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: settings.font.family,
                    fontSize: settings.fontSize * 0.8,
                    height: 1.9,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: TafsirService.editions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final edition = TafsirService.editions[index];
                    return ChoiceChip(
                      selected: edition.id == editionId,
                      onSelected: (_) => ref
                          .read(tafsirEditionProvider.notifier)
                          .select(edition.id),
                      label: Text(
                        context.isAppRtl ? edition.nameAr : edition.nameEn,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              tafsir.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
                error: (_, _) => _message(context, 'tafsir_unavailable'),
                data: (text) {
                  if (text == null || text.isEmpty) {
                    return _message(context, 'tafsir_unavailable');
                  }
                  return Text(
                    text,
                    textAlign: TextAlign.justify,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.9,
                      fontSize: 16,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _message(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(key),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
