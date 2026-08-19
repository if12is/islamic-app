import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../data/services/quran_api_service.dart';
import 'quran_page.dart'; // To import Surah model

/// Page for actually reading the Surah
class SurahReaderPage extends ConsumerStatefulWidget {
  final Surah? surah;
  final int? juzId;

  const SurahReaderPage({super.key, this.surah, this.juzId})
    : assert(surah != null || juzId != null);

  @override
  ConsumerState<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends ConsumerState<SurahReaderPage> {
  Color get _primaryDarkGreen => Theme.of(context).colorScheme.primary;
  Color get _accentGold => Theme.of(context).colorScheme.secondary;

  final QuranApiService _apiService = QuranApiService();

  List<dynamic> _verses = [];
  final List<TapGestureRecognizer> _recognizers = [];
  final Map<int, GlobalKey> _ayahKeys = {};
  bool _isLoading = true;
  String _errorKey = '';
  int _bookmarkedVerse = -1;
  int _bookmarkedAnchor = -1;
  double _fontSize = 28.0;
  final ScrollController _scrollController = ScrollController();
  int? _currentJuz;
  int? _currentHizbQuarter;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchSurahDetails();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Font Size
    setState(() {
      _fontSize = prefs.getDouble('quran_font_size') ?? 28.0;
    });

    // Load Bookmark
    final savedSurah = prefs.getInt('last_read_surah_id');
    if (widget.surah != null && savedSurah == widget.surah!.id) {
      final savedVerse = prefs.getInt('last_read_verse_num') ?? -1;
      setState(() {
        _bookmarkedVerse = savedVerse;
        _bookmarkedAnchor = savedVerse;
      });
    }
  }

  int _resolveAyahAnchorId(Map<String, dynamic> verseObj) {
    if (widget.surah != null) {
      return (verseObj['numberInSurah'] as int?) ??
          (verseObj['number'] as int?) ??
          0;
    }
    return (verseObj['number'] as int?) ??
        (verseObj['numberInSurah'] as int?) ??
        0;
  }

