import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/data_saver.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../quran/data/services/audio_download_service.dart';
import '../../../quran/data/services/stt_model_catalogue.dart';
import '../../../quran/data/services/stt_model_store.dart';

/// What the app is keeping, and what can go.
///
/// Every row says how much space it is using and what is lost by clearing it.
/// "Clear cache" with no number behind it is a button people either never
/// press or press and then regret.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StoragePage()));
  }

  @override
  State<StoragePage> createState() => _StoragePageState();
}

/// One thing taking up room.
class _StorageItem {
  const _StorageItem({
    required this.titleKey,
    required this.descriptionKey,
    required this.bytes,
    required this.icon,
    required this.clear,
    this.countLabel,
  });

  final String titleKey;
  final String descriptionKey;
  final int bytes;
  final IconData icon;
  final Future<void> Function() clear;

  /// "12 surahs", when a count says more than a size does.
  final String? countLabel;
}

class _StoragePageState extends State<StoragePage> {
  final AudioDownloadService _audio = AudioDownloadService();

  List<_StorageItem> _items = const [];
  bool _loading = true;
  bool _dataSaver = DataSaver.isEnabled;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    setState(() => _loading = true);

    final items = <_StorageItem>[];

    // Downloaded recitations, which is nearly always the biggest thing here.
    final downloads = await _audio.listDownloads();
    items.add(
      _StorageItem(
        titleKey: 'storage_audio',
        descriptionKey: 'storage_audio_desc',
        icon: Icons.headphones_outlined,
        bytes: downloads.fold(0, (sum, item) => sum + item.bytes),
        countLabel: '${downloads.length}',
        clear: _audio.deleteAll,
      ),
    );

    // Offline speech models, which are large and easy to forget about.
    var modelBytes = 0;
    var modelCount = 0;
    for (final model in SttModelCatalogue.models) {
      final size = await SttModelStore.installedSize(model);
      if (size > 0) {
        modelBytes += size;
        modelCount++;
      }
    }
    items.add(
      _StorageItem(
        titleKey: 'storage_models',
        descriptionKey: 'storage_models_desc',
        icon: Icons.mic_none,
        bytes: modelBytes,
        countLabel: '$modelCount',
        clear: () async {
          for (final model in SttModelCatalogue.models) {
            await SttModelStore.remove(model);
          }
          await SttModelStore.select(null);
        },
      ),
    );

    // The tafsir the reader has fetched. Text, so small — but it is the one
    // cache clearing actually costs something, because it is fetched per surah.
    items.add(
      _StorageItem(
        titleKey: 'storage_tafsir',
        descriptionKey: 'storage_tafsir_desc',
        icon: Icons.menu_book_outlined,
        bytes: await _boxBytes('tafsir_cache'),
        clear: () => _clearBox('tafsir_cache'),
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// Hive reports no size of its own, so this is the box file on disk.
  ///
  /// In a browser there is no file — the box lives in IndexedDB — so this
  /// reports nothing rather than guessing, and the row shows 0 B.
  Future<int> _boxBytes(String name) async {
    if (kIsWeb) {
      return 0;
    }
    try {
      final box =
          Hive.isBoxOpen(name)
              ? Hive.box<Map>(name)
              : await Hive.openBox<Map>(name);
      final path = box.path;
      if (path == null) {
        return 0;
      }
      final file = File(path);
      return file.existsSync() ? await file.length() : 0;
    } catch (e) {
      AppLogger.warning('Could not measure $name: $e');
      return 0;
    }
  }

  Future<void> _clearBox(String name) async {
    final box =
        Hive.isBoxOpen(name)
            ? Hive.box<Map>(name)
            : await Hive.openBox<Map>(name);
    await box.clear();
    // clear() empties the entries but leaves the file at its high-water mark
    // until Hive compacts it, which would make the row still read megabytes.
    await box.compact();
  }

  Future<void> _confirmClear(_StorageItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr(item.titleKey)),
            content: Text(dialogContext.tr('storage_clear_body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.tr('storage_clear')),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }
    await item.clear();
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final total = _items.fold(0, (sum, item) => sum + item.bytes);

    return AppScaffold(
      title: 'storage',
      showBack: true,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : ListView(
                padding: AppScaffold.scrollPadding,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.pie_chart_outline, color: tokens.gold),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AudioDownloadService.formatBytes(total),
                                style: AppTextStyles.display(
                                  context,
                                  fontSize: 22,
                                  color: tokens.ink,
                                ),
                              ),
                              Text(
                                context.tr('storage_total_desc'),
                                style: AppTextStyles.caption(
                                  context,
                                  color: tokens.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(title: context.tr('storage_kept')),
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _row(item, tokens),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: context.tr('data_saver'),
                    subtitle: context.tr('data_saver_desc'),
                  ),
                  AppCard(
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _dataSaver,
                          onChanged: (value) async {
                            await DataSaver.setEnabled(value);
                            setState(() => _dataSaver = value);
                          },
                          title: Text(
                            context.tr('data_saver'),
                            style: AppTextStyles.body(context),
                          ),
                          subtitle: Text(
                            context.tr('data_saver_what'),
                            style: AppTextStyles.caption(
                              context,
                              color: tokens.inkFaint,
                            ),
                          ),
                        ),
                        if (_dataSaver) ...[
                          const Divider(height: AppSpacing.xl),
                          Text(
                            AppLocalizations.translate(
                              Localizations.localeOf(context).languageCode,
                              'data_saver_warn',
                              replacements: {
                                'mb': '${DataSaver.warnMegabytes}',
                              },
                            ),
                            style: AppTextStyles.caption(
                              context,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _row(_StorageItem item, AppTokens tokens) {
    final empty = item.bytes == 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.brand.withValues(alpha: 0.12),
              borderRadius: AppRadii.smAll,
            ),
            child: Icon(item.icon, size: 18, color: tokens.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(item.titleKey),
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(item.descriptionKey),
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AudioDownloadService.formatBytes(item.bytes),
                style: AppTextStyles.caption(
                  context,
                  color: empty ? tokens.inkFaint : tokens.ink,
                ),
              ),
              if (!empty)
                TextButton(
                  onPressed: () => _confirmClear(item),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.tr('storage_clear')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
