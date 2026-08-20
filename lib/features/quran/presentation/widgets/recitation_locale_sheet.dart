import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/services/recitation_service.dart';
import '../../data/services/stt_model_store.dart';
import '../../data/services/stt_model_catalogue.dart';

/// Choose which voice pack listens to the recitation.
///
/// Three things this screen refuses to do: require a particular dialect,
/// require a download before anything else works, and hide the packs that are
/// already installed. A phone may have several Arabic packs — Egyptian, Gulf,
/// Levantine — and which of them hears a given reciter best is not something
/// the app can know. So it lists them, remembers the choice, and puts the
/// download where someone who has none can find it.
class RecitationLocaleSheet extends StatefulWidget {
  const RecitationLocaleSheet({super.key, required this.service});

  final RecitationService service;

  static Future<bool?> show(BuildContext context, RecitationService service) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RecitationLocaleSheet(service: service),
    );
  }

  @override
  State<RecitationLocaleSheet> createState() => _RecitationLocaleSheetState();
}

class _RecitationLocaleSheetState extends State<RecitationLocaleSheet> {
  List<RecitationLocale> _locales = const [];
  String? _selected;
  bool _loading = true;
  bool _showAll = false;
  bool _changed = false;

  /// Offline models: which are on disk, which one is in use, and the one
  /// currently downloading.
  final Map<String, bool> _installed = {};
  String? _selectedModel;
  String? _busyModel;
  SttDownloadProgress? _progress;
  StreamSubscription<SttDownloadProgress>? _download;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final locales = await widget.service.installedLocales();
    final saved = await RecitationService.savedLocale();
    final selectedModel = await SttModelStore.selectedId();

