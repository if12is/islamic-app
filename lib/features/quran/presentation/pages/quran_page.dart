import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../home/domain/custom_wird.dart';
import '../../../home/presentation/widgets/add_to_wird_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../shared/widgets/shell_header_buttons.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/surah_audio_provider.dart';
import 'downloads_page.dart';
import '../widgets/khatmah_card.dart';
import '../widgets/last_read_card.dart';
import '../widgets/reciter_picker_sheet.dart';
import 'now_playing_page.dart';
import 'recitation_page.dart';
import 'surah_reader_page.dart';
import 'package:just_audio/just_audio.dart';

/// What the index is listing right now.
enum QuranIndexMode { surahs, juz, hizb, pages, sajdah }

// --- DATA MODEL ---
class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final int versesCount;
  final String type; // e.g. "مكية"

  const Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.versesCount,
    required this.type,
  });

  factory Surah.fromApiJson(Map<String, dynamic> json) {
    return Surah(
      id: json['number'] as int? ?? 0,
      nameAr: json['name']?.toString().replaceFirst('سُورَةُ ', '') ?? '',
      nameEn: json['englishName'] as String? ?? '',
      versesCount: json['numberOfAyahs'] as int? ?? 0,
      type: json['revelationType'] == 'Meccan' ? 'مكية' : 'مدنية',
    );
  }
}

class AyahSearchResult {
  final int surahId;
  final int verseNumber;
  final String surahNameAr;
  final String surahNameEn;
  final String ayahText;

  const AyahSearchResult({
    required this.surahId,
    required this.verseNumber,
    required this.surahNameAr,
    required this.surahNameEn,
    required this.ayahText,
  });

  factory AyahSearchResult.fromApiJson(Map<String, dynamic> json) {
    final surahMap =
        json['surah'] is Map<String, dynamic>
            ? json['surah'] as Map<String, dynamic>
            : <String, dynamic>{};

    return AyahSearchResult(
      surahId: surahMap['number'] as int? ?? 1,
      verseNumber: json['numberInSurah'] as int? ?? 1,
      surahNameAr: (surahMap['name'] as String? ?? '')
          .replaceFirst('سُورَةُ ', '')
          .replaceFirst('سورة ', ''),
      surahNameEn: surahMap['englishName'] as String? ?? '',
      ayahText: json['text'] as String? ?? '',
    );
  }
}

class QuranPage extends ConsumerStatefulWidget {
  const QuranPage({super.key});

  @override
  ConsumerState<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends ConsumerState<QuranPage> {
  // Constants & Colors
  Color get _primaryDarkGreen => context.tokens.brand;

  // States
  //
  // The one player the whole app shares. A second AudioPlayer used to live
  // here, and just_audio_background only ever attaches its notification to the
  // first player created — so whichever screen was built first won the media
  // controls and the other played with none, while both fought over the same
  // audio session.
  //
  // The session itself now lives in [surahAudioProvider] rather than in this
  // State: it used to be thrown away every time the tab changed, which lost
  // the bar, the reciter and the sleep timer while the audio carried on.
  AudioPlayer get _audioPlayer => ref.read(quranAudioPlayerProvider);

  SurahAudioController get _playback => ref.read(surahAudioProvider.notifier);

  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];
  final List<int> _allJuzNumbers = List<int>.generate(30, (index) => index + 1);
  List<int> _filteredJuzNumbers = List<int>.generate(30, (index) => index + 1);
  final List<int> _allHizbNumbers = List<int>.generate(
    QuranLocalService.hizbCount,
    (index) => index + 1,
  );
  List<int> _filteredHizbNumbers = List<int>.generate(
    QuranLocalService.hizbCount,
    (index) => index + 1,
  );
  final List<int> _allPages = List<int>.generate(
    QuranLocalService.pageCount,
    (index) => index + 1,
  );
  List<int> _filteredPages = List<int>.generate(
    QuranLocalService.pageCount,
    (index) => index + 1,
  );
  final List<QuranVerse> _sajdahVerses = QuranLocalService.sajdahList();
  List<AyahSearchResult> _ayahSearchResults = [];
  bool _isLoading = true;
  bool _isAyahSearchLoading = false;
  QuranIndexMode _mode = QuranIndexMode.surahs;

