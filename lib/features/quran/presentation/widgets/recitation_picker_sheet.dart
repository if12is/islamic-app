import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/services/reciter_catalogue.dart';
import '../../data/services/verse_voices.dart';
import '../../domain/entities/riwaya.dart';

/// Whole-surah recordings versus voices that can be cut at the ayah.
enum RecitationPickerMode { surah, verse }

/// The rows a picker is allowed to show — never a recording that cannot play.
///
/// Listing a voice that 404s, or one whose reading is not on the page, is how
/// the old three lists quietly fell through to a default sheikh. Filtering
/// here is the whole fix; the sheet only renders what this returns.
class RecitationOptions {
  RecitationOptions._();

  /// Sentinel for the leading "all" tab. Real riwayah ids start at 1.
  static const int allRiwayatId = 0;

  static List<ReciterVoice> surahVoices({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
  }) => [
    for (final voice in voices)
      if (edition.accepts(voice.riwayaId))
        if (surahNumber == null || voice.surahs.contains(surahNumber)) voice,
  ];

  /// Everything that can play one ayah in [edition].
  ///
  /// Two kinds, shown as one list because the reader asked for one list: the
  /// per-ayah corpus, and whole-surah recordings cut at the provider's verse
  /// marks. The second is what gives Qalun any ayah playback at all — the
  /// per-ayah host has no Qalun folder, so without it that half of the reader
  /// would simply be missing for anyone who chose it.
  static List<PlayableVerseVoice> verseVoices({
    required List<ReciterVoice> voices,
    required MushafEdition edition,
    int? surahNumber,
    bool filesOnly = false,
  }) =>
      filesOnly
          ? VerseVoices.files(edition)
          : VerseVoices.all(
            voices: voices,
            edition: edition,
            surahNumber: surahNumber,
          );

  /// Riwayat that actually have a recording in [riwayaIds], Hafs then Warsh
  /// then the provider's remaining order.
  static List<Riwaya> tabsFor({
    required Iterable<int> riwayaIds,
    List<Riwaya>? known,
  }) {
    final present = riwayaIds.toSet();
    final source = known ?? ReciterCatalogue.riwayat;
    if (source.isEmpty) {
      // The catalogue getter already falls back to the bundled names; this
      // is the belt for a test that passes an empty list.
      return tabsFor(riwayaIds: present, known: Riwaya.bundled);
    }

    final byId = {for (final riwaya in source) riwaya.id: riwaya};
    final used = <int>{};
    final result = <Riwaya>[];

    void addIfPresent(int id) {
      if (!present.contains(id) || !used.add(id)) {
        return;
      }
      result.add(
        byId[id] ?? Riwaya(id: id, nameAr: Riwaya.nameFor(id, source)),
      );
    }

    // The readings the app can also *show* come first, in the order they are
    // offered everywhere else, so the tabs and the reading selector read the
    // same way round. The provider's own order follows for the rest.
    for (final edition in MushafEdition.values) {
      addIfPresent(edition.riwayaId);
    }
    for (final riwaya in source) {
      addIfPresent(riwaya.id);
    }
    for (final id in present) {
      addIfPresent(id);
    }
    return result;
  }

  static List<T> inRiwaya<T>(
    List<T> items,
    int tabId,
    int Function(T item) riwayaIdOf,
  ) {
    if (tabId == allRiwayatId) {
      return items;
    }
    return [
      for (final item in items)
        if (riwayaIdOf(item) == tabId) item,
    ];
  }
}

/// One sheet for every reciter choice, grouped by riwayah.
///
/// The three lists this replaced did not share a source, so a voice picked in
/// one place was missing from another and playback fell through to a default.
class RecitationPickerSheet extends StatefulWidget {
  const RecitationPickerSheet({
    super.key,
    required this.mode,
    required this.selectedId,
    required this.edition,
    this.surahNumber,
    this.filesOnly = false,
  });

  final RecitationPickerMode mode;
  final String selectedId;
  final MushafEdition edition;

  /// Voices that do not contain this surah are hidden — mp3quran publishes
  /// partial recordings that 404.
  final int? surahNumber;

  /// Per-ayah files only, for a caller that cannot use a clip.
  final bool filesOnly;

