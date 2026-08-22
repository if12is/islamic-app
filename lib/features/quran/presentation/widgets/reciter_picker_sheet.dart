import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/services/reciter_catalogue.dart';
import '../providers/quran_audio_provider.dart';

/// Choose from every reciter, not from a shortlist of seven.
///
/// Two hundred and forty recordings is far too many for a dropdown, so this is
/// a sheet with a search box: type two letters of a name and the list is short
/// again. The same reciter can appear more than once — murattal, mujawwad, a
/// different riwayah — because those are different recordings, and someone who
/// wants Husary mujawwad does not want Husary murattal.
class ReciterPickerSheet extends StatefulWidget {
  const ReciterPickerSheet({super.key, required this.selectedId});

  final String selectedId;

  /// Returns the chosen voice, or null if the sheet was dismissed.
  static Future<ReciterVoice?> show(BuildContext context, String selectedId) {
    return showModalBottomSheet<ReciterVoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReciterPickerSheet(selectedId: selectedId),
    );
  }

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  final TextEditingController _search = TextEditingController();

  List<ReciterVoice> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    final voices = await ReciterCatalogue.load(refresh: refresh);
    if (mounted) {
      setState(() {
        _all = voices;
        _loading = false;
      });
    }
  }

  List<ReciterVoice> get _visible {
    final query = _search.text.trim();
    if (query.isEmpty) {
      return _all;
    }
    // Match on the bare letters so a search typed without diacritics still
    // finds a name that carries them.
    final needle = _bare(query);
    return _all.where((voice) {
      return _bare(voice.nameAr).contains(needle) ||
          _bare(voice.styleAr).contains(needle);
    }).toList();
  }

  static String _bare(String value) => value
      .replaceAll(RegExp('[ً-ْٰ]'), '')
      .replaceAll(RegExp('[آأإٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final visible = _visible;

    return Directionality(
      textDirection: context.appTextDirection,
      child: SafeArea(
        child: ConstrainedBox(
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
                  title: context.tr('reciter'),
                  subtitle: AppLocalizations.translate(
                    Localizations.localeOf(context).languageCode,
                    'reciter_count',
                    replacements: {'count': '${_all.length}'},
                  ),
                ),
                TextField(
                  controller: _search,
                  autofocus: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.tr('reciter_search_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      context.tr('no_results'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(context),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final voice = visible[index];
                        final selected = voice.id == widget.selectedId;
                        final partial = voice.surahs.length < 114;

                        return AppListRow(
                          dense: true,
                          selected: selected,
                          leading: Icon(
                            Icons.graphic_eq,
                            size: 20,
                            color: selected ? tokens.brand : tokens.inkFaint,
                          ),
                          title: voice.nameAr,
                          meta:
                              partial
                                  // Say so rather than let a missing surah
                                  // look like a broken download.
                                  ? '${voice.styleAr} · '
                                      '${voice.surahs.length}/114'
                                  : voice.styleAr,
                          trailing:
                              selected
                                  ? Icon(
                                    Icons.check,
                                    color: tokens.brand,
                                    size: 18,
                                  )
                                  : null,
                          onTap: () => Navigator.of(context).pop(voice),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => _load(refresh: true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(context.tr('reciter_refresh')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [ReciterPickerSheet] instead of a seven-item dropdown.
///
/// A dropdown of bundled voices cannot hold a catalogue id such as
/// `mp3quran:92:92`, and Flutter asserts when the selected value is missing.
class ReciterChooser extends StatelessWidget {
  const ReciterChooser({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.compact = false,
  });

  final String selectedId;
  final ValueChanged<ReciterVoice> onSelected;
  final bool compact;

  Future<void> _pick(BuildContext context) async {
    final chosen = await ReciterPickerSheet.show(context, selectedId);
    if (chosen != null) {
      onSelected(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReciterVoice>>(
      future: ReciterCatalogue.load(),
      builder: (context, snapshot) {
        final voices = snapshot.data ?? ReciterCatalogue.bundled;
        final voice = ReciterCatalogue.byId(selectedId, voices);
        final bundled = QuranReciter.byCode(selectedId);
        final label =
            voice?.label ??
            (context.isAppRtl ? bundled.nameAr : bundled.nameEn);

        if (compact) {
          return InkWell(
            onTap: () => _pick(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('reciter')),
          subtitle: Text(label),
          trailing: const Icon(Icons.expand_more),
          onTap: () => _pick(context),
        );
      },
    );
  }
}
