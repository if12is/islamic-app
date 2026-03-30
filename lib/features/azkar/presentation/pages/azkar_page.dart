import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/azkar_data_service.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../data/models/azkar_models.dart';
import 'all_azkar_categories_page.dart';
import 'azkar_details_page.dart';

class AzkarPage extends StatefulWidget {
  const AzkarPage({Key? key}) : super(key: key);

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  final AzkarDataService _azkarDataService = AzkarDataService();
  bool _isLoading = true;
  List<AzkarCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _azkarDataService.loadAzkarData();
      final rawCategories = data['categories'] as List? ?? [];
      
      final parsedCategories = rawCategories.map((c) {
        final azkarList = c['azkar'] as List? ?? [];
        return AzkarCategory(
          id: c['id']?.toString() ?? '',
          nameAr: c['nameAr']?.toString() ?? '',
          nameEn: c['nameEn']?.toString() ?? '',
          azkar: azkarList.map((z) => ZekrItem(
            id: (z['id'] as num?)?.toInt() ?? 0,
            textAr: z['textAr']?.toString() ?? '',
            textEn: z['textEn']?.toString() ?? '',
            targetCount: (z['count'] as num?)?.toInt() ?? 1,
          )).toList(),
        );
      }).toList();

      setState(() {
        _categories = parsedCategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Improved category fetcher to handle remote API lists that may not use "morning" or "evening" as an exact ID
  AzkarCategory _getCategory(String exactId, String searchKeyword, String fallbackName) {
    try {
      return _categories.firstWhere(
        (c) => c.id == exactId || c.nameAr.contains(searchKeyword),
      );
    } catch (e) {
      // Fallback empty category specifically mapped to nothing if not found via ID or Keyword
      return AzkarCategory(id: exactId, nameAr: fallbackName, nameEn: '', azkar: []);
    }
  }

  void _navigateToDetails(AzkarCategory category) {
    if (category.azkar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أذكار في هذا القسم حالياً')),
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AzkarDetailsPage(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // Soft off-white
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () {},
          ),
          title: const Text(
            'الأذكار',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
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
        ),
        body: _isLoading
            ? const Center(child: CustomLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmartTasbeehWidget(),
                    const SizedBox(height: 24),
                    _buildAdhkarSectionHeader(),
                    const SizedBox(height: 16),
                    _buildAdhkarGrid(),
                    const SizedBox(height: 16),
                    _buildAyahOfTheDayCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAdhkarSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'أذكار المسلم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: () {
            // Navigate to robust grid listing all azkar from the API
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AllAzkarCategoriesPage(categories: _categories),
              ),
            );
          },
          child: const Text(
            'عرض الكل',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.brown,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdhkarGrid() {
    // Making keyword-based lookups more robust according to what remote API typically provides.
    final morningCat = _getCategory('morning', 'صباح', 'أذكار الصباح');
    final prayerCat = _getCategory('prayer', 'صلاة', 'بعد الصلاة');
    final eveningCat = _getCategory('evening', 'مساء', 'أذكار المساء');
    final sleepCat = _getCategory('sleep', 'نوم', 'أذكار النوم');

    // Make the display names clean based exactly on the matched object instead of forcing fallbacks
    return Column(
      children: [
        // Morning Adhkar (Top)
        _buildAdhkarCard(
          title: morningCat.nameAr.isNotEmpty ? morningCat.nameAr : 'أذكار الصباح',
          subtitle: 'تبدأ من طلوع الفجر',
          count: morningCat.azkar.length.toString(),
          icon: Icons.wb_sunny,
          color: Colors.white,
          isFullWidth: true,
          onTap: () => _navigateToDetails(morningCat),
        ),
        const SizedBox(height: 12),
        // Prayer & Evening Adhkar (Middle Row)
        Row(
          children: [
            Expanded(
              child: _buildAdhkarCard(
                title: prayerCat.nameAr.isNotEmpty ? prayerCat.nameAr : 'بعد الصلاة',
                subtitle: 'دبر كل صلاة',
                count: prayerCat.azkar.length.toString(),
                icon: Icons.mosque,
                color: Colors.white,
                isFullWidth: false,
                onTap: () => _navigateToDetails(prayerCat),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdhkarCard(
                title: eveningCat.nameAr.isNotEmpty ? eveningCat.nameAr : 'أذكار المساء',
                subtitle: 'بعد صلاة العصر',
                count: eveningCat.azkar.length.toString(),
                icon: Icons.nights_stay,
                color: const Color(0xFFD3EADD), // Light pastel green
                isFullWidth: false,
                onTap: () => _navigateToDetails(eveningCat),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Sleep Adhkar (Bottom)
        _buildAdhkarCard(
          title: sleepCat.nameAr.isNotEmpty ? sleepCat.nameAr : 'أذكار النوم',
          subtitle: 'قبل النوم',
          count: sleepCat.azkar.length.toString(),
          icon: Icons.brightness_3,
          color: const Color(0xFFEEEEEE),
          isFullWidth: true,
          showArrow: true,
          onTap: () => _navigateToDetails(sleepCat),
        ),
      ],
    );
  }

  Widget _buildAdhkarCard({
    required String title,
    required String subtitle,
    required String count,
    required IconData icon,
    required Color color,
    required bool isFullWidth,
    required VoidCallback onTap,
    bool showArrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.05),
                  child: Icon(icon, color: Colors.amber.shade700),
                ),
                if (count != '0')
                  Text(
                    '$count ذكراً',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black54),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahOfTheDayCard() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage(
              'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.3)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              'آية اليوم',
              style: TextStyle(
                color: Color(0xFFF6D167), // Gold
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'أَلا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartTasbeehWidget extends StatefulWidget {
  const SmartTasbeehWidget({Key? key}) : super(key: key);

  @override
  State<SmartTasbeehWidget> createState() => _SmartTasbeehWidgetState();
}

class _SmartTasbeehWidgetState extends State<SmartTasbeehWidget> {
  int _tasbeehCount = 0;
  final int _target = 33;
  int _currentZekrIndex = 0;

  final List<String> _azkarList = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'استغفر الله',
    'لا حول ولا قوة إلا بالله',
  ];

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() {
      _tasbeehCount++;
      if (_tasbeehCount > _target) {
        _tasbeehCount = 1; // Rollover and move to next
        _currentZekrIndex = (_currentZekrIndex + 1) % _azkarList.length;
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tasbeehCount = 0;
    });
  }

  void _previousZekr() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentZekrIndex = (_currentZekrIndex - 1) < 0 ? _azkarList.length - 1 : _currentZekrIndex - 1;
      _tasbeehCount = 0;
    });
  }

  void _nextZekr() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentZekrIndex = (_currentZekrIndex + 1) % _azkarList.length;
      _tasbeehCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _tasbeehCount / _target;
    final currentZekr = _azkarList[_currentZekrIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B4633), // Primary Dark Green
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'المسبحة الذكية',
                style: TextStyle(
                  color: Color(0xFFF6D167), // Gold
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _increment,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress == 0 ? 1 : progress, // when 0 show grey ring entirely
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 0 ? Colors.white.withOpacity(0.1) : const Color(0xFFF6D167),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tasbeehCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/ $_target',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Previous zekr
              Positioned(
                left: -20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
                  onPressed: _previousZekr,
                ),
              ),
              // Next zekr
              Positioned(
                right: -20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                  onPressed: _nextZekr,
                ),
              ),
              // Reset button
              Positioned(
                bottom: -15,
                child: GestureDetector(
                  onTap: _reset,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F5A42),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            currentZekr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
