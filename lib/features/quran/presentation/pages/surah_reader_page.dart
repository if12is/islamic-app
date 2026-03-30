import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/quran_api_service.dart';
import 'quran_page.dart'; // To import Surah model

/// Page for actually reading the Surah
class SurahReaderPage extends StatefulWidget {
  final Surah surah;
  
  const SurahReaderPage({Key? key, required this.surah}) : super(key: key);

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  // Constants & Colors
  final Color _bgOffWhite = const Color(0xFFF8F9FA);
  final Color _primaryDarkGreen = const Color(0xFF0B4633);
  final Color _accentGold = const Color(0xFFF6D167);

  final QuranApiService _apiService = QuranApiService();
  
  List<dynamic> _verses = [];
  List<TapGestureRecognizer> _recognizers = [];
  bool _isLoading = true;
  String _errorMsg = '';
  int _bookmarkedVerse = -1;
  ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadBookmark();
    _fetchSurahDetails();
  }
  
  @override
  void dispose() {
    for (var recognizer in _recognizers) {
      recognizer.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSurah = prefs.getInt('last_read_surah_id');
    if (savedSurah == widget.surah.id) {
      setState(() {
        _bookmarkedVerse = prefs.getInt('last_read_verse_num') ?? -1;
      });
    }
  }

  Future<void> _saveBookmark(int verseNum) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_surah_id', widget.surah.id);
    await prefs.setInt('last_read_verse_num', verseNum);
    
    // Save additional details to reconstruct the Surah obj in QuranPage
    await prefs.setString('last_read_surah_nameAr', widget.surah.nameAr);
    await prefs.setString('last_read_surah_nameEn', widget.surah.nameEn);
    await prefs.setString('last_read_surah_type', widget.surah.type);
    await prefs.setInt('last_read_surah_verses', widget.surah.versesCount);
    
    setState(() {
      _bookmarkedVerse = verseNum;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ العلامة عند الآية $verseNum'),
          backgroundColor: _primaryDarkGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchSurahDetails() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final surahData = await _apiService.fetchSurah(widget.surah.id);
      if (surahData == null || surahData.isEmpty) {
        throw Exception('Empty data');
      }

      final ayahs = List<dynamic>.from(surahData['ayahs'] as List);
      
      // Initialize gesture recognizers for each ayah
      for (var i = 0; i < ayahs.length; i++) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            _saveBookmark(ayahs[i]['numberInSurah']);
          };
        _recognizers.add(recognizer);
      }

      setState(() {
        _verses = ayahs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'فشل في تحميل آيات السورة. يرجى المحاولة لاحقاً.';
          _isLoading = false;
        });
      }
    }
  }

  String _convertToArabicNumber(int number) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final chars = number.toString().split('');
    return chars.map((char) => arabicNumbers[int.parse(char)]).join('');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgOffWhite,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'سورة ${widget.surah.nameAr}',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: _primaryDarkGreen),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => _buildSurahInfoSheet(),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMsg, style: TextStyle(color: Colors.red.shade800)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSurahDetails,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : _buildContinuousReadingView(),
      ),
    );
  }

  Widget _buildContinuousReadingView() {
    List<InlineSpan> spans = [];

    // Optional Basmalah at the top (except Al-Fatiha and At-Tawbah)
    if (widget.surah.id != 1 && widget.surah.id != 9) {
      spans.add(
        TextSpan(
          text: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\n\n',
          style: GoogleFonts.amiriQuran(
            fontSize: 28,
            color: Colors.black87,
            height: 2.0,
          ),
        ),
      );
    }

    for (int i = 0; i < _verses.length; i++) {
      final verseObj = _verses[i] as Map<String, dynamic>;
      final verseNum = verseObj['numberInSurah'];
      String rawText = verseObj['text'].toString();

      // Clean Basmalah from the first verse text if we already displayed it as a header
      if (i == 0 && widget.surah.id != 1 && widget.surah.id != 9) {
        final bismillahPattern = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
        // Note: Sometimes the API returns it with a trailing space, or slightly different diacritics. We do our best.
        if (rawText.startsWith(bismillahPattern)) {
          rawText = rawText.substring(bismillahPattern.length).trim();
        } else if (rawText.startsWith('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ')) {
          rawText = rawText.substring('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'.length).trim();
        }
      }
      
      final isBookmarked = _bookmarkedVerse == verseNum;
      final arabicNum = _convertToArabicNumber(verseNum);

      spans.add(
        TextSpan(
          text: '$rawText ',
          style: GoogleFonts.amiriQuran(
            fontSize: 28,
            height: 2.2,
            color: isBookmarked ? _primaryDarkGreen : Colors.black87,
            backgroundColor: isBookmarked ? _accentGold.withOpacity(0.3) : Colors.transparent,
          ),
          recognizer: _recognizers[i],
        ),
      );

      // Ayah End Symbol
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _saveBookmark(verseNum),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.brightness_high, 
                    color: isBookmarked ? _primaryDarkGreen : _accentGold, 
                    size: 38
                  ),
                  Text(
                    arabicNum,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isBookmarked ? _accentGold : _primaryDarkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      spans.add(const TextSpan(text: '  '));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: RichText(
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }

  Widget _buildSurahInfoSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'معلومات السورة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryDarkGreen,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('الاسم:', 'سورة ${widget.surah.nameAr} (${widget.surah.nameEn})'),
          const SizedBox(height: 8),
          _infoRow('النوع:', widget.surah.type),
          const SizedBox(height: 8),
          _infoRow('رقم السورة:', widget.surah.id.toString()),
          const SizedBox(height: 8),
          _infoRow('عدد الآيات:', widget.surah.versesCount.toString()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
