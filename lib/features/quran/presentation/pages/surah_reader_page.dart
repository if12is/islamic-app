import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/islamic_ornaments.dart';
import '../../data/bookmark_store.dart';
import '../../data/services/quran_local_service.dart';
import '../../domain/tajweed_palette.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/quran_audio_provider.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/reading_progress_provider.dart';
import '../widgets/ayah_actions_sheet.dart';
import '../widgets/player_sheet.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/tajweed_text.dart';
import 'bookmarks_page.dart';
import 'hifz_page.dart';
import 'notes_page.dart';

/// The Quran reader.
///
/// Text comes from the bundled Mushaf, so opening a surah is instant and works
/// with no connection. Tapping a verse selects it and tapping it again opens
/// its actions — selecting is never the same thing as bookmarking.
class SurahReaderPage extends ConsumerStatefulWidget {
  const SurahReaderPage({
    super.key,
    this.surahNumber,
    this.juzNumber,
    this.hizbNumber,
    this.pageNumber,
    this.initialVerse,
    this.autoPlay = false,
  }) : assert(
         surahNumber != null ||
             juzNumber != null ||
             hizbNumber != null ||
             pageNumber != null,
         'Provide a surah, juz, hizb, or page to read',
       );

  final int? surahNumber;
  final int? juzNumber;
  final int? hizbNumber;
  final int? pageNumber;

  /// Verse to scroll to on open (search results, bookmarks, resume).
  final int? initialVerse;

  /// Start reciting as soon as the passage is loaded (notification actions).
  final bool autoPlay;

  @override
  ConsumerState<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends ConsumerState<SurahReaderPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _verseKeys = {};

  /// One recognizer per verse, kept for the life of the page so page mode can
  /// build and rebuild pages without disposing spans that are still on screen.
  final Map<String, TapGestureRecognizer> _tapRecognizers = {};

  List<QuranVerse> _verses = const [];
  String? _selectedKey;
  bool _loading = true;
  String _errorKey = '';

  int _headerJuz = 1;
  int _headerPage = 1;
  int _headerQuarter = 1;
  String _headerSurahName = '';

  Ticker? _autoScrollTicker;
  bool _autoScrolling = false;

  /// Elapsed time at the previous tick, so movement follows the clock.
  Duration _lastTick = Duration.zero;

  /// True while a finger is driving the scroll.
  bool _userIsScrolling = false;

  /// Pixels a second at speed 1.0 — a comfortable reading pace.
  static const double _pixelsPerSecond = 42;

  PageController? _pageController;
  List<int> _pages = const [];