  static Future<ReciterVoice?> showSurah(
    BuildContext context, {
    required String selectedId,
    required MushafEdition edition,
    int? surahNumber,
  }) {
    return showModalBottomSheet<ReciterVoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => RecitationPickerSheet(
            mode: RecitationPickerMode.surah,
            selectedId: selectedId,
            edition: edition,
            surahNumber: surahNumber,
          ),
    );
  }

  /// Voices that can play one ayah.
  ///
  /// [filesOnly] is for the video exporter, which downloads a file per ayah
  /// and has nothing to do with a clip inside a longer recording. Everywhere
  /// else both kinds are offered together, because to the reader they are the
  /// same thing: a sheikh who recites this verse.
  static Future<PlayableVerseVoice?> showVerse(
    BuildContext context, {
    required String selectedId,
    required MushafEdition edition,
    int? surahNumber,
    bool filesOnly = false,
  }) {
    return showModalBottomSheet<PlayableVerseVoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => RecitationPickerSheet(
            mode: RecitationPickerMode.verse,
            selectedId: selectedId,
            edition: edition,
            surahNumber: surahNumber,
            filesOnly: filesOnly,
          ),
    );
  }

  @override
  State<RecitationPickerSheet> createState() => _RecitationPickerSheetState();
}

class _RecitationPickerSheetState extends State<RecitationPickerSheet> {
  final TextEditingController _search = TextEditingController();

  List<ReciterVoice> _voices = const [];
  bool _loading = true;
  int _tab = RecitationOptions.allRiwayatId;

  bool get _isSurah => widget.mode == RecitationPickerMode.surah;

  @override
  void initState() {
    super.initState();
    // The per-ayah files are a bundled list and appear at once; everything
    // else waits on the catalogue.
    _loading = _isSurah || VerseVoices.files(widget.edition).isEmpty;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    // A spinner only when there is nothing to show yet. Covering forty known
    // names while the catalogue is fetched makes a working list look broken;
    // an empty sheet with no spinner looks broken too. Which one applies
    // depends on the reading — Hafs has its per-ayah list already, Qalun has
    // nothing until the catalogue lands.
    if (mounted && _playable.isEmpty) {
      setState(() => _loading = true);
    }
    // The catalogue is wanted in both modes now: whole-surah recordings are
    // the rows in one, and in the other they are the voices that can be cut
    // at the ayah. The picker showing fewer names than the provider carries
    // was the complaint that started all of this.
    final voices =
        widget.filesOnly
            ? const <ReciterVoice>[]
            : await ReciterCatalogue.load(refresh: refresh);
    await ReciterCatalogue.loadRiwayat(refresh: refresh);
    if (!_isSurah && !widget.filesOnly) {
      await VerseVoices.warmClips(
        voices: voices,
        edition: widget.edition,
        surahNumber: widget.surahNumber,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _voices = voices;
      _loading = false;
      final ids = _playable.map((row) => row.riwayaId);
      final tabs = RecitationOptions.tabsFor(riwayaIds: ids);
      if (_tab != RecitationOptions.allRiwayatId &&
          !tabs.any((riwaya) => riwaya.id == _tab)) {
        _tab = RecitationOptions.allRiwayatId;
      }
    });
  }

  List<_PickerRow> get _playable {
    if (_isSurah) {
      return [
        for (final voice in RecitationOptions.surahVoices(
          voices: _voices,
          edition: widget.edition,
          surahNumber: widget.surahNumber,
        ))
          _PickerRow.surah(voice),
      ];
    }
    return [
      for (final voice in RecitationOptions.verseVoices(
        voices: _voices,
        edition: widget.edition,
        surahNumber: widget.surahNumber,
        filesOnly: widget.filesOnly,
      ))
        _PickerRow.verse(voice),
    ];
  }

  List<_PickerRow> get _visible {
    final inTab = RecitationOptions.inRiwaya(
      _playable,
      _tab,
      (row) => row.riwayaId,
    );
    final query = _search.text.trim();
    if (query.isEmpty) {
      return inTab;
    }
    final needle = _bare(query);
    return [
      for (final row in inTab)
        if (_bare(row.nameAr).contains(needle) ||
            _bare(row.styleAr).contains(needle))
          row,
    ];
  }