  String _monthlyReadSurahsKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return 'monthly_read_surahs_${now.year}_$month';
  }

  Future<void> _markSurahsAsReadForCurrentMonth(List<dynamic> ayahs) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthlyReadSurahsKey();

    final existingIds =
        (prefs.getStringList(key) ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();

    if (widget.surah != null) {
      existingIds.add(widget.surah!.id);
    } else {
      for (final ayah in ayahs) {
        final ayahMap = Map<String, dynamic>.from(ayah as Map);
        final surahMap =
            ayahMap['surah'] is Map<String, dynamic>
                ? ayahMap['surah'] as Map<String, dynamic>
                : null;
        final surahId = surahMap?['number'] as int?;
        if (surahId != null && surahId >= 1 && surahId <= 114) {
          existingIds.add(surahId);
        }
      }
    }

    final sorted = existingIds.toList()..sort();
    await prefs.setStringList(key, sorted.map((id) => id.toString()).toList());
  }

  void _scrollToAyah(int anchorId) {
    if (_ayahKeys.containsKey(anchorId) &&
        _ayahKeys[anchorId]!.currentContext != null) {
      Scrollable.ensureVisible(
        _ayahKeys[anchorId]!.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        alignment: 0.2, // Align near the top
      );
    }
  }

  void _changeFontSize(double delta) async {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(18.0, 50.0);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('quran_font_size', _fontSize);
  }

  @override
  void dispose() {
    for (var recognizer in _recognizers) {
      recognizer.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveBookmark(
    int verseNum, {
    int? surahIdOverride,
    String? nameAr,
    int? anchorVerseNum,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int sId = surahIdOverride ?? (widget.surah?.id ?? 1);
    await prefs.setInt('last_read_surah_id', sId);
    await prefs.setInt('last_read_verse_num', verseNum);

    // Save additional details to reconstruct the Surah obj in QuranPage
    if (widget.surah != null) {
      await prefs.setString('last_read_surah_nameAr', widget.surah!.nameAr);
      await prefs.setString('last_read_surah_nameEn', widget.surah!.nameEn);
      await prefs.setString('last_read_surah_type', widget.surah!.type);
      await prefs.setInt('last_read_surah_verses', widget.surah!.versesCount);
    } else if (nameAr != null) {
      await prefs.setString('last_read_surah_nameAr', nameAr);
    }

    setState(() {
      _bookmarkedVerse = verseNum;
      _bookmarkedAnchor = anchorVerseNum ?? verseNum;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('bookmark_saved_at_verse')} ${_formatLocalizedNumber(context, verseNum)}',
          ),
          backgroundColor: _primaryDarkGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchSurahDetails() async {
    setState(() {
      _isLoading = true;
      _errorKey = '';
    });

    try {
      final surahData =
          widget.surah != null
              ? await _apiService.fetchSurah(widget.surah!.id)
              : await _apiService.fetchJuz(widget.juzId!);
      if (surahData == null || surahData.isEmpty) {
        throw Exception('Empty data');
      }

      final ayahs = List<dynamic>.from(surahData['ayahs'] as List);
      await _markSurahsAsReadForCurrentMonth(ayahs);

      // Sort ayahs globally in case the API returns them unordered
      ayahs.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

      for (var recognizer in _recognizers) {
        recognizer.dispose();
      }
      _recognizers.clear();
      _ayahKeys.clear();

      // Initialize gesture recognizers and keys for each ayah
      for (var i = 0; i < ayahs.length; i++) {
        final ayahObj = Map<String, dynamic>.from(ayahs[i] as Map);
        final vNum = ayahObj['numberInSurah'] as int? ?? 1;
        final anchorId = _resolveAyahAnchorId(ayahObj);
        _ayahKeys[anchorId] = GlobalKey();

        final sObj = ayahObj['surah'];
        final sId = sObj != null ? sObj['number'] : null;
        final sNameAr =
            sObj != null
                ? (sObj['name'] as String).replaceFirst('سُورَةُ ', '')
                : null;

        final recognizer =
            TapGestureRecognizer()
              ..onTap = () {
                _saveBookmark(
                  vNum,
                  surahIdOverride: sId,
                  nameAr: sNameAr,
                  anchorVerseNum: anchorId,
                );
              };
        _recognizers.add(recognizer);
      }

      setState(() {
        _verses = ayahs;
        if (ayahs.isNotEmpty) {
          _currentJuz = ayahs[0]['juz'];
          _currentHizbQuarter = ayahs[0]['hizbQuarter'];
        }
        _isLoading = false;
      });

      // Scroll to bookmarked verse after rendering
      if (_bookmarkedAnchor != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _scrollToAyah(_bookmarkedAnchor);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorKey = 'unable_load_verses_later';
          _isLoading = false;
        });
      }
    }
  }

  String _formatLocalizedNumber(BuildContext context, int number) {
    if (context.isAppRtl) {
      return _convertToArabicNumber(number);
    }
    return number.toString();
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

  int _currentSurahNameIndex = 0;
  void _onScroll() {
    if (_ayahKeys.isEmpty || _verses.isEmpty) return;

    int topVerseIndex = 0;
    for (int i = 0; i < _verses.length; i++) {
      final verseObj = Map<String, dynamic>.from(_verses[i] as Map);
      final anchorId = _resolveAyahAnchorId(verseObj);
      final key = _ayahKeys[anchorId];
      if (key != null && key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          // AppBar is around 56-100 pixels depending on safe area and bottom widget
          // So > 140 is a safe threshold
          if (position.dy > 140) {
            topVerseIndex = i > 0 ? i - 1 : 0;
            break;
          }
          if (i == _verses.length - 1) {
            topVerseIndex = i;
          }
        }
      }
    }

    final topVerse = _verses[topVerseIndex];
    final juz = topVerse['juz'];
    final hizbQuarter = topVerse['hizbQuarter'];

    if (juz != null &&
        hizbQuarter != null &&
        (_currentJuz != juz ||
            _currentHizbQuarter != hizbQuarter ||
            _currentSurahNameIndex != topVerseIndex)) {
      setState(() {
        _currentJuz = juz;
        _currentHizbQuarter = hizbQuarter;
        _currentSurahNameIndex = topVerseIndex;
      });
    }
  }

  String _formatHizbQuarter(BuildContext context, int globalQuarter) {
    int hizb = ((globalQuarter - 1) ~/ 4) + 1;
    int quarter = ((globalQuarter - 1) % 4);

    String quarterText = '';
    if (quarter == 0) {
      quarterText = context.tr('hizb_label');
    } else if (quarter == 1) {
      quarterText = context.tr('quarter_hizb_label');
    } else if (quarter == 2) {
      quarterText = context.tr('half_hizb_label');
    } else if (quarter == 3) {
      quarterText = context.tr('three_quarters_hizb_label');
    }

    return '$quarterText ${_formatLocalizedNumber(context, hizb)}';
  }

  PreferredSizeWidget _buildDynamicHeader(bool isDark) {
    String hizbText =
        _currentHizbQuarter != null
            ? _formatHizbQuarter(context, _currentHizbQuarter!)
            : '';
    String juzText =
        _currentJuz != null
            ? '${context.tr('juz_word')} ${_formatLocalizedNumber(context, _currentJuz!)}'
            : '';

    String currentSurahName =
        context.isAppRtl
            ? (widget.surah?.nameAr ?? '')
            : (widget.surah?.nameEn ?? widget.surah?.nameAr ?? '');
    if (_verses.isNotEmpty && _currentSurahNameIndex < _verses.length) {
      final sObj = _verses[_currentSurahNameIndex]['surah'];
      if (sObj != null && sObj['name'] != null) {
        if (context.isAppRtl) {
          currentSurahName = (sObj['name'] as String).replaceFirst(
            'سُورَةُ ',
            '',
          );
        } else {
          currentSurahName =
              sObj['englishName'] as String? ??
              (sObj['name'] as String).replaceFirst('سُورَةُ ', '');
        }
      }
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(46.0),
      child: Container(
        height: 46.0,
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Color(0xFFE8F0EA),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.black : Colors.grey.shade300,
              width: 0.5,
            ),
            bottom: BorderSide(
              color: isDark ? Colors.black : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              juzText,
              style: TextStyle(
                color: isDark ? Theme.of(context).colorScheme.secondary : Color(0xFF0B4633),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: GoogleFonts.cairo().fontFamily,
              ),
            ),
            Text(
              '${context.tr('surah_word')} $currentSurahName',
              style: TextStyle(
                color: isDark ? Colors.white : Color(0xFF0B4633),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: GoogleFonts.cairo().fontFamily,
              ),
            ),
            Text(
              hizbText,
              style: TextStyle(
                color: isDark ? Theme.of(context).colorScheme.secondary : Color(0xFF0B4633),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: GoogleFonts.cairo().fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _convertToArabicNumber(int number) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final chars = number.toString().split('');
    return chars.map((char) => arabicNumbers[int.parse(char)]).join('');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final bgColor =
        isDark ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Theme.of(context).textTheme.bodyLarge!.color! : Colors.black87;
    final cardColor = isDark ? Theme.of(context).cardColor : Theme.of(context).cardColor;
    final appBarColor = bgColor;

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 1,
          iconTheme: IconThemeData(color: textColor),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            context.tr('quran_title_full'),
            style: GoogleFonts.amiriQuran(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: isDark ? Colors.white70 : _primaryDarkGreen,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: cardColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) => _buildSurahInfoSheet(isDark, textColor),
                );
              },
            ),
          ],
          bottom:
              (_isLoading || _errorKey.isNotEmpty)
                  ? null
                  : _buildDynamicHeader(isDark),
        ),
        body: Stack(
          children: [
            _isLoading
                ? Center(child: CustomLoader())
                : _errorKey.isNotEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr(_errorKey),
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSurahDetails,
                        child: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                )
                : _buildContinuousReadingView(textColor, cardColor, isDark),

            // Floating Toolbar at the bottom
            if (!_isLoading && _errorKey.isEmpty)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.5 : 0.1,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bookmark icon
                        IconButton(
                          icon: Icon(
                            _bookmarkedVerse != -1
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: _primaryDarkGreen,
                          ),
                          onPressed: () {
                            if (_bookmarkedAnchor != -1) {
                              _scrollToAyah(_bookmarkedAnchor);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr('tap_ayah_to_bookmark'),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        _buildDivider(isDark),
                        // Dark Mode icon
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color:
                                isDark
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.black87,
                          ),
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                        _buildDivider(isDark),
                        // Decrease Font
                        IconButton(
                          icon: Icon(
                            Icons.text_decrease,
                            color: isDark ? Theme.of(context).textTheme.bodyLarge!.color! : Colors.black87,
                          ),
                          onPressed: () => _changeFontSize(-2.0),
                        ),
                        _buildDivider(isDark),
                        // Increase Font
                        IconButton(
                          icon: Icon(
                            Icons.text_increase,
                            color: isDark ? Theme.of(context).textTheme.bodyLarge!.color! : Colors.black87,
                          ),
                          onPressed: () => _changeFontSize(2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 24,
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
    );
  }

  Widget _buildContinuousReadingView(
    Color textColor,
    Color cardColor,
    bool isDark,
  ) {
    List<Widget> contentChildren = [];
    List<InlineSpan> currentSpans = [];

    void flushSpans() {
      if (currentSpans.isNotEmpty) {
        contentChildren.add(
          RichText(
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            strutStyle: StrutStyle(
              fontSize: _fontSize,
              height: 2.5,
              leading: 0.5,
              fontFamily: GoogleFonts.amiriQuran().fontFamily,
            ),
            text: TextSpan(
              style: TextStyle(
                height: 2.2,
                wordSpacing: 3,
                color: textColor,
                fontFamily: GoogleFonts.amiriQuran().fontFamily,
              ),
              children: List.from(currentSpans),
            ),
          ),
        );
        currentSpans.clear();
      }
    }

    for (int i = 0; i < _verses.length; i++) {
      final verseObj = _verses[i] as Map<String, dynamic>;
      final verseNum = verseObj['numberInSurah'];
      final anchorId = _resolveAyahAnchorId(verseObj);
      final surahObj = verseObj['surah'];
      final surahId =
          surahObj != null ? surahObj['number'] : (widget.surah?.id ?? 1);
      final surahNameAr =
          surahObj != null
              ? (surahObj['name'] as String).replaceFirst('سُورَةُ ', '')
              : widget.surah?.nameAr ?? '';
      final surahNameEn =
          surahObj != null
              ? surahObj['englishName'] as String? ?? surahNameAr
              : (widget.surah?.nameEn.isNotEmpty ?? false)
              ? widget.surah!.nameEn
              : widget.surah?.nameAr ?? '';

      String rawText = verseObj['text'].toString();

      // If it's the first verse of a Surah, we insert a Surah Banner and Bismillah (if needed)
      if (verseNum == 1) {
        flushSpans(); // flush any previous surah's text

        // Build Surah Banner as a standalone Widget
        contentChildren.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 24, bottom: 16),
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Color(0xFFF0F5F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _primaryDarkGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              context.isAppRtl
                  ? '${context.tr('surah_word')} $surahNameAr'
                  : '${context.tr('surah_word')} $surahNameEn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? _accentGold : _primaryDarkGreen,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.cairo().fontFamily,
              ),
            ),
          ),
        );

        if (surahId != 1 && surahId != 9) {
          contentChildren.add(
            Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiriQuran(
                    fontSize: _fontSize + 2,
                    color: textColor,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Clean Basmalah from the first verse text if we already displayed it as a header
      if (verseNum == 1 && surahId != 1 && surahId != 9) {
        final cleanRaw = rawText.replaceAll(RegExp(r'[^ء-ي ]'), '');
        if (cleanRaw.startsWith('بسم الله الرحمن الرحيم')) {
          int matchCount = 0;
          int stripIndex = 0;
          for (int j = 0; j < rawText.length; j++) {
            if (RegExp(r'[ء-ي]').hasMatch(rawText[j])) {
              matchCount++;
            }
            if (matchCount == 22) {
              stripIndex = j + 1;
              break;
            }
          }
          if (stripIndex > 0 && stripIndex < rawText.length) {
            rawText = rawText.substring(stripIndex).trim();
          }
        } else {
          final bismillahPattern = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
          if (rawText.startsWith(bismillahPattern)) {
            rawText = rawText.substring(bismillahPattern.length).trim();
          } else if (rawText.startsWith(
            'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
          )) {
            rawText =
                rawText
                    .substring('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'.length)
                    .trim();
          }
        }
      }

      final isBookmarked = _bookmarkedAnchor == anchorId;
      final arabicNum = _convertToArabicNumber(verseNum);

      // Invisible anchor for scrolling to the beginning of the ayah
      currentSpans.add(
        WidgetSpan(
          child: SizedBox(key: _ayahKeys[anchorId], width: 0, height: 0),
        ),
      );

      currentSpans.add(
        TextSpan(
          text: '$rawText ',
          style: GoogleFonts.amiriQuran(
            fontSize: _fontSize,
            height: 2.2,
            color:
                isBookmarked
                    ? (isDark ? Theme.of(context).colorScheme.secondary : _primaryDarkGreen)
                    : textColor,
            backgroundColor:
                isBookmarked
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : _accentGold.withValues(alpha: 0.3))
                    : Colors.transparent,
          ),
          recognizer: _recognizers[i],
        ),
      );

      currentSpans.add(
        TextSpan(
          text: '﴿$arabicNum﴾ ',
          style: GoogleFonts.amiriQuran(
            fontSize: _fontSize,
            height: 2.2,
            color:
                isBookmarked
                    ? (isDark ? Theme.of(context).colorScheme.secondary : _primaryDarkGreen)
                    : (isDark ? Theme.of(context).colorScheme.onSurfaceVariant : _accentGold),
            backgroundColor:
                isBookmarked
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : _accentGold.withValues(alpha: 0.3))
                    : Colors.transparent,
          ),
          recognizer: _recognizers[i],
        ),
      );
    }

    // Flush remaining spans
    flushSpans();

    if (widget.surah != null && widget.surah!.id < 114) {
      contentChildren.add(const SizedBox(height: 32));
      contentChildren.add(
        Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (context) => SurahReaderPage(
                        surah: Surah(
                          id: widget.surah!.id + 1,
                          nameAr: 'السورة التالية',
                          nameEn: 'Next Surah',
                          versesCount: 0,
                          type: '',
                        ),
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('next_surah') != 'next_surah'
                      ? context.tr('next_surah')
                      : 'السورة التالية',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(left: 16, right: 16, top: 32, bottom: 100),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: contentChildren,
        ),
      ),
    );
  }

  Widget _buildSurahInfoSheet(bool isDark, Color textColor) {
    if (widget.surah == null) {
      return Container(
        padding: EdgeInsets.all(24),
        child: Text(
          context.tr('juz_info_unavailable'),
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('surah_info'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
          _infoRow(
            '${context.tr('name_label')}:',
            context.isAppRtl
                ? '${context.tr('surah_word')} ${widget.surah!.nameAr} (${widget.surah!.nameEn})'
                : '${context.tr('surah_word')} ${widget.surah!.nameEn} (${widget.surah!.nameAr})',
            textColor,
          ),
          SizedBox(height: 8),
          _infoRow(
            '${context.tr('type_label')}:',
            _localizedSurahType(context, widget.surah!.type),
            textColor,
          ),
          SizedBox(height: 8),
          _infoRow(
            '${context.tr('surah_number_label')}:',
            widget.surah!.id.toString(),
            textColor,
          ),
          SizedBox(height: 8),
          _infoRow(
            '${context.tr('ayah_count_label')}:',
            widget.surah!.versesCount.toString(),
            textColor,
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textColor) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
        ),
        SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