  Timer? _saveDebounce;
  Timer? _readingClock;
  double? _previousBrightness;
  int _lastRecordedPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _startReadingClock();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-page must not lose the position, so write it now
    // instead of waiting for the scroll debounce.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveDebounce?.cancel();
      final verse = _currentVerse();
      if (verse != null) {
        _persistPosition(verse);
      }
    }
  }

  /// Where the reader is right now: the selected verse if there is one,
  /// otherwise whatever sits at the top of the viewport.
  QuranVerse? _currentVerse() {
    if (_selectedKey != null) {
      for (final verse in _verses) {
        if (verse.key == _selectedKey) {
          return verse;
        }
      }
    }
    return _firstVisibleVerse();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _readingClock?.cancel();
    _autoScrollTicker?.dispose();
    for (final recognizer in _tapRecognizers.values) {
      recognizer.dispose();
    }
    _pageController?.dispose();
    _scrollController.dispose();
    _releaseScreenSettings();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final verses = switch (widget) {
        SurahReaderPage(surahNumber: final surah?) =>
          QuranLocalService.versesOfSurah(surah),
        SurahReaderPage(juzNumber: final juz?) => QuranLocalService.versesOfJuz(
          juz,
        ),
        SurahReaderPage(hizbNumber: final hizb?) =>
          QuranLocalService.versesOfHizb(hizb),
        SurahReaderPage(pageNumber: final page?) =>
          QuranLocalService.versesOfPage(page),
        _ => const <QuranVerse>[],
      };

      _verseKeys.clear();
      for (final verse in verses) {
        _verseKeys[verse.key] = GlobalKey();
      }

      setState(() {
        _verses = verses;
        _loading = false;
        if (verses.isNotEmpty) {
          _headerJuz = verses.first.juz;
          _headerPage = verses.first.page;
          _headerQuarter = verses.first.hizbQuarter;
          _headerSurahName = verses.first.surahNameAr;
        }
      });

      if (verses.isNotEmpty) {
        _pages = _pageRangeFor(verses);
        _lastRecordedPage = verses.first.page;
        unawaited(
          ref
              .read(readingProgressProvider.notifier)
              .recordPage(verses.first.page),
        );
      }

      await _applyScreenSettings();
      _restorePosition();

      if (widget.autoPlay && verses.isNotEmpty) {
        final index =
            widget.initialVerse == null
                ? 0
                : verses.indexWhere(
                  (verse) => verse.numberInSurah == widget.initialVerse,
                );
        await _playFrom(verses[index < 0 ? 0 : index]);
      }
    } catch (e, stack) {
      AppLogger.error('Failed to load verses', e, stack);
      if (mounted) {
        setState(() {
          _errorKey = 'unable_load_verses_later';
          _loading = false;
        });
      }
    }
  }

  /// Jump to the requested verse, or back to where the reader stopped.
  void _restorePosition() {
    final target = _resolveResumeVerse();
    if (target == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _scrollToVerse(target, select: widget.initialVerse != null);
        }
      });
    });
  }

  String? _resolveResumeVerse() {
    if (widget.initialVerse != null && widget.surahNumber != null) {
      return '${widget.surahNumber}:${widget.initialVerse}';
    }

    final lastRead = ref.read(lastReadProvider);
    if (lastRead == null || widget.surahNumber == null) {
      return null;
    }
    if (lastRead.surahNumber != widget.surahNumber) {
      return null;
    }
    return '${lastRead.surahNumber}:${lastRead.verseNumber}';
  }

  Future<void> _applyScreenSettings() async {
    final settings = ref.read(readerSettingsProvider);

    if (settings.keepScreenOn) {
      await WakelockPlus.enable();
    }

    final brightness = settings.brightnessOverride;
    if (brightness != null) {
      try {
        _previousBrightness = await ScreenBrightness().application;
        await ScreenBrightness().setApplicationScreenBrightness(brightness);
      } catch (e) {
        AppLogger.warning('Brightness lock unavailable: $e');
      }
    }
  }

  Future<void> _releaseScreenSettings() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Nothing to release.
    }

    if (_previousBrightness != null) {
      try {
        await ScreenBrightness().resetApplicationScreenBrightness();
      } catch (_) {
        // Brightness already restored by the system.
      }
    }
  }

  void _onScroll() {
    if (_verses.isEmpty) {
      return;
    }

    final topVerse = _firstVisibleVerse();
    if (topVerse == null) {
      return;
    }

    if (topVerse.juz != _headerJuz ||
        topVerse.page != _headerPage ||
        topVerse.hizbQuarter != _headerQuarter ||
        topVerse.surahNameAr != _headerSurahName) {
      setState(() {
        _headerJuz = topVerse.juz;
        _headerPage = topVerse.page;
        _headerQuarter = topVerse.hizbQuarter;
        _headerSurahName = topVerse.surahNameAr;
      });
    }

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      _persistPosition(topVerse);
    });
  }

  QuranVerse? _firstVisibleVerse() {
    for (final verse in _verses) {
      final key = _verseKeys[verse.key];
      final renderObject = key?.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) {
        continue;
      }
      final position = renderObject.localToGlobal(Offset.zero);
      if (position.dy > 140) {
        return verse;
      }
    }
    return _verses.isEmpty ? null : _verses.last;
  }

  void _persistPosition(QuranVerse verse) {
    ref
        .read(lastReadProvider.notifier)
        .update(
          surahNumber: verse.surahNumber,
          verseNumber: verse.numberInSurah,
          scrollOffset:
              _scrollController.hasClients ? _scrollController.offset : 0,
        );

    // Feed the reading log, which drives the streak and the khatmah plan.
    if (verse.page != _lastRecordedPage) {
      _lastRecordedPage = verse.page;
      ref.read(readingProgressProvider.notifier).recordPage(verse.page);
    }
  }

  /// Counts reading time a minute at a time, so closing the app mid-session
  /// never loses what was already read.
  void _startReadingClock() {
    _readingClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      ref.read(readingProgressProvider.notifier).addMinutes(1);
    });
  }

  void _scrollToVerse(String verseKey, {bool select = false}) {
    final context = _verseKeys[verseKey]?.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );

    if (select) {
      setState(() => _selectedKey = verseKey);
    }
  }

  void _toggleAutoScroll() {
    if (_autoScrolling) {
      _autoScrollTicker?.stop();
      setState(() => _autoScrolling = false);
      return;
    }

    _lastTick = Duration.zero;
    _autoScrollTicker ??= createTicker(_onAutoScrollTick);
    _autoScrollTicker!.start();
    setState(() => _autoScrolling = true);
  }

  /// Advance the page by the time that has passed, not by a fixed step.
  ///
  /// Two things were wrong before. It moved a constant number of pixels per
  /// frame, so the speed depended on the refresh rate and the top of the range
  /// was still a crawl. And it called jumpTo on every frame, which cancels
  /// whatever scroll the reader has started — so the page could not be moved
  /// by hand at all while it was running. Now a drag simply wins, and the
  /// scroll picks up from wherever the reader let go, at the same pace.
  void _onAutoScrollTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      return;
    }

    final delta =
        _lastTick == Duration.zero ? Duration.zero : elapsed - _lastTick;
    _lastTick = elapsed;

    // A hand on the glass outranks the timer.
    if (_userIsScrolling) {
      return;
    }

    final position = _scrollController.position;
    final speed = ref.read(readerSettingsProvider).autoScrollSpeed;
    final next =
        position.pixels +
        _pixelsPerSecond * speed * delta.inMicroseconds / 1000000;

    if (next >= position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
      _autoScrollTicker?.stop();
      setState(() => _autoScrolling = false);
      return;
    }

    _scrollController.jumpTo(next);
  }

  /// Notice when the reader takes over, and stand aside until they let go.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _userIsScrolling = true;
      }
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
      _userIsScrolling = false;
    }
    return false;
  }

  Future<void> _playFrom(QuranVerse verse) async {
    final index = _verses.indexWhere((item) => item.key == verse.key);
    if (index < 0) {
      return;
    }

    final settings = ref.read(readerSettingsProvider);
    await ref
        .read(quranAudioProvider.notifier)
        .playVerses(
          _verses,
          startIndex: index,
          reciterCode: QuranReciter.verseAudioCode(settings.reciterCode),
        );
  }

  void _openActions(QuranVerse verse) {
    setState(() => _selectedKey = verse.key);
    AyahActionsSheet.show(
      context,
      verse: verse,
      onPlayFromHere: () => _playFrom(verse),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final palette = settings.paletteFor(context);
    final audio = ref.watch(quranAudioProvider);

    // Follow the recitation: keep the verse being recited on screen.
    ref.listen<QuranAudioState>(quranAudioProvider, (previous, next) {
      final key = next.currentKey;
      if (key != null && key != previous?.currentKey) {
        _scrollToVerse(key);
      }
    });

    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];
    final bookmarkedKeys = bookmarks.map((item) => item.key).toSet();

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: _appBar(palette),
        body: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator.adaptive())
            else if (_errorKey.isNotEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr(_errorKey)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: Text(context.tr('retry')),
                    ),
                  ],
                ),
              )
            else if (settings.viewMode == ReaderViewMode.pages)
              _pagesView(settings, palette, bookmarkedKeys, audio)
            else
              _readingView(settings, palette, bookmarkedKeys, audio),
            if (!_loading && _errorKey.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(child: _toolbar(palette, audio)),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(ReaderPalette palette) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.text,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: Center(
        child: Material(
          color: palette.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                context.isAppRtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                size: 19,
                color: palette.text,
              ),
            ),
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _pageTitle(),
            style: TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          Text(
            '${context.tr('juz_word')} ${_localizedNumber(_headerJuz)}'
            ' · ${_hizbLabel(_headerQuarter)}'
            ' · ${context.tr('page_word')} ${_localizedNumber(_headerPage)}',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: palette.accent,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.tr('bookmarks'),
          icon: const Icon(Icons.bookmarks_outlined, size: 20),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BookmarksPage()),
              ),
        ),
        IconButton(
          tooltip: context.tr('my_reflections'),
          icon: const Icon(Icons.edit_note, size: 20),
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NotesPage()),
              ),
        ),
        IconButton(
          tooltip: context.tr('hifz'),
          icon: const Icon(Icons.psychology_alt_outlined, size: 20),
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const HifzPage())),
        ),
      ],
    );
  }

  /// The pages this passage covers, in order.
  /// Every page of the Mushaf, so a swipe carries on past the last verse of
  /// the surah the way turning a page does.
  ///
  /// This used to be only the pages the open surah touches, which meant the
  /// reader hit a wall at both ends of it — no next page, no previous one.
  /// [verses] is kept for the caller's convenience; the range is the book.
  List<int> _pageRangeFor(List<QuranVerse> verses) =>
      List<int>.generate(QuranLocalService.pageCount, (index) => index + 1);

  TapGestureRecognizer _recognizerFor(QuranVerse verse) {
    return _tapRecognizers.putIfAbsent(verse.key, () {
      return TapGestureRecognizer()
        ..onTap = () {
          // One tap selects, a second tap on the same verse opens its tools.
          if (_selectedKey == verse.key) {
            _openActions(verse);
          } else {
            setState(() => _selectedKey = verse.key);
            // Tapping a verse says "this is where I am" more clearly than
            // any scroll position does.
            _persistPosition(verse);
          }
        };
    });
  }

  /// Turns verses into laid-out blocks: surah banners, basmalah, and justified
  /// text with tappable ayah spans. Shared by both view modes.
  List<Widget> _verseBlocks(
    List<QuranVerse> verses,
    ReaderSettings settings,
    ReaderPalette palette,
    Set<String> bookmarkedKeys,
    QuranAudioState audio, {
    bool showBanners = true,
  }) {
    final blocks = <Widget>[];
    var spans = <InlineSpan>[];
    var currentSurah = -1;

    void flush() {
      if (spans.isEmpty) {
        return;
      }
      blocks.add(
        RichText(
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          strutStyle: StrutStyle(
            fontSize: settings.fontSize,
            height: settings.lineHeight,
            forceStrutHeight: true,
            fontFamily: settings.font.family,
          ),
          text: TextSpan(
            style: TextStyle(
              fontFamily: settings.font.family,
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              color: palette.text,
            ),
            children: List<InlineSpan>.from(spans),
          ),
        ),
      );
      spans = <InlineSpan>[];
    }

    for (final verse in verses) {
      if (verse.surahNumber != currentSurah) {
        flush();
        currentSurah = verse.surahNumber;
        if (showBanners || verse.isFirstOfSurah) {
          blocks.add(_surahBanner(verse, palette));
          if (verse.isFirstOfSurah &&
              verse.surahNumber != 1 &&
              verse.surahNumber != 9) {
            blocks.add(_basmalah(settings, palette));
          }
        }
      }

      final isSelected = _selectedKey == verse.key;
      final isPlaying = audio.currentKey == verse.key;
      final isBookmarked = bookmarkedKeys.contains(verse.key);
      final recognizer = _recognizerFor(verse);

      spans.add(
        WidgetSpan(
          child: SizedBox(key: _verseKeys[verse.key], width: 0, height: 0),
        ),
      );

      final background =
          isPlaying
              ? palette.highlight
              : isSelected
              ? palette.highlight.withValues(alpha: 0.5)
              : isBookmarked
              ? palette.accent.withValues(alpha: 0.12)
              : null;

      final verseStyle = TextStyle(
        color: isPlaying ? palette.accent : palette.text,
        backgroundColor: background,
      );

      // Tajweed colouring gives way to the playing highlight: while a verse is
      // being recited the reader is following the voice, and two colour
      // systems fighting over the same letters helps with neither.
      if (settings.showTajweed && !isPlaying) {
        spans.addAll(
          TajweedText.spansFor(
            text: '${verse.text} ',
            baseStyle: verseStyle,
            palette: TajweedPalette.forGround(isDark: palette.isDark),
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '${verse.text} ',
            style: verseStyle,
            recognizer: recognizer,
          ),
        );
      }

      if (settings.showVerseNumbers) {
        spans.add(
          TextSpan(
            text: '﴿${_arabicNumber(verse.numberInSurah)}﴾ ',
            style: TextStyle(color: palette.accent),
            recognizer: recognizer,
          ),
        );
      }

      if (verse.isSajdah) {
        spans.add(
          TextSpan(text: '۩ ', style: TextStyle(color: palette.accent)),
        );
      }
    }

    flush();
    return blocks;
  }

  /// Continuous scroll.
  Widget _readingView(
    ReaderSettings settings,
    ReaderPalette palette,
    Set<String> bookmarkedKeys,
    QuranAudioState audio,
  ) {
    final blocks = _verseBlocks(
      _verses,
      settings,
      palette,
      bookmarkedKeys,
      audio,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          settings.horizontalPadding,
          24,
          settings.horizontalPadding,
          140,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...blocks,
              const SizedBox(height: 24),
              _nextSurahButton(palette),
            ],
          ),
        ),
      ),
    );
  }

  /// Page by page, the way a printed Mushaf is read.
  Widget _pagesView(
    ReaderSettings settings,
    ReaderPalette palette,
    Set<String> bookmarkedKeys,
    QuranAudioState audio,
  ) {
    if (_pages.isEmpty) {
      return const SizedBox.shrink();
    }

    _pageController ??= PageController(
      initialPage: _pages.indexOf(_headerPage).clamp(0, _pages.length - 1),
    );

    return PageView.builder(
      controller: _pageController,
      // RTL: swiping from the left edge moves forward, like turning a Mushaf.
      reverse: true,
      itemCount: _pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final page = _pages[index];
        final verses = QuranLocalService.versesOfPage(page);
        final blocks = _verseBlocks(
          verses,
          settings,
          palette,
          bookmarkedKeys,
          audio,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            settings.horizontalPadding,
            16,
            settings.horizontalPadding,
            140,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...blocks,
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    '${context.tr('page_word')} ${_localizedNumber(page)}',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Page mode has no scroll listener, so the header and the log update here.
  void _onPageChanged(int index) {
    final page = _pages[index];
    final verses = QuranLocalService.versesOfPage(page);
    if (verses.isEmpty) {
      return;
    }

    final first = verses.first;
    setState(() {
      _headerJuz = first.juz;
      _headerPage = first.page;
      _headerQuarter = first.hizbQuarter;
      _headerSurahName = first.surahNameAr;
    });

    _persistPosition(first);
  }

  /// The head of a surah, drawn as an arch rather than boxed in a border.
  Widget _surahBanner(QuranVerse verse, ReaderPalette palette) {
    final surah = QuranLocalService.surahInfo(verse.surahNumber);

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: CustomPaint(
          painter: _SurahHeaderPainter(color: palette.accent),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                verse.surahNameAr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  fontSize: 22,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              Text(
                '${_localizedNumber(surah.versesCount)} '
                '${context.tr('verses')}',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  color: palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basmalah(ReaderSettings settings, ReaderPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: settings.font.family,
          fontSize: settings.fontSize * 0.9,
          color: palette.text,
        ),
      ),
    );
  }

  Widget _nextSurahButton(ReaderPalette palette) {
    final currentSurah = widget.surahNumber;
    if (currentSurah == null || currentSurah >= QuranLocalService.surahCount) {
      return const SizedBox.shrink();
    }

    return Center(
      child: FilledButton.icon(
        onPressed:
            () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => SurahReaderPage(surahNumber: currentSurah + 1),
              ),
            ),
        icon: const Icon(Icons.arrow_back_ios_new, size: 16),
        label: Text(context.tr('next_surah')),
      ),
    );
  }

  Widget _toolbar(ReaderPalette palette, QuranAudioState audio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.5 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('reader_settings'),
            icon: Icon(Icons.tune, color: palette.text),
            onPressed: () => ReaderSettingsSheet.show(context),
          ),
          _divider(palette),
          IconButton(
            tooltip: context.tr(_autoScrolling ? 'stop_scroll' : 'auto_scroll'),
            icon: Icon(
              _autoScrolling ? Icons.pause_circle : Icons.swipe_vertical,
              color: _autoScrolling ? palette.accent : palette.text,
            ),
            onPressed: _toggleAutoScroll,
          ),
          _divider(palette),
          IconButton(
            tooltip: context.tr('listen'),
            icon:
                audio.loading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                    : Icon(
                      audio.playing ? Icons.pause : Icons.play_arrow,
                      color: audio.playing ? palette.accent : palette.text,
                    ),
            onPressed: () {
              if (audio.hasQueue) {
                ref.read(quranAudioProvider.notifier).toggle();
                return;
              }
              final start = _verses.firstWhere(
                (verse) => verse.key == _selectedKey,
                orElse: () => _verses.first,
              );
              _playFrom(start);
            },
          ),
          _divider(palette),
          IconButton(
            tooltip: context.tr('player'),
            icon: Icon(
              Icons.graphic_eq,
              color:
                  audio.isRepeatingRange || audio.hasSleepTimer
                      ? palette.accent
                      : palette.text,
            ),
            onPressed: () => PlayerSheet.show(context, _verses),
          ),
          _divider(palette),
          IconButton(
            tooltip: context.tr('add_bookmark'),
            icon: Icon(Icons.bookmark_add_outlined, color: palette.text),
            onPressed: () {
              final verse = _verses.firstWhere(
                (item) => item.key == _selectedKey,
                orElse: () => _firstVisibleVerse() ?? _verses.first,
              );
              _openActions(verse);
            },
          ),
        ],
      ),
    );
  }

  Widget _divider(ReaderPalette palette) {
    return Container(
      width: 1,
      height: 22,
      color: palette.text.withValues(alpha: 0.15),
    );
  }

  /// What this reading session is: a surah, a juz, a hizb, or a page.
  String _pageTitle() {
    if (widget.juzNumber != null) {
      return '${context.tr('juz_word')} ${_localizedNumber(widget.juzNumber!)}';
    }
    if (widget.hizbNumber != null) {
      return '${context.tr('hizb_label')} '
          '${_localizedNumber(widget.hizbNumber!)}';
    }
    if (widget.pageNumber != null) {
      return '${context.tr('page_word')} '
          '${_localizedNumber(widget.pageNumber!)}';
    }
    return '${context.tr('surah_word')} $_headerSurahName';
  }

  /// `الحزب ٣` / `ربع الحزب ٣` … for the running header.
  String _hizbLabel(int quarter) {
    final hizb = ((quarter - 1) ~/ 4) + 1;
    final position = (quarter - 1) % 4;
    final label = switch (position) {
      1 => context.tr('quarter_hizb_label'),
      2 => context.tr('half_hizb_label'),
      3 => context.tr('three_quarters_hizb_label'),
      _ => context.tr('hizb_label'),
    };
    return '$label ${_localizedNumber(hizb)}';
  }

  String _localizedNumber(int value) =>
      context.isAppRtl ? _arabicNumber(value) : value.toString();

  static String _arabicNumber(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }
}

