import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/quran_api_service.dart';
import 'surah_reader_page.dart';

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

class QuranPage extends StatefulWidget {
  const QuranPage({Key? key}) : super(key: key);

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  // Constants & Colors
  final Color _bgOffWhite = const Color(0xFFF8F9FA);
  final Color _primaryDarkGreen = const Color(0xFF0B4633);
  final Color _accentGold = const Color(0xFFF6D167);

  // Services
  final QuranApiService _apiService = QuranApiService();

  // States
  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];
  bool _isLoading = true;
  String _errorMsg = '';
  
  final TextEditingController _searchController = TextEditingController();
  
  String _dynamicNextPrayer = 'الفجر'; 
  int? _currentlyPlayingSurahId;
  final double _khatmahProgress = 0.65; // User's monthly progress

  // Mocked Last Read state (could be loaded from SharedPreferences)
  Surah? _lastReadSurah;
  int _lastReadVerse = 1;

  @override
  void initState() {
    super.initState();
    _fetchSurahs();
    _searchController.addListener(_onSearchChanged);
    
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _dynamicNextPrayer = 'الظهر';
        });
      }
    });
  }

  Future<void> _fetchSurahs() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final rawList = await _apiService.fetchSurahsList();
      if (rawList.isEmpty) {
        setState(() {
          _errorMsg = 'لا يمكن تحميل السور حالياً. تأكد من اتصال الإنترنت.';
          _isLoading = false;
        });
        return;
      }

      final surahs = rawList.map((json) {
        final safeMap = Map<String, dynamic>.from(json as Map);
        return Surah.fromApiJson(safeMap);
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      final lastReadId = prefs.getInt('last_read_surah_id');
      final lastReadVerseNum = prefs.getInt('last_read_verse_num') ?? 1;

      Surah? savedSurah;
      if (lastReadId != null) {
        savedSurah = surahs.cast<Surah?>().firstWhere((s) => s?.id == lastReadId, orElse: () => null);
      }
      
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = List.from(surahs);
        _lastReadSurah = savedSurah ?? surahs.cast<Surah?>().firstWhere((s) => s?.id == 18, orElse: () => surahs.first);
        _lastReadVerse = lastReadVerseNum;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'حدث خطأ أثناء الاتصال بالخادم.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReadId = prefs.getInt('last_read_surah_id');
    final lastReadVerseNum = prefs.getInt('last_read_verse_num') ?? 1;

    if (lastReadId != null && _allSurahs.isNotEmpty) {
      final savedSurah = _allSurahs.cast<Surah?>().firstWhere((s) => s?.id == lastReadId, orElse: () => null);
      if (savedSurah != null) {
        setState(() {
          _lastReadSurah = savedSurah;
          _lastReadVerse = lastReadVerseNum;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = List.from(_allSurahs);
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          return surah.nameAr.contains(query) || 
                 surah.nameEn.toLowerCase().contains(query) || 
                 surah.id.toString() == query;
        }).toList();
      }
    });
  }

  void _togglePlayPause(int surahId) {
    setState(() {
      if (_currentlyPlayingSurahId == surahId) {
        _currentlyPlayingSurahId = null; 
      } else {
        _currentlyPlayingSurahId = surahId; 
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgOffWhite,
        appBar: _buildCustomAppBar(),
        body: Stack(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMsg.isNotEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMsg, style: TextStyle(color: Colors.red.shade800)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchSurahs,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 100.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    if (_lastReadSurah != null) _buildHeroLastRead(),
                    const SizedBox(height: 20),
                    _buildMonthlyKhatmah(),
                    const SizedBox(height: 24),
                    _buildSurahIndexHeader(),
                    const SizedBox(height: 12),
                    _buildSurahList(),
                  ],
                ),
              ),

            // Floating Settings Menu
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, left: 32.0, right: 32.0),
                  child: _buildFloatingSettingsBar(),
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
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () {},
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          _dynamicNextPrayer,
          key: ValueKey<String>(_dynamicNextPrayer),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن سورة أو رقم...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildHeroLastRead() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _primaryDarkGreen, // #0B4633
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -20,
            left: -10,
            child: Opacity(
              opacity: 0.1,
              child: const Icon(Icons.menu_book, size: 140, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.history, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'آخر قراءة',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'سورة ${_lastReadSurah!.nameAr}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'وصلت إلى الآية: $_lastReadVerse',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SurahReaderPage(surah: _lastReadSurah!),
                        ),
                      ).then((_) {
                        _loadLastRead();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGold,
                      foregroundColor: _primaryDarkGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('متابعة القراءة', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_back, size: 18), 
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentGold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star_border, color: _accentGold, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'ختمة الشهر',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryDarkGreen),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم إنجاز ${( _khatmahProgress * 100 ).toInt()}٪',
                style: TextStyle(
                  color: _primaryDarkGreen, // green
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'الهدف: ١٠٠٪',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurahIndexHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'فهرس السور',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.sort, color: Colors.black54),
            onPressed: () {
              setState(() {
                _filteredSurahs = _filteredSurahs.reversed.toList();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSurahList() {
    if (_filteredSurahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'لم يتم العثور على أي سورة',
            style: TextStyle(color: Colors.grey.shade500),
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
        final isPlaying = _currentlyPlayingSurahId == surah.id;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SurahReaderPage(surah: surah),
              ),
            ).then((_) {
              _loadLastRead();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
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
                    color: _primaryDarkGreen.withOpacity(0.05),
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
                        'سورة ${surah.nameAr}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${surah.versesCount} آيات • ${surah.type}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
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
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _togglePlayPause(surah.id),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
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

  Widget _buildFloatingSettingsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFloatingIconBtn(Icons.bookmark_outline),
          _buildVerticalDivider(),
          _buildFloatingIconBtn(Icons.dark_mode_outlined),
          _buildVerticalDivider(),
          _buildTextIconBtn('T', 16),
          _buildVerticalDivider(),
          _buildTextIconBtn('T', 22), 
        ],
      ),
    );
  }

  Widget _buildFloatingIconBtn(IconData icon) {
    return GestureDetector(
      onTap: () {},
      child: Icon(icon, color: Colors.grey.shade700, size: 28),
    );
  }

  Widget _buildTextIconBtn(String text, double size) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: size,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade300,
    );
  }
}