  /// Match on the bare letters so a search typed without diacritics still
  /// finds a name that carries them.
  static String _bare(String value) => value
      .replaceAll(RegExp('[ً-ْٰ]'), '')
      .replaceAll(RegExp('[آأإٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  /// The id to tick, or null when the saved choice cannot play here.
  ///
  /// Substituting a different row is how a listed sheikh used to do nothing
  /// and the default played instead. A missing selection is an empty check,
  /// not a different name.
  String? get _selectedId {
    if (_isSurah) {
      final match = ReciterCatalogue.byId(widget.selectedId, _voices);
      if (match == null) {
        return null;
      }
      final playable = _playable.any((row) => row.id == match.id);
      return playable ? match.id : null;
    }
    final playable = _playable.any((row) => row.id == widget.selectedId);
    return playable ? widget.selectedId : null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final playable = _playable;
    final visible = _visible;
    final tabs = RecitationOptions.tabsFor(
      riwayaIds: playable.map((row) => row.riwayaId),
    );
    final selectedId = _selectedId;
    final countKey = _isSurah ? 'reciter_count' : 'verse_reciter_count';

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
                    countKey,
                    replacements: {'count': '${playable.length}'},
                  ),
                ),
                Semantics(
                  label: context.tr('riwaya'),
                  child: PillSelector<int>(
                    compact: true,
                    value: _tab,
                    onChanged: (value) => setState(() => _tab = value),
                    options: [
                      PillOption(
                        value: RecitationOptions.allRiwayatId,
                        label: context.tr('all_riwayat'),
                      ),
                      for (final riwaya in tabs)
                        PillOption(value: riwaya.id, label: riwaya.nameAr),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                else if (playable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      context.tr('no_reciters_for_surah'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(context),
                    ),
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
                        final row = visible[index];
                        final selected =
                            selectedId != null && row.id == selectedId;
                        return AppListRow(
                          dense: true,
                          selected: selected,
                          leading: Icon(
                            Icons.graphic_eq,
                            size: 20,
                            color: selected ? tokens.brand : tokens.inkFaint,
                          ),
                          title: row.nameAr,
                          meta: row.meta,
                          trailing:
                              selected
                                  ? Icon(
                                    Icons.check,
                                    color: tokens.brand,
                                    size: 18,
                                  )
                                  : null,
                          onTap: () => Navigator.of(context).pop(row.payload),
                        );
                      },
                    ),
                  ),
                if (_isSurah) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _load(refresh: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.tr('reciter_refresh')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow {
  const _PickerRow({
    required this.id,
    required this.nameAr,
    required this.styleAr,
    required this.riwayaId,
    required this.meta,
    required this.payload,
  });

  factory _PickerRow.surah(ReciterVoice voice) {
    final partial = voice.surahs.length < 114;
    final style = voice.styleAr;
    return _PickerRow(
      id: voice.id,
      nameAr: voice.nameAr,
      styleAr: style,
      riwayaId: voice.riwayaId,
      meta:
          partial
              ? '${style.isEmpty ? '' : '$style · '}'
                  '${voice.surahs.length}/114'
              : (style.isEmpty ? null : style),
      payload: voice,
    );
  }

  factory _PickerRow.verse(PlayableVerseVoice voice) => _PickerRow(
    id: voice.id,
    nameAr: voice.nameAr,
    styleAr: voice.styleAr,
    riwayaId: voice.riwayaId,
    meta: voice.styleAr.isEmpty ? null : voice.styleAr,
    payload: voice,
  );

  final String id;
  final String nameAr;
  final String styleAr;
  final int riwayaId;
  final String? meta;
  final Object payload;
}

/// Opens [RecitationPickerSheet] instead of a shortlist dropdown.
///
/// A dropdown of bundled voices cannot hold a catalogue id such as
/// `mp3quran:92:92`, and Flutter asserts when the selected value is missing.
class ReciterChooser extends StatelessWidget {
  const ReciterChooser({
    super.key,
    required this.selectedId,
    required this.edition,
    required this.onSelected,
    this.surahNumber,
    this.compact = false,
  });

  final String selectedId;
  final MushafEdition edition;
  final ValueChanged<ReciterVoice> onSelected;
  final int? surahNumber;
  final bool compact;

  Future<void> _pick(BuildContext context) async {
    final chosen = await RecitationPickerSheet.showSurah(
      context,
      selectedId: selectedId,
      edition: edition,
      surahNumber: surahNumber,
    );
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
        final label =
            voice?.label ?? ReciterCatalogue.displayName(selectedId, voices);

        if (compact) {
          return InkWell(
            onTap: () => _pick(context),
            borderRadius: AppRadii.smAll,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      context,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
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