  /// Ayah search and the surah tools only apply to the surah list.
  bool get _isSurahMode => _mode == QuranIndexMode.surahs;
  String _errorKey = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchSurahs() async {
    setState(() {
      _isLoading = true;
      _errorKey = '';
    });

    try {
      // The index comes from the bundled Mushaf: no network, no waiting.
      final surahs =
          QuranLocalService.surahs()
              .map(
                (info) => Surah(
                  id: info.id,
                  nameAr: info.nameAr,
                  nameEn: info.nameEn,
                  versesCount: info.versesCount,
                  type: info.isMeccan ? 'مكية' : 'مدنية',
                ),
              )
              .toList();

      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = List.from(surahs);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorKey = 'server_connection_error';
          _isLoading = false;
        });
      }
    }
  }

  String _localizedSurahType(BuildContext context, String rawType) {
    final normalized = rawType.toLowerCase();
    if (normalized.contains('مكية') || normalized.contains('meccan')) {
      return context.tr('surah_type_meccan');
    }
    if (normalized.contains('مدنية') || normalized.contains('medinan')) {
      return context.tr('surah_type_medinan');
    }
    return rawType;
  }

  String _formatNumber(BuildContext context, int value) {
    if (!context.isAppRtl) {
      return value.toString();
    }
    return _toArabicDigits(value);
  }

  /// Coming back from the reader: the last-read card watches the provider, so
  /// this only nudges the rest of the screen to rebuild.
  Future<void> _loadLastRead() async {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchChanged() {
    final rawQuery = _searchController.text.trim();
    final lowerQuery = rawQuery.toLowerCase();
    final normalizedDigitsQuery = _normalizeDigits(lowerQuery);

    _searchDebounce?.cancel();

    if (_isSurahMode) {
      setState(() {
        if (normalizedDigitsQuery.isEmpty) {
          _filteredSurahs = List.from(_allSurahs);
          _ayahSearchResults = [];
          _isAyahSearchLoading = false;
        } else {
          _filteredSurahs =
              _allSurahs.where((surah) {
                return surah.nameAr.contains(rawQuery) ||
                    surah.nameEn.toLowerCase().contains(lowerQuery) ||
                    surah.id.toString() == normalizedDigitsQuery ||
                    _toArabicDigits(surah.id).contains(rawQuery);
              }).toList();
        }
      });

      if (normalizedDigitsQuery.length >= 2) {
        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
          _searchAyahs(rawQuery);
        });
      }
      return;
    }

    bool matchesNumber(int value) {
      if (normalizedDigitsQuery.isEmpty) {
        return true;
      }
      return value.toString().contains(normalizedDigitsQuery) ||
          _toArabicDigits(value).contains(rawQuery);
    }

    setState(() {
      _filteredJuzNumbers = _allJuzNumbers.where(matchesNumber).toList();
      _filteredHizbNumbers = _allHizbNumbers.where(matchesNumber).toList();
      _filteredPages = _allPages.where(matchesNumber).toList();
      _ayahSearchResults = [];
      _isAyahSearchLoading = false;
    });
  }

  Future<void> _searchAyahs(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2 || !_isSurahMode) {
      if (!mounted) return;
      setState(() {
        _ayahSearchResults = [];
        _isAyahSearchLoading = false;
      });
      return;
    }

    setState(() {
      _isAyahSearchLoading = true;
    });

    // Offline search over the bundled text, ignoring diacritics.
    final matches = QuranLocalService.search(trimmed, limit: 60);
    if (!mounted) return;

    // Ignore stale results from a query the user has already changed.
    if (_searchController.text.trim() != trimmed || !_isSurahMode) {
      return;
    }

    setState(() {
      _ayahSearchResults =
          matches
              .map(
                (verse) => AyahSearchResult(
                  surahId: verse.surahNumber,
                  verseNumber: verse.numberInSurah,
                  surahNameAr: verse.surahNameAr,
                  surahNameEn: verse.surahNameEn,
                  ayahText: verse.text,
                ),
              )
              .toList();
      _isAyahSearchLoading = false;
    });
  }

  String _normalizeDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var normalized = input;
    for (var i = 0; i < arabicDigits.length; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], '$i');
    }
    return normalized;
  }

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((char) => arabicDigits[int.parse(char)])
        .join('');
  }

  void _setMode(QuranIndexMode mode) {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      if (mode != QuranIndexMode.surahs) {
        _ayahSearchResults = [];
        _isAyahSearchLoading = false;
      }
    });

    _onSearchChanged();
  }

  /// Start or toggle a surah, and say something useful when it will not play.
  Future<void> _play(int surahId) async {
    final ok = await _playback.play(surahId);
    if (ok || !mounted) {
      return;
    }

    final state = ref.read(surahAudioProvider);
    final key = state.errorKey ?? 'audio_play_failed';
    final detail = state.errorDetail;
    _playback.clearError();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            detail == null ? context.tr(key) : '${context.tr(key)} ($detail)',
          ),
          action: SnackBarAction(
            label: context.tr('retry'),
            onPressed: () => _play(surahId),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    // The player belongs to the provider, which disposes it. Stopping here
    // would cut off a recitation the listener left running on purpose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppScaffold(
      titleWidget: Text(
        context.tr('quran'),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      leading: const ShellThemeButton(),
      actions: const [ShellProfileButton()],
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CustomLoader())
          else if (_errorKey.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr(_errorKey),
                    style: AppTextStyles.body(context, color: tokens.danger),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _fetchSurahs,
                    child: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else
            ListView(
              padding: AppScaffold.scrollPadding,
              children: [
                _buildSearchBar(),
                const SizedBox(height: AppSpacing.lg),
                const LastReadCard(),
                const SizedBox(height: AppSpacing.md),
                const KhatmahCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildSurahIndexHeader(),
                _buildIndexBody(),
                if (_isSurahMode &&
                    _searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildAyahSearchHeader(),
                  const SizedBox(height: AppSpacing.md),
                  _buildAyahSearchResults(),
                ],
              ],
            ),

          // The player floats above the list while something is playing.
          if (ref.watch(surahAudioProvider).hasSurah)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.navClearance,
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                  ),
                  child: _buildAudioPlayerBar(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GlassSearchField(
      controller: _searchController,
      // Someone who half-remembers a verse cannot type it. The mic goes where
      // they are already looking for it.
      voiceTooltip: context.tr('recite_mode_identify'),
      onVoiceSearch:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RecitationPage.identify(),
            ),
          ),
      hintText: switch (_mode) {
        QuranIndexMode.surahs => context.tr('search_surah_or_number_hint'),
        QuranIndexMode.juz => context.tr('search_juz_hint'),
        QuranIndexMode.hizb => context.tr('search_hizb_hint'),
        QuranIndexMode.pages => context.tr('search_page_hint'),
        QuranIndexMode.sajdah => context.tr('sajdah_index'),
      },
      onChanged: (_) => setState(() {}),
    );
  }

  /// Surah · Juz · Hizb · Page · Sajdah, as a pill track.
  Widget _buildModeToggle() {
    return Row(
      children: [
        Flexible(
          child: PillSelector<QuranIndexMode>(
            compact: true,
            value: _mode,
            onChanged: _setMode,
            options: [
              PillOption(
                value: QuranIndexMode.surahs,
                label: context.tr('surahs_tab'),
              ),
              PillOption(
                value: QuranIndexMode.juz,
                label: context.tr('juz_tab'),
              ),
              PillOption(
                value: QuranIndexMode.hizb,
                label: context.tr('hizb_tab'),
              ),
              PillOption(
                value: QuranIndexMode.pages,
                label: context.tr('pages_tab'),
              ),
              PillOption(
                value: QuranIndexMode.sajdah,
                label: context.tr('sajdah_tab'),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GhostIconButton(
          icon: Icons.my_location,
          tooltip: context.tr('jump_to'),
          onTap: _openJumpSheet,
        ),
        const SizedBox(width: AppSpacing.xs),
        // Offline downloads were three taps deep behind a card, which is a
        // long way to walk for the screen you want before a flight.
        GhostIconButton(
          icon: Icons.download_for_offline_outlined,
          tooltip: context.tr('offline_downloads'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
              ),
        ),
      ],
    );
  }

  Widget _buildSurahIndexHeader() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final title = switch (_mode) {
      QuranIndexMode.surahs =>
        hasQuery ? context.tr('surahs_results') : context.tr('surahs_index'),
      QuranIndexMode.juz => context.tr('juz_index'),
      QuranIndexMode.hizb => context.tr('hizb_index'),
      QuranIndexMode.pages => context.tr('pages_index'),
      QuranIndexMode.sajdah => context.tr('sajdah_index'),
    };

    final counter = switch (_mode) {
      QuranIndexMode.surahs =>
        '${_formatNumber(context, _filteredSurahs.length)} '
            '${context.tr('surah_word')}',
      QuranIndexMode.juz =>
        '${_formatNumber(context, _filteredJuzNumbers.length)} '
            '${context.tr('juz_word')}',
      QuranIndexMode.hizb =>
        '${_formatNumber(context, _filteredHizbNumbers.length)} '
            '${context.tr('hizb_label')}',
      QuranIndexMode.pages =>
        '${_formatNumber(context, _filteredPages.length)} '
            '${context.tr('page_word')}',
      QuranIndexMode.sajdah =>
        '${_formatNumber(context, _sajdahVerses.length)} '
            '${context.tr('sajdah_word')}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: counter),
        _buildModeToggle(),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildSurahList() {
    if (_filteredSurahs.isEmpty) {
      return _empty(context.tr('no_surah_match'));
    }

    final playback = ref.watch(surahAudioProvider);

    return Column(
      children: [
        for (final surah in _filteredSurahs)
          AppListRow(
            badge: _formatNumber(context, surah.id),
            title: context.isAppRtl ? surah.nameAr : surah.nameEn,
            meta:
                '${_localizedSurahType(context, surah.type)} · '
                '${_formatNumber(context, surah.versesCount)} '
                '${context.tr('verses')}',
            trailingText: context.isAppRtl ? null : surah.nameAr,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Adding a surah to the daily wird belongs where the surah is,
                // not buried in a screen the reader has to already know about.
                AddToWirdButton(
                  kind: WirdKind.surah,
                  reference: '${surah.id}',
                  title:
                      '${context.tr('surah_word')} '
                      '${context.isAppRtl ? surah.nameAr : surah.nameEn}',
                  compact: true,
                ),
                GhostIconButton(
                  icon:
                      playback.surahNumber == surah.id && playback.playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_outline,
                  active: playback.surahNumber == surah.id && playback.playing,
                  size: 24,
                  tooltip: context.tr('play'),
                  onTap: () => _play(surah.id),
                ),
              ],
            ),
            onTap: () => _openReader(SurahReaderPage(surahNumber: surah.id)),
          ),
      ],
    );
  }

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption(context),
      ),
    ),
  );

  /// The thirty ajzaa.
  ///
  /// This was the last hand-built list in the app: its own card at radius 16
  /// with its own shadow, a 48px badge on `surfaceContainerHighest`, a
  /// hardcoded green, and "Juz 7" in Latin down the side of an Arabic screen.
  /// It sat one tab away from the hizb list, which was already on the shared
  /// row — the same list, drawn twice, differently.
  Widget _buildJuzList() {
    return _buildIndexList(
      count: _filteredJuzNumbers.length,
      emptyKey: 'no_juz_match',
      builder: (index) {
        final juzNumber = _filteredJuzNumbers[index];
        final start = QuranLocalService.juzStart(juzNumber);

        return _IndexEntry(
          badge: _formatNumber(context, juzNumber),
          title:
              '${context.tr('juz_word')} '
              '${_formatNumber(context, juzNumber)}',
          subtitle:
              '${context.tr('starts_at')} ${start.surahNameAr} '
              '${_formatNumber(context, start.numberInSurah)}',
          trailing:
              '${context.tr('page_word')} '
              '${_formatNumber(context, start.page)}',
          onTap: () => _openReader(SurahReaderPage(juzNumber: juzNumber)),
          wirdKind: WirdKind.juz,
          wirdReference: '$juzNumber',
        );
      },
    );
  }

  /// The list that matches the selected index mode.
  Widget _buildIndexBody() {
    switch (_mode) {
      case QuranIndexMode.surahs:
        return _buildSurahList();
      case QuranIndexMode.juz:
        return _buildJuzList();
      case QuranIndexMode.hizb:
        return _buildHizbList();
      case QuranIndexMode.pages:
        return _buildPagesList();
      case QuranIndexMode.sajdah:
        return _buildSajdahList();
    }
  }

  Widget _buildHizbList() {
    return _buildIndexList(
      count: _filteredHizbNumbers.length,
      emptyKey: 'no_results',
      builder: (index) {
        final hizb = _filteredHizbNumbers[index];
        final start = QuranLocalService.hizbStart(hizb);
        return _IndexEntry(
          badge: _formatNumber(context, hizb),
          title: '${context.tr('hizb_label')} ${_formatNumber(context, hizb)}',
          subtitle:
              '${context.tr('starts_at')} ${start.surahNameAr} '
              '${_formatNumber(context, start.numberInSurah)} · '
              '${context.tr('juz_word')} ${_formatNumber(context, start.juz)}',
          trailing:
              '${context.tr('page_word')} ${_formatNumber(context, start.page)}',
          onTap: () => _openReader(SurahReaderPage(hizbNumber: hizb)),
          wirdKind: WirdKind.hizb,
          wirdReference: '$hizb',
        );
      },
    );
  }

  Widget _buildPagesList() {
    return _buildIndexList(
      count: _filteredPages.length,
      emptyKey: 'no_results',
      viewportHeight: 560,
      builder: (index) {
        final page = _filteredPages[index];
        final start = QuranLocalService.pageStart(page);
        final names = QuranLocalService.surahNamesOnPage(page);
        return _IndexEntry(
          badge: _formatNumber(context, page),
          title: '${context.tr('page_word')} ${_formatNumber(context, page)}',
          subtitle: names.join(' · '),
          trailing:
              '${context.tr('juz_word')} ${_formatNumber(context, start.juz)}',
          onTap: () => _openReader(SurahReaderPage(pageNumber: page)),
        );
      },
    );
  }

  Widget _buildSajdahList() {
    return _buildIndexList(
      count: _sajdahVerses.length,
      emptyKey: 'no_results',
      builder: (index) {
        final verse = _sajdahVerses[index];
        return _IndexEntry(
          badge: '۩',
          title:
              '${context.tr('surah_word')} ${verse.surahNameAr} · '
              '${context.tr('ayah_word')} '
              '${_formatNumber(context, verse.numberInSurah)}',
          subtitle:
              '${context.tr('juz_word')} ${_formatNumber(context, verse.juz)}'
              ' · ${context.tr('page_word')} '
              '${_formatNumber(context, verse.page)}',
          trailing: context.tr('sajdah_word'),
          onTap:
              () => _openReader(
                SurahReaderPage(
                  surahNumber: verse.surahNumber,
                  initialVerse: verse.numberInSurah,
                ),
              ),
        );
      },
    );
  }

  /// Shared card list used by the juz, hizb, page, and sajdah indexes.
  Widget _buildIndexList({
    required int count,
    required String emptyKey,
    required _IndexEntry Function(int index) builder,
    double? viewportHeight,
  }) {
    if (count == 0) {
      return _empty(context.tr(emptyKey));
    }

    // Long indexes (604 pages) get their own viewport so the rows are built
    // lazily instead of all at once inside the page scroll view.
    final list = ListView.builder(
      shrinkWrap: viewportHeight == null,
      physics:
          viewportHeight == null ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: count,
      itemBuilder: (context, index) {
        final entry = builder(index);
        return AppListRow(
          badge: entry.badge,
          title: entry.title,
          meta: entry.subtitle,
          // The juz and hizb indexes are where someone decides to read a
          // portion a day, so the wird button belongs on the row rather than
          // only on the surah list.
          trailingText: entry.canJoinWird ? null : entry.trailing,
          trailing:
              entry.canJoinWird
                  ? AddToWirdButton(
                    kind: entry.wirdKind!,
                    reference: entry.wirdReference!,
                    title: entry.title,
                    compact: true,
                  )
                  : null,
          onTap: entry.onTap,
        );
      },
    );

    return viewportHeight == null
        ? list
        : SizedBox(height: viewportHeight, child: list);
  }

  void _openReader(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => page))
        .then((_) => _loadLastRead());
  }

  /// "Go to" — open the reader at an exact surah:verse, juz, hizb, or page.
  Future<void> _openJumpSheet() async {
    final surahController = TextEditingController();
    final verseController = TextEditingController();
    final numberController = TextEditingController();
    var target = QuranIndexMode.surahs;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: sheetContext.appTextDirection,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final isVerseTarget = target == QuranIndexMode.surahs;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('jump_to'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<QuranIndexMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: QuranIndexMode.surahs,
                          label: Text(context.tr('ayah_word')),
                        ),
                        ButtonSegment(
                          value: QuranIndexMode.juz,
                          label: Text(context.tr('juz_word')),
                        ),
                        ButtonSegment(
                          value: QuranIndexMode.hizb,
                          label: Text(context.tr('hizb_label')),
                        ),
                        ButtonSegment(
                          value: QuranIndexMode.pages,
                          label: Text(context.tr('page_word')),
                        ),
                      ],
                      selected: {target},
                      onSelectionChanged:
                          (value) => setSheetState(() => target = value.first),
                    ),
                    const SizedBox(height: 16),
                    if (isVerseTarget)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: surahController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('surah_number_label'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: verseController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('ayah_word'),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      TextField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: switch (target) {
                            QuranIndexMode.juz => context.tr('juz_word'),
                            QuranIndexMode.hizb => context.tr('hizb_label'),
                            _ => context.tr('page_word'),
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final page = _resolveJumpTarget(
                            target,
                            surahController.text,
                            verseController.text,
                            numberController.text,
                          );
                          if (page == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('invalid_reference')),
                              ),
                            );
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          _openReader(page);
                        },
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: Text(context.tr('open')),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    surahController.dispose();
    verseController.dispose();
    numberController.dispose();
  }

  /// Validates the typed reference and returns the reader to open, or null.
  Widget? _resolveJumpTarget(
    QuranIndexMode target,
    String surahText,
    String verseText,
    String numberText,
  ) {
    int? parse(String value) => int.tryParse(_normalizeDigits(value.trim()));

    switch (target) {
      case QuranIndexMode.surahs:
      case QuranIndexMode.sajdah:
        final surah = parse(surahText);
        if (surah == null ||
            surah < 1 ||
            surah > QuranLocalService.surahCount) {
          return null;
        }
        final verse = parse(verseText) ?? 1;
        final count = QuranLocalService.surahInfo(surah).versesCount;
        if (verse < 1 || verse > count) {
          return null;
        }
        return SurahReaderPage(surahNumber: surah, initialVerse: verse);
      case QuranIndexMode.juz:
        final juz = parse(numberText);
        if (juz == null || juz < 1 || juz > QuranLocalService.juzCount) {
          return null;
        }
        return SurahReaderPage(juzNumber: juz);
      case QuranIndexMode.hizb:
        final hizb = parse(numberText);
        if (hizb == null || hizb < 1 || hizb > QuranLocalService.hizbCount) {
          return null;
        }
        return SurahReaderPage(hizbNumber: hizb);
      case QuranIndexMode.pages:
        final page = parse(numberText);
        if (page == null || page < 1 || page > QuranLocalService.pageCount) {
          return null;
        }
        return SurahReaderPage(pageNumber: page);
    }
  }

  Widget _buildAyahSearchHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.tr('ayahs_search_results'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color!,
          ),
        ),
        if (!_isAyahSearchLoading)
          Text(
            '${_formatNumber(context, _ayahSearchResults.length)} ${context.tr('result_word')}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildAyahSearchResults() {
    if (_isAyahSearchLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: CircularProgressIndicator(color: _primaryDarkGreen),
        ),
      );
    }

    if (_ayahSearchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            context.tr('no_ayahs_match'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ayahSearchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = _ayahSearchResults[index];

        return GestureDetector(
          onTap: () {
            // Open the reader on the matched verse, not the top of the surah.
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder:
                        (context) => SurahReaderPage(
                          surahNumber: result.surahId,
                          initialVerse: result.verseNumber,
                        ),
                  ),
                )
                .then((_) {
                  _loadLastRead();
                });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _primaryDarkGreen.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.isAppRtl
                      ? '${context.tr('surah_word')} ${result.surahNameAr} • ${context.tr('ayah_word')} ${_formatNumber(context, result.verseNumber)}'
                      : '${context.tr('surah_word')} ${result.surahNameEn} • ${context.tr('ayah_word')} ${result.verseNumber}',
                  style: TextStyle(
                    color: _primaryDarkGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.ayahText,
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTextStyles.quranFamily,
                    fontSize: 22,
                    height: 1.7,
                    color: Theme.of(context).textTheme.bodyLarge!.color!,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The mini bar: what is playing, one control, and a way into the full
  /// player. Everything else — speed, repeat, the sleep timer, seeking — lives
  /// one tap away rather than crammed into a strip over the list.
  Widget _buildAudioPlayerBar() {
    final tokens = context.tokens;
    final playback = ref.watch(surahAudioProvider);
    final surahNumber = playback.surahNumber;
    if (surahNumber == null) {
      return const SizedBox.shrink();
    }
    final info = QuranLocalService.surahInfo(surahNumber);

    return Material(
      color: tokens.surfaceRaised,
      elevation: 0,
      borderRadius: AppRadii.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => NowPlayingPage.open(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.lgAll,
            border: Border.all(color: tokens.line),
            boxShadow: AppShadows.soft(tokens.ink),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip:
                          playback.playing
                              ? context.tr('pause')
                              : context.tr('play'),
                      icon: Icon(
                        playback.playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: tokens.brand,
                        size: 40,
                      ),
                      onPressed: _playback.toggle,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.isAppRtl ? info.nameAr : info.nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.display(
                              context,
                              fontSize: 15,
                              color: tokens.ink,
                            ),
                          ),
                          ReciterChooser(
                            compact: true,
                            selectedId: playback.reciterId,
                            onSelected: (voice) {
                              _playback.setReciter(voice.id);
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setReciter(voice.id);
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('now_playing'),
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 22,
                        color: tokens.inkMuted,
                      ),
                      onPressed: () => NowPlayingPage.open(context),
                    ),
                    IconButton(
                      tooltip: context.tr('close'),
                      icon: Icon(Icons.close_rounded, color: tokens.inkMuted),
                      onPressed: _playback.stop,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _audioPlayer.duration ?? Duration.zero;
                      final progress =
                          duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                  duration.inMilliseconds
                              : 0.0;
                      return ClipRRect(
                        borderRadius: AppRadii.pillAll,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: tokens.groundAlt,
                          valueColor: AlwaysStoppedAnimation(tokens.gold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in a Quran index list.
class _IndexEntry {
  const _IndexEntry({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.wirdKind,
    this.wirdReference,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  /// What this row would become if added to the daily wird.
  ///
  /// Null for the indexes that are a way of finding a place rather than a
  /// portion to commit to — a page number is where you are, not what you read.
  final WirdKind? wirdKind;
  final String? wirdReference;

  bool get canJoinWird => wirdKind != null && wirdReference != null;
}
