import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/widgets/shell_header_buttons.dart';
import '../../data/services/quran_api_service.dart';
import 'surah_reader_page.dart';
import 'package:just_audio/just_audio.dart';

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

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  // Constants & Colors
  Color get _bgOffWhite => Theme.of(context).scaffoldBackgroundColor;
  Color get _primaryDarkGreen => Theme.of(context).colorScheme.primary;
  Color get _accentGold => Theme.of(context).colorScheme.secondary;

  // Services
  final QuranApiService _apiService = QuranApiService();

  // States
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedReciterUrl = 'https://server12.mp3quran.net/maher';
  final Map<String, String> _reciters = {
    'https://server12.mp3quran.net/maher': 'الشيخ ماهر المعيقلي',
    'https://server11.mp3quran.net/sds': 'الشيخ عبدالرحمن السديس',
    'https://server8.mp3quran.net/afs': 'الشيخ مشاري العفاسي',
  };
  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];
  final List<int> _allJuzNumbers = List<int>.generate(30, (index) => index + 1);
  List<int> _filteredJuzNumbers = List<int>.generate(30, (index) => index + 1);
  List<AyahSearchResult> _ayahSearchResults = [];
  bool _isLoading = true;
  bool _isAyahSearchLoading = false;
  bool _isSurahMode = true;
  String _errorKey = '';

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _dynamicNextPrayerKey = 'fajr';
  int? _currentlyPlayingSurahId;
  double _khatmahProgress = 0.0;
  int _monthlyReadSurahsCount = 0;

  // Mocked Last Read state (could be loaded from SharedPreferences)
  Surah? _lastReadSurah;
  int _lastReadVerse = 1;

  @override
  void initState() {
    super.initState();
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _currentlyPlayingSurahId = null;
          });
        }
      } else {
        if (mounted) setState(() {});
      }
    });

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _dynamicNextPrayerKey = 'dhuhr';
        });
      }
    });
  }

  Future<void> _fetchSurahs() async {
    setState(() {
      _isLoading = true;
      _errorKey = '';
    });

    try {
      final rawList = await _apiService.fetchSurahsList();
      if (rawList.isEmpty) {
        setState(() {
          _errorKey = 'unable_load_surahs_now';
          _isLoading = false;
        });
        return;
      }

      final surahs =
          rawList.map((json) {
            final safeMap = Map<String, dynamic>.from(json as Map);
            return Surah.fromApiJson(safeMap);
          }).toList();

      final prefs = await SharedPreferences.getInstance();
      final lastReadId = prefs.getInt('last_read_surah_id');
      final lastReadVerseNum = prefs.getInt('last_read_verse_num') ?? 1;
      final monthlyReadCount = _countMonthlyReadSurahs(prefs);
      final monthlyProgress =
          (monthlyReadCount / 114).clamp(0.0, 1.0).toDouble();

      Surah? savedSurah;
      if (lastReadId != null) {
        savedSurah = surahs.cast<Surah?>().firstWhere(
          (s) => s?.id == lastReadId,
          orElse: () => null,
        );
      }

      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = List.from(surahs);
        _lastReadSurah =
            savedSurah ??
            surahs.cast<Surah?>().firstWhere(
              (s) => s?.id == 18,
              orElse: () => surahs.first,
            );
        _lastReadVerse = lastReadVerseNum;
        _monthlyReadSurahsCount = monthlyReadCount;
        _khatmahProgress = monthlyProgress;
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

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReadId = prefs.getInt('last_read_surah_id');
    final lastReadVerseNum = prefs.getInt('last_read_verse_num') ?? 1;

    if (lastReadId != null && _allSurahs.isNotEmpty) {
      final savedSurah = _allSurahs.cast<Surah?>().firstWhere(
        (s) => s?.id == lastReadId,
        orElse: () => null,
      );
      if (savedSurah != null) {
        setState(() {
          _lastReadSurah = savedSurah;
          _lastReadVerse = lastReadVerseNum;
        });
      }
    }

    await _loadMonthlyKhatmahProgress();
  }

  String _monthlyReadSurahsKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return 'monthly_read_surahs_${now.year}_$month';
  }

  int _countMonthlyReadSurahs(SharedPreferences prefs) {
    final savedIds =
        prefs.getStringList(_monthlyReadSurahsKey()) ?? const <String>[];
    final uniqueValidIds =
        savedIds
            .map(int.tryParse)
            .whereType<int>()
            .where((id) => id >= 1 && id <= 114)
            .toSet();
    return uniqueValidIds.length;
  }

  Future<void> _loadMonthlyKhatmahProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final monthlyReadCount = _countMonthlyReadSurahs(prefs);
    if (!mounted) return;

    setState(() {
      _monthlyReadSurahsCount = monthlyReadCount;
      _khatmahProgress = (monthlyReadCount / 114).clamp(0.0, 1.0).toDouble();
    });
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

    setState(() {
      if (normalizedDigitsQuery.isEmpty) {
        _filteredJuzNumbers = List.from(_allJuzNumbers);
      } else {
        _filteredJuzNumbers =
            _allJuzNumbers.where((juz) {
              return juz.toString().contains(normalizedDigitsQuery) ||
                  _toArabicDigits(juz).contains(rawQuery);
            }).toList();
      }
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

    final rawMatches = await _apiService.searchAyah(trimmed);
    if (!mounted) return;

    // Ignore stale search responses from previous queries.
    if (_searchController.text.trim() != trimmed || !_isSurahMode) {
      return;
    }

    final parsedMatches =
        rawMatches
            .map(
              (json) => AyahSearchResult.fromApiJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();

    setState(() {
      _ayahSearchResults = parsedMatches;
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

  void _setListMode(bool showSurahs) {
    if (_isSurahMode == showSurahs) return;

    setState(() {
      _isSurahMode = showSurahs;
      if (!showSurahs) {
        _ayahSearchResults = [];
        _isAyahSearchLoading = false;
      }
    });

    _onSearchChanged();
  }

  void _togglePlayPause(int surahId) async {
    try {
      if (_currentlyPlayingSurahId == surahId) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        setState(() {});
      } else {
        setState(() {
          _currentlyPlayingSurahId = surahId;
        });

        // Use the selected reciter
        final url =
            '$_selectedReciterUrl/${surahId.toString().padLeft(3, '0')}.mp3';
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            !uri.host.endsWith('mp3quran.net')) {
          throw StateError('Untrusted reciter URL');
        }

        await _audioPlayer.setUrl(url);
        await _audioPlayer.play();
      }
    } catch (e) {
      AppLogger.warning('Error playing audio: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: _bgOffWhite,
        appBar: _buildCustomAppBar(),
        body: Stack(
          children: [
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              )
            else if (_errorKey.isNotEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.tr(_errorKey),
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchSurahs,
                      child: Text(context.tr('retry')),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: 100.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    if (_lastReadSurah != null) _buildHeroLastRead(),
                    const SizedBox(height: 20),
                    _buildMonthlyKhatmah(),
                    const SizedBox(height: 24),
                    _buildModeToggle(),
                    const SizedBox(height: 16),
                    _buildSurahIndexHeader(),
                    const SizedBox(height: 12),
                    _isSurahMode ? _buildSurahList() : _buildJuzList(),
                    if (_isSurahMode &&
                        _searchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildAyahSearchHeader(),
                      const SizedBox(height: 12),
                      _buildAyahSearchResults(),
                    ],
                  ],
                ),
              ),

            // Floating Audio Player
            if (_currentlyPlayingSurahId != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24.0,
                      left: 32.0,
                      right: 32.0,
                    ),
                    child: _buildAudioPlayerBar(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: const ShellMenuButton(),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          context.tr(_dynamicNextPrayerKey),
          key: ValueKey<String>(_dynamicNextPrayerKey),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      centerTitle: true,
      actions: const [ShellProfileButton()],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText:
              _isSurahMode
                  ? context.tr('search_surah_or_number_hint')
                  : context.tr('search_juz_hint'),
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!),
      ),
    );
  }

  Widget _buildHeroLastRead() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -20,
            left: -10,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.menu_book, size: 140, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('last_read'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.isAppRtl
                      ? '${context.tr('surah_word')} ${_lastReadSurah!.nameAr}'
                      : '${context.tr('surah_word')} ${_lastReadSurah!.nameEn}',
                  style: GoogleFonts.amiriQuran(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.tr('reached_verse')}: ${_formatNumber(context, _lastReadVerse)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      SurahReaderPage(surah: _lastReadSurah!),
                            ),
                          )
                          .then((_) {
                            _loadLastRead();
                          });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('continue_reading'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_back, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyKhatmah() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_border, color: _accentGold, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr('monthly_khatmah'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _khatmahProgress,
              minHeight: 12,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr('completed_percent')} ${_formatNumber(context, (_khatmahProgress * 100).toInt())}%',
                style: TextStyle(
                  color: _primaryDarkGreen, // green
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${context.tr('goal')}: 100%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${context.tr('read_count_this_month')} ${_formatNumber(context, _monthlyReadSurahsCount)} ${context.tr('from_total_surahs')} 114',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildModeButton(label: context.tr('surahs_tab'), showSurahs: true),
          const SizedBox(width: 8),
          _buildModeButton(label: context.tr('juz_tab'), showSurahs: false),
        ],
      ),
    );
  }

  Widget _buildModeButton({required String label, required bool showSurahs}) {
    final isSelected = _isSurahMode == showSurahs;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setListMode(showSurahs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahIndexHeader() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final title =
        _isSurahMode
            ? (hasQuery
                ? context.tr('surahs_results')
                : context.tr('surahs_index'))
            : context.tr('juz_index');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color!,
          ),
        ),
        if (_isSurahMode)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () {
                setState(() {
                  _filteredSurahs = _filteredSurahs.reversed.toList();
                });
              },
            ),
          ),
        if (!_isSurahMode)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_formatNumber(context, _filteredJuzNumbers.length)} ${context.tr('juz_word')}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSurahList() {
    if (_filteredSurahs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.tr('no_surah_match'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSurahs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final surah = _filteredSurahs[index];
        final isPlaying =
            _currentlyPlayingSurahId == surah.id && _audioPlayer.playing;

        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => SurahReaderPage(surah: surah),
                  ),
                )
                .then((_) {
                  _loadLastRead();
                });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      surah.id.toString(),
                      style: TextStyle(
                        color: _primaryDarkGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.isAppRtl
                            ? '${context.tr('surah_word')} ${surah.nameAr}'
                            : '${context.tr('surah_word')} ${surah.nameEn}',
                        style: GoogleFonts.amiriQuran(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge!.color!,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatNumber(context, surah.versesCount)} ${context.tr('verses')} • ${_localizedSurahType(context, surah.type)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      surah.nameEn,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _togglePlayPause(surah.id),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (
                          Widget child,
                          Animation<double> animation,
                        ) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          key: ValueKey<bool>(isPlaying),
                          color: isPlaying ? _accentGold : _primaryDarkGreen,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJuzList() {
    if (_filteredJuzNumbers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.tr('no_juz_match'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredJuzNumbers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final juzNumber = _filteredJuzNumbers[index];

        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => SurahReaderPage(juzId: juzNumber),
                  ),
                )
                .then((_) {
                  _loadLastRead();
                });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _formatNumber(context, juzNumber),
                      style: TextStyle(
                        color: _primaryDarkGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('juz_word')} ${_formatNumber(context, juzNumber)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color!,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('tap_to_read_full_juz'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Juz $juzNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _primaryDarkGreen,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            final surah = Surah(
              id: result.surahId,
              nameAr: result.surahNameAr,
              nameEn: result.surahNameEn,
              versesCount: 0,
              type: '',
            );

            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => SurahReaderPage(surah: surah),
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
              border: Border.all(color: _primaryDarkGreen.withValues(alpha: 0.08)),
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
                  style: GoogleFonts.amiriQuran(
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

  Widget _buildAudioPlayerBar() {
    final surah = _allSurahs.firstWhere(
      (s) => s.id == _currentlyPlayingSurahId,
      orElse: () => _allSurahs.first,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        context.isAppRtl ? surah.nameAr : surah.nameEn,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedReciterUrl,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        items:
                            _reciters.entries.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedReciterUrl = val;
                            });
                            final wasPlaying = _audioPlayer.playing;
                            final url =
                                '$_selectedReciterUrl/${surah.id.toString().padLeft(3, '0')}.mp3';
                            _audioPlayer.setUrl(url).then((_) {
                              if (wasPlaying) {
                                _audioPlayer.play();
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                StreamBuilder<Duration>(
                  stream: _audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = _audioPlayer.duration ?? Duration.zero;
                    final progress =
                        duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;
                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              _audioPlayer.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: Theme.of(context).colorScheme.primary,
              size: 36,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              if (_audioPlayer.playing) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play();
              }
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurfaceVariant),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _audioPlayer.stop();
              setState(() {
                _currentlyPlayingSurahId = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
