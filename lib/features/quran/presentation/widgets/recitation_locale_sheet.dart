import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/services/recitation_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final locales = await widget.service.installedLocales();
    final saved = await RecitationService.savedLocale();
    if (!mounted) {
      return;
    }
    setState(() {
      _locales = locales;
      _selected = saved;
      _loading = false;
    });
  }

  Future<void> _choose(String? id) async {
    await RecitationService.setPreferredLocale(id);
    widget.service.invalidateLocale();
    if (!mounted) {
      return;
    }
    setState(() {
      _selected = id;
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

    return Directionality(
      textDirection: context.appTextDirection,
      child: SafeArea(
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
              else ...[
                if (arabic.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: tokens.gold.withValues(alpha: 0.12),
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: Text(
                      context.tr('recite_no_arabic_pack'),
                      style: AppTextStyles.caption(context, color: tokens.ink),
                    ),
                  ),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      AppListRow(
                        dense: true,
                        selected: _selected == null,
                        leading: Icon(
                          Icons.auto_mode,
                          size: 20,
                          color: _selected == null
                              ? tokens.brand
                              : tokens.inkFaint,
                        ),
                        title: context.tr('recite_pack_automatic'),
                        meta: context.tr('recite_pack_automatic_desc'),
                        trailing: _selected == null
                            ? Icon(Icons.check, color: tokens.brand, size: 18)
                            : null,
                        onTap: () => _choose(null),
                      ),
                      for (final locale in visible)
                        AppListRow(
                          dense: true,
                          selected: _selected == locale.id,
                          leading: Icon(
                            locale.isArabic
                                ? Icons.record_voice_over_outlined
                                : Icons.language,
                            size: 20,
                            color: _selected == locale.id
                                ? tokens.brand
                                : tokens.inkFaint,
                          ),
                          title: locale.name,
                          meta: locale.id,
                          trailing: _selected == locale.id
                              ? Icon(Icons.check, color: tokens.brand, size: 18)
                              : null,
                          onTap: () => _choose(locale.id),
                        ),
                    ],
                  ),
                ),

                if (others.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      icon: Icon(
                        _showAll ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _showAll
                            ? context.tr('recite_hide_other_packs')
                            : context.tr('recite_show_other_packs'),
                      ),
                    ),
                  ),
              ],

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
    );
  }
}