    final installed = <String, bool>{};
    for (final model in SttModelCatalogue.models) {
      installed[model.id] = await SttModelStore.isInstalled(model);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _locales = locales;
      _selected = saved;
      _selectedModel = selectedModel;
      _installed
        ..clear()
        ..addAll(installed);
      _loading = false;
    });
  }

  /// Download a model, with the size stated first.
  Future<void> _startDownload(SttModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr(model.nameKey)),
            content: Text(
              AppLocalizations.translate(
                Localizations.localeOf(dialogContext).languageCode,
                'stt_download_confirm',
                replacements: {
                  'download': SttModelCatalogue.formatBytes(
                    model.downloadBytes,
                  ),
                  'installed': SttModelCatalogue.formatBytes(
                    model.installedBytes,
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyModel = model.id;
      _progress = const SttDownloadProgress(state: SttModelState.downloading);
    });

    _download = SttModelStore.download(model).listen((progress) {
      if (!mounted) {
        return;
      }
      setState(() => _progress = progress);

      if (progress.state == SttModelState.installed) {
        setState(() {
          _installed[model.id] = true;
          _busyModel = null;
          _progress = null;
        });
        _chooseModel(model.id);
      } else if (progress.state == SttModelState.failed) {
        setState(() {
          _busyModel = null;
          _progress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('stt_download_failed'))),
        );
      }
    });
  }

  Future<void> _chooseModel(String? id) async {
    await SttModelStore.select(id);
    // The next session has to re-resolve which engine listens, or the choice
    // made here would not take effect until the screen is reopened.
    widget.service.invalidateLocale();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedModel = id;
      _changed = true;
    });
  }

  Future<void> _removeModel(SttModel model) async {
    await SttModelStore.remove(model);
    if (!mounted) {
      return;
    }
    setState(() {
      _installed[model.id] = false;
      if (_selectedModel == model.id) {
        _selectedModel = null;
      }
      _changed = true;
    });
  }

  /// Every offline model, with its size, licence and state.
  Widget _offlineModels(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: context.tr('stt_offline_engines'),
          subtitle: context.tr('stt_offline_engines_desc'),
        ),
        for (final model in SttModelCatalogue.models)
          Builder(
            builder: (context) {
              final installed = _installed[model.id] ?? false;
              final busy = _busyModel == model.id;
              final chosen = _selectedModel == model.id;

              return AppListRow(
                dense: true,
                selected: chosen,
                leading: Icon(
                  installed
                      ? Icons.offline_bolt
                      : Icons.cloud_download_outlined,
                  size: 20,
                  color: chosen ? tokens.brand : tokens.inkFaint,
                ),
                title: context.tr(model.nameKey),
                meta:
                    busy
                        ? _progressLabel(context)
                        : '${SttModelCatalogue.formatBytes(model.downloadBytes)}'
                            ' · ${model.licence}',
                trailing:
                    busy
                        ? IconButton(
                          tooltip: context.tr('cancel'),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            SttModelStore.cancel();
                            setState(() {
                              _busyModel = null;
                              _progress = null;
                            });
                          },
                        )
                        : installed
                        ? IconButton(
                          tooltip: context.tr('delete'),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: tokens.danger,
                          ),
                          onPressed: () => _removeModel(model),
                        )
                        : IconButton(
                          tooltip: context.tr('download'),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          onPressed:
                              _busyModel == null
                                  ? () => _startDownload(model)
                                  : null,
                        ),
                onTap:
                    installed && !busy
                        ? () => _chooseModel(chosen ? null : model.id)
                        : null,
              );
            },
          ),
        if (_progress != null && _progress!.state == SttModelState.downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: _progress!.ratio == 0 ? null : _progress!.ratio,
                minHeight: 5,
                backgroundColor: tokens.groundAlt,
              ),
            ),
          ),
      ],
    );
  }

  String _progressLabel(BuildContext context) {
    final progress = _progress;
    if (progress == null) {
      return '';
    }
    if (progress.state == SttModelState.extracting) {
      return context.tr('stt_extracting');
    }
    final percent = (progress.ratio * 100).round();
    return '${context.tr('downloading')} $percent%';
  }

  Future<void> _choose(String? id) async {
    await RecitationService.setPreferredLocale(id);
    // Picking a device pack means picking the device engine. Leaving a model
    // selected would keep it listening and make this row look inert.
    await SttModelStore.select(null);
    widget.service.invalidateLocale();
    if (!mounted) {
      return;
    }
    setState(() {
      _selected = id;
      _selectedModel = null;
      _changed = true;
    });
  }

  Future<void> _openSettings() async {
    final opened = await RecitationService.openSystemSpeechSettings();
    if (!mounted) {
      return;
    }
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('recite_settings_unavailable'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final arabic = _locales.where((locale) => locale.isArabic).toList();
    final others = _locales.where((locale) => !locale.isArabic).toList();
    final visible = _showAll ? [...arabic, ...others] : arabic;

    // A downloaded model needs no Arabic pack, so the warning above the list
    // would be false while one is in use.
    final offlineActive =
        _selectedModel != null && (_installed[_selectedModel] ?? false);

    return Directionality(
      textDirection: context.appTextDirection,
      child: SafeArea(
        child: ConstrainedBox(
          // The sheet took whatever height its content asked for, which left
          // the pack list a few pixels tall and made expanding it look broken.
          // Give it most of the screen and let one scroll view do the work.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: context.tr('recite_voice_pack'),
                  subtitle: context.tr('recite_voice_pack_desc'),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        if (offlineActive)
                          _notice(
                            context,
                            icon: Icons.offline_bolt_rounded,
                            tint: tokens.brand,
                            text: AppLocalizations.translate(
                              Localizations.localeOf(context).languageCode,
                              'stt_engine_in_use',
                              replacements: {
                                'name': context.tr(
                                  SttModelCatalogue.byId(
                                    _selectedModel!,
                                  )!.nameKey,
                                ),
                              },
                            ),
                          )
                        else if (arabic.isEmpty)
                          _notice(
                            context,
                            icon: Icons.info_outline_rounded,
                            tint: tokens.gold,
                            text: context.tr('recite_no_arabic_pack'),
                          ),

                        AppListRow(
                          dense: true,
                          selected: _selected == null && !offlineActive,
                          leading: Icon(
                            Icons.auto_mode,
                            size: 20,
                            color:
                                _selected == null && !offlineActive
                                    ? tokens.brand
                                    : tokens.inkFaint,
                          ),
                          title: context.tr('recite_pack_automatic'),
                          meta: context.tr('recite_pack_automatic_desc'),
                          trailing:
                              _selected == null && !offlineActive
                                  ? Icon(
                                    Icons.check,
                                    color: tokens.brand,
                                    size: 18,
                                  )
                                  : null,
                          onTap: () => _choose(null),
                        ),
                        for (final locale in visible)
                          AppListRow(
                            dense: true,
                            selected: _selected == locale.id && !offlineActive,
                            leading: Icon(
                              locale.isArabic
                                  ? Icons.record_voice_over_outlined
                                  : Icons.language,
                              size: 20,
                              color:
                                  _selected == locale.id
                                      ? tokens.brand
                                      : tokens.inkFaint,
                            ),
                            title: locale.name,
                            meta: locale.id,
                            trailing:
                                _selected == locale.id && !offlineActive
                                    ? Icon(
                                      Icons.check,
                                      color: tokens.brand,
                                      size: 18,
                                    )
                                    : null,
                            onTap: () => _choose(locale.id),
                          ),

                        if (others.isNotEmpty)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed:
                                  () => setState(() => _showAll = !_showAll),
                              icon: Icon(
                                _showAll
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              label: Text(
                                _showAll
                                    ? context.tr('recite_hide_other_packs')
                                    : AppLocalizations.translate(
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                      'recite_show_other_packs_count',
                                      replacements: {
                                        'count': '${others.length}',
                                      },
                                    ),
                              ),
                            ),
                          ),

                        _offlineModels(context),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(context.tr('recite_download_pack')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr('recite_download_hint'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_changed),
                  child: Text(context.tr('done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A tinted line of explanation above the list.
  Widget _notice(
    BuildContext context, {
    required IconData icon,
    required Color tint,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption(context, color: context.tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}
