import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/data_saver.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/services/audio_download_service.dart';
import '../../data/services/quran_local_service.dart';
import '../../data/services/reciter_catalogue.dart';
import '../widgets/reciter_picker_sheet.dart';
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

  /// Filled once the catalogue is known, so the field can show a name rather
  /// than the identifier it is stored under.
  String? _reciterLabel;

  @override
  void initState() {
    super.initState();
    _resolveReciterName();
  }

  Future<void> _resolveReciterName() async {
    final voices = await ReciterCatalogue.load();
    final voice = ReciterCatalogue.byId(_reciterCode, voices);
    if (mounted && voice != null) {
      setState(() => _reciterLabel = voice.label);
    }
  }

  String get _reciterName =>
      _reciterLabel ?? QuranReciter.byCode(_reciterCode).nameAr;

  Future<void> _pickReciter() async {
    final voice = await ReciterPickerSheet.show(context, _reciterCode);
    if (voice == null || !mounted) {
      return;
    }
    setState(() {
      _reciterCode = voice.id;
      _reciterLabel = voice.label;
    });
    await ref.read(readerSettingsProvider.notifier).setReciter(voice.id);
  }

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
              // Say it once, at the top, rather than letting every row offer a
              // download button that cannot work.
              if (!AudioDownloadService.isSupported)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('downloads_web_unsupported'),
                          style: AppTextStyles.caption(context),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                // A dropdown cannot hold two hundred and forty voices. The
                // picker is a searchable sheet instead.
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('reciter'),
                    border: const OutlineInputBorder(),
                  ),
                  child: InkWell(
                    onTap: _pickReciter,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _reciterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(context, fontSize: 15),
                          ),
                        ),
                        const Icon(Icons.unfold_more, size: 18),
                      ],
                    ),
                  ),
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
              _bulkRow(context, state, surahs),
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

  /// Queue a batch, asking first when the data saver says it is a lot.
  ///
  /// The size is an estimate from a typical surah, not a measurement: these
  /// servers answer chunked, so nothing states a length until the bytes are
  /// already arriving. An estimate is enough to warn on; it is not enough to
  /// report as a total, so it is never shown as one.
  Future<void> _downloadAll(List<int> pending) async {
    if (DataSaver.shouldConfirmBatch(pending.length)) {
      final language = Localizations.localeOf(context).languageCode;
      final approved = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(dialogContext.tr('data_saver')),
              content: Text(
                AppLocalizations.translate(
                  language,
                  'download_batch_warning',
                  replacements: {
                    'count': '${pending.length}',
                    'size': AudioDownloadService.formatBytes(
                      DataSaver.estimateBatchBytes(pending.length),
                    ),
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(dialogContext.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(dialogContext.tr('download')),
                ),
              ],
            ),
      );
      if (approved != true) {
        return;
      }
    }

    await ref
        .read(downloadsProvider.notifier)
        .downloadAll(_reciterCode, pending);
  }

  /// Queue everything the current search shows, in one tap.
  ///
  /// Tapping ninety download buttons one at a time is the same work for the
  /// phone and a great deal more for the person holding it.
  Widget _bulkRow(
    BuildContext context,
    DownloadsState state,
    List<QuranSurahInfo> surahs,
  ) {
    final pending = [
      for (final surah in surahs)
        if (!state.has(_reciterCode, surah.id) &&
            !state.isBusy(_reciterCode, surah.id))
          surah.id,
    ];
    final busy = state.progress.isNotEmpty || state.queue.isNotEmpty;

    if (!AudioDownloadService.isSupported || (pending.isEmpty && !busy)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (pending.isNotEmpty)
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _downloadAll(pending),
                icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                label: Text(
                  '${context.tr('download_all_visible')} (${pending.length})',
                ),
              ),
            ),
          if (busy) ...[
            if (pending.isNotEmpty) const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: ref.read(downloadsProvider.notifier).cancelAll,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(
                '${context.tr('cancel')} '
                '(${state.progress.length + state.queue.length})',
              ),
            ),
          ],
        ],
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
    final queued = state.isQueued(_reciterCode, surah.id);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        // Null means the server never stated a size, so the
                        // bar sweeps instead of standing still at zero.
                        value: progress.ratio,
                        minHeight: 5,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.totalLabel != null
                          ? '${progress.receivedLabel} / ${progress.totalLabel}'
                          : progress.receivedLabel,
                      style: AppTextStyles.caption(context, fontSize: 11),
                    ),
                  ],
                ),
              )
              : queued
              ? Text(
                context.tr('download_queued'),
                style: AppTextStyles.caption(context),
              )
              : Text(
                isDownloaded
                    ? context.tr('downloaded_offline')
                    : '${surah.versesCount} ${context.tr('ayah_word')}',
                style: AppTextStyles.caption(context),
              ),
      trailing:
          progress != null || queued
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
