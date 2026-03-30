import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AzkarPage extends StatelessWidget {
  const AzkarPage({Key? key}) : super(key: key);

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
            'الفجر',
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
        body: SingleChildScrollView(
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
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildAdhkarSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          'أذكار المسلم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          'عرض الكل',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.brown,
          ),
        ),
      ],
    );
  }

  Widget _buildAdhkarGrid() {
    return Column(
      children: [
        // Morning Adhkar (Top)
        _buildAdhkarCard(
          title: 'أذكار الصباح',
          subtitle: 'تبدأ من طلوع الفجر',
          count: '74',
          icon: Icons.wb_sunny,
          color: Colors.white,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        // Prayer & Evening Adhkar (Middle Row)
        Row(
          children: [
            Expanded(
              child: _buildAdhkarCard(
                title: 'بعد الصلاة',
                subtitle: 'دبر كل صلاة',
                count: '',
                icon: Icons.mosque,
                color: Colors.white,
                isFullWidth: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdhkarCard(
                title: 'أذكار المساء',
                subtitle: 'بعد صلاة العصر',
                count: '',
                icon: Icons.nights_stay,
                color: const Color(0xFFD3EADD), // Light pastel green
                isFullWidth: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Sleep Adhkar (Bottom)
        _buildAdhkarCard(
          title: 'أذكار النوم',
          subtitle: 'قبل النوم',
          count: '',
          icon: Icons.brightness_3,
          color: const Color(0xFFEEEEEE),
          isFullWidth: true,
          showArrow: true,
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
    bool showArrow = false,
  }) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.05),
                child: Icon(icon, color: Colors.amber.shade700),
              ),
              if (count.isNotEmpty)
                Text(
                  '$count ذكراً',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (showArrow)
                const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black54),
            ],
          ),
        ],
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

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1, // Adhkar active
      selectedItemColor: const Color(0xFF0B4633),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B4633),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          label: 'الأذكار',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          label: 'القرآن',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'حسابي',
        ),
      ],
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

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() {
      _tasbeehCount++;
      if (_tasbeehCount > _target) {
        _tasbeehCount = 1;
      }
    });
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tasbeehCount = 0;
    });
  }

  void _vibrateSettings() {
    HapticFeedback.heavyImpact();
    // Would open settings or toggle vibration in a real app
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _tasbeehCount / _target;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B4633), // Primary Dark Green
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'المسبحة الذكية',
            style: TextStyle(
              color: Color(0xFFF6D167), // Gold
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
                        value: progress == 0 ? 1 : progress, // when 0 show grey ring entirely vs empty
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
              // Vibrate button
              Positioned(
                bottom: -15,
                left: 10,
                child: _buildSmallCircularButton(
                  icon: Icons.phone_android,
                  onTap: _vibrateSettings,
                ),
              ),
              // Reset button
              Positioned(
                bottom: -15,
                right: 10,
                child: _buildSmallCircularButton(
                  icon: Icons.refresh,
                  onTap: _reset,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'سبحان الله وبحمده',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCircularButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F5A42), // slightly lighter than background
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
