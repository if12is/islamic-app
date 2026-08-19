import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/design_colors.dart';
import '../../../../core/services/azkar_data_service.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../data/models/azkar_models.dart';
import 'all_azkar_categories_page.dart';
import 'azkar_details_page.dart';

class AzkarPage extends StatefulWidget {
  const AzkarPage({super.key});

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
        SnackBar(content: Text(context.tr('no_azkar_in_section'))),
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
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).textTheme.bodyLarge!.color!),
            onPressed: () {},
          ),
          title: Text(
            context.tr('azkar'),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).cardColor,
                child: Icon(Icons.person, color: Theme.of(context).textTheme.bodyLarge!.color!),
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
        Text(
          context.tr('muslim_azkar'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color!,
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
          child: Text(
            context.tr('view_all'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  String _displayCategoryName(
    BuildContext context,
    AzkarCategory category,
    String fallbackKey,
  ) {
    if (context.isAppRtl) {
      return category.nameAr.isNotEmpty ? category.nameAr : context.tr(fallbackKey);
    }

    if (category.nameEn.isNotEmpty) {
      return category.nameEn;
    }

    if (category.nameAr.isNotEmpty) {
      return category.nameAr;
    }

    return context.tr(fallbackKey);
  }

  Widget _buildAdhkarGrid() {
    // Making keyword-based lookups more robust according to what remote API typically provides.
    final morningCat = _getCategory('morning', 'صباح', context.tr('morning_azkar'));
    final prayerCat = _getCategory('prayer', 'صلاة', context.tr('after_prayer_azkar'));
    final eveningCat = _getCategory('evening', 'مساء', context.tr('evening_azkar'));
    final sleepCat = _getCategory('sleep', 'نوم', context.tr('sleep_azkar'));

    // Make the display names clean based exactly on the matched object instead of forcing fallbacks
    return Column(
      children: [
        // Morning Adhkar (Top)
        _buildAdhkarCard(
          title: _displayCategoryName(context, morningCat, 'morning_azkar'),
          subtitle: context.tr('morning_azkar_subtitle'),
          count: morningCat.azkar.length.toString(),
          icon: Icons.wb_sunny,
          color: Theme.of(context).cardColor,
          isFullWidth: true,
          onTap: () => _navigateToDetails(morningCat),
        ),
        const SizedBox(height: 12),
        // Prayer & Evening Adhkar (Middle Row)
        Row(
          children: [
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(context, prayerCat, 'after_prayer_azkar'),
                subtitle: context.tr('after_prayer_azkar_subtitle'),
                count: prayerCat.azkar.length.toString(),
                icon: Icons.mosque,
                color: Theme.of(context).cardColor,
                isFullWidth: false,
                onTap: () => _navigateToDetails(prayerCat),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(context, eveningCat, 'evening_azkar'),
                subtitle: context.tr('evening_azkar_subtitle'),
                count: eveningCat.azkar.length.toString(),
                icon: Icons.nights_stay,
                color: Theme.of(context).colorScheme.primaryContainer,
                isFullWidth: false,
                onTap: () => _navigateToDetails(eveningCat),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Sleep Adhkar (Bottom)
        _buildAdhkarCard(
          title: _displayCategoryName(context, sleepCat, 'sleep_azkar'),
          subtitle: context.tr('sleep_azkar_subtitle'),
          count: sleepCat.azkar.length.toString(),
          icon: Icons.brightness_3,
          color: Theme.of(context).cardColor,
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
              color: Colors.black.withValues(alpha: 0.05),
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
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
                ),
                if (count != '0')
                  Text(
                    '$count ${context.tr('zekr_count_unit')}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge!.color!,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  Icon(Icons.arrow_back_ios, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            colors: [Colors.black.withValues(alpha: 0.7), Colors.black.withValues(alpha: 0.3)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              context.tr('ayah_of_the_day'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('azkar_ayah_of_day_text'),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color!,
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
  const SmartTasbeehWidget({super.key});

  @override
  State<SmartTasbeehWidget> createState() => _SmartTasbeehWidgetState();
}

class _SmartTasbeehWidgetState extends State<SmartTasbeehWidget> {
  int _tasbeehCount = 0;
  final int _target = 33;
  int _currentZekrIndex = 0;

  List<String> _azkarList(BuildContext context) {
    return [
      context.tr('tasbeeh_phrase_subhanallah'),
      context.tr('tasbeeh_phrase_alhamdulillah'),
      context.tr('tasbeeh_phrase_la_ilaha_illa_allah'),
      context.tr('tasbeeh_phrase_allahu_akbar'),
      context.tr('tasbeeh_phrase_astaghfirullah'),
      context.tr('tasbeeh_phrase_hawqala'),
    ];
  }

  void _increment(int phrasesLength) {
    HapticFeedback.lightImpact();
    setState(() {
      _tasbeehCount++;
      if (_tasbeehCount > _target) {
        _tasbeehCount = 1; // Rollover and move to next
        _currentZekrIndex = (_currentZekrIndex + 1) % phrasesLength;
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

  void _previousZekr(int phrasesLength) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentZekrIndex = (_currentZekrIndex - 1) < 0 ? phrasesLength - 1 : _currentZekrIndex - 1;
      _tasbeehCount = 0;
    });
  }

  void _nextZekr(int phrasesLength) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentZekrIndex = (_currentZekrIndex + 1) % phrasesLength;
      _tasbeehCount = 0;
    });
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final azkarList = _azkarList(context);
    final double progress = (_tasbeehCount / _target).clamp(0.0, 1.0);
    final int remaining = (_target - _tasbeehCount).clamp(0, _target);
    final currentZekr = azkarList[_currentZekrIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C6653),
            Color(0xFF084236),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('smart_tasbeeh'),
                  style: const TextStyle(
                    color: DesignColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text(
                  '${_tasbeehCount.toString()} / $_target',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildControlButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => _previousZekr(azkarList.length),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _increment(azkarList.length),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0C4F41),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 162,
                              height: 162,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(DesignColors.gold),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tasbeehCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$remaining ${context.tr('count')}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: () => _nextZekr(azkarList.length),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Text(
                currentZekr,
                key: ValueKey(currentZekr),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
