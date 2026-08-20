import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/audio_download_service.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/downloads_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';

/// The reciter library: pick a reciter, download surahs, listen offline.
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  late String _reciterCode = ref.read(readerSettingsProvider).reciterCode;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.tr('reciter_library'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      body: downloads.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final surahs = QuranLocalService.searchSurahs(_query);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<String>(
                  initialValue: _reciterCode,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('reciter')),
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
                    setState(() => _reciterCode = value);
                    ref.read(readerSettingsProvider.notifier).setReciter(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.tr('search_surah_or_number_hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              _storageRow(context, state),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return _surahTile(context, state, surah);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _storageRow(BuildContext context, DownloadsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.sd_storage_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.tr('downloads_size')}: '
              '${AudioDownloadService.formatBytes(state.totalBytes)} · '
              '${state.downloads.length}',
              style: AppTextStyles.caption(context),
            ),
          ),
          if (state.downloads.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(downloadsProvider.notifier).deleteAll(),
              child: Text(context.tr('downloads_clear')),
            ),
        ],
      ),
    );
  }

  Widget _surahTile(
    BuildContext context,
    DownloadsState state,
    QuranSurahInfo surah,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDownloaded = state.has(_reciterCode, surah.id);
    final progress = state.progressOf(_reciterCode, surah.id);
    final notifier = ref.read(downloadsProvider.notifier);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${surah.id}. ${context.isAppRtl ? surah.nameAr : surah.nameEn}',
        style: AppTextStyles.body(context, fontSize: 15),
      ),
      subtitle:
          progress != null
              ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              )
              : Text(
                isDownloaded
                    ? context.tr('downloaded_offline')
                    : '${surah.versesCount} ${context.tr('ayah_word')}',
                style: AppTextStyles.caption(context),
              ),
      trailing:
          progress != null
              ? IconButton(
                tooltip: context.tr('cancel'),
                icon: const Icon(Icons.close),
                onPressed: () => notifier.cancel(_reciterCode, surah.id),
              )
              : IconButton(
                tooltip:
                    isDownloaded
                        ? context.tr('downloads_delete')
                        : context.tr('download'),
                icon: Icon(
                  isDownloaded ? Icons.delete_outline : Icons.download_outlined,
                  color: isDownloaded ? colorScheme.error : colorScheme.primary,
                ),
                onPressed:
                    () =>
                        isDownloaded
                            ? notifier.delete(_reciterCode, surah.id)
                            : notifier.download(_reciterCode, surah.id),
              ),
    );
  }
}