/// Bookmark colour used by both the reader and the bookmarks list.
Color bookmarkTagColor(BookmarkTag tag, ColorScheme scheme) {
  switch (tag) {
    case BookmarkTag.favorite:
      return scheme.primary;
    case BookmarkTag.memorize:
      return scheme.secondary;
    case BookmarkTag.reflect:
      return scheme.tertiary;
    case BookmarkTag.review:
      return scheme.error;
  }
}

/// The ornament behind a surah's name: a pointed arch with a thin rule running
/// out to each side, the way a printed Mushaf marks the head of a chapter.
class _SurahHeaderPainter extends CustomPainter {
  const _SurahHeaderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(
      size.width * 0.16,
      2,
      size.width * 0.68,
      size.height - 4,
    );
    final arch = IslamicOrnaments.archPath(frame, pointPixels: 34);

    canvas
      ..drawPath(arch, Paint()..color = color.withValues(alpha: 0.07))
      ..drawPath(
        arch,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );

    final rule =
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1;
    final middle = size.height / 2;
    canvas
      ..drawLine(Offset(0, middle), Offset(frame.left - 12, middle), rule)
      ..drawLine(
        Offset(frame.right + 12, middle),
        Offset(size.width, middle),
        rule,
      )
      ..drawCircle(Offset(frame.left - 20, middle), 2.5, Paint()..color = color)
      ..drawCircle(
        Offset(frame.right + 20, middle),
        2.5,
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(covariant _SurahHeaderPainter old) => old.color != color;
}
