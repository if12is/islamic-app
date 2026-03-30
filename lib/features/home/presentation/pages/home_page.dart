import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_loader.dart';
import '../../../azkar/presentation/pages/azkar_page.dart';
import '../../../prayer_times/presentation/pages/prayer_times_page.dart';
import '../../../prayer_times/domain/entities/prayer_times_entity.dart';
import '../../../prayer_times/presentation/providers/prayer_times_providers.dart';
import '../../../quran/presentation/pages/quran_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

// --- MAIN PAGE (CONTROLS NAV) ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;

  void _onTabTapped(int index) {
    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeDashboard(onOpenTab: _onTabTapped),
      const QuranPage(),
      const AzkarPage(),
      const SettingsPage(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl, // Strict RTL Layout
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: IndexedStack(index: _selectedNavIndex, children: tabs),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF003527), // Primary Dark Green
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Color(0xFF707974));
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Color(0xFF003527),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo', // Assume Cairo if GoogleFonts issues
                );
              }
              return const TextStyle(
                color: Color(0xFF707974),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Cairo',
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
              NavigationDestination(icon: Icon(Icons.menu_book), label: 'القرآن'),
              NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'الأذكار'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HOME DASHBOARD (DYNAMIC CONNECTED) ---
class _HomeDashboard extends ConsumerStatefulWidget {
  final ValueChanged<int> onOpenTab;

  const _HomeDashboard({required this.onOpenTab});

  @override
  ConsumerState<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<_HomeDashboard> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  // Parses "HH:mm" from API into today's DateTime
  DateTime _parseTime(String timeStr) {
    try {
      // Support for values like "04:32 (EET)" coming from Aladhan
      final cleanTimeStr = timeStr.split(' ').first; 
      final parts = cleanTimeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _getArabicName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('fajr')) return 'الفجر';
    if (lowerName.contains('sunrise')) return 'الشروق';
    if (lowerName.contains('dhuhr')) return 'الظهر';
    if (lowerName.contains('asr')) return 'العصر';
    if (lowerName.contains('maghrib')) return 'المغرب';
    if (lowerName.contains('isha')) return 'العشاء';
    return name;
  }

  IconData _getIconForPrayer(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('fajr')) return Icons.wb_twilight;
    if (lowerName.contains('sunrise')) return Icons.wb_sunny;
    if (lowerName.contains('dhuhr')) return Icons.wb_sunny_outlined;
    if (lowerName.contains('asr')) return Icons.light_mode_outlined;
    if (lowerName.contains('maghrib')) return Icons.nightlight_round;
    if (lowerName.contains('isha')) return Icons.nightlight_outlined;
    return Icons.access_time;
  }

  String _formatTime12H(DateTime time) {
    int h = time.hour;
    int m = time.minute;
    String ampm = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) h = 12;
    String mStr = m.toString().padLeft(2, '0');
    String hStr = h.toString().padLeft(2, '0');
    return '$hStr:$mStr $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Note: Requesting Tanta, Egypt coordinates dynamically from Provider as defined earlier
    final prayerTimesAsync = ref.watch(prayerTimesProvider(
      const PrayerTimesParams(latitude: 31.0345728, longitude: 30.4676864, method: 5), // method 5 = Egyptian General Authority of Survey
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1A1C1C), size: 32),
          onPressed: () {},
        ),
        title: const Text(
          'الفجر',
          style: TextStyle(
            color: Color(0xFF1A1C1C),
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
            fontFamily: 'Cairo', // Use App font
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF003527),
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: prayerTimesAsync.when(
        data: (entity) {
          // Filter to just main 5 prayers
          final mainPrayers = entity.prayers.where((p) => 
            ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].any((valid) => p.name.toLowerCase().contains(valid))
          ).toList();

          // Calculate Next Prayer dynamically based on seconds logic
          PrayerEntity? nextPrayer;
          Duration timeUntilNext = Duration.zero;

          for (var p in mainPrayers) {
            final pTime = _parseTime(p.time);
            if (pTime.isAfter(_currentTime)) {
              nextPrayer = p;
              timeUntilNext = pTime.difference(_currentTime);
              break;
            }
          }

          // If all prayers passed today, next is Fajr tomorrow
          if (nextPrayer == null && mainPrayers.isNotEmpty) {
            final first = mainPrayers.firstWhere((p) => p.name.toLowerCase().contains('fajr'), orElse: () => mainPrayers.first);
            final pTime = _parseTime(first.time).add(const Duration(days: 1));
            nextPrayer = first;
            timeUntilNext = pTime.difference(_currentTime);
          }

          return SafeArea(
            child: CustomScrollView( // Using CustomScrollView for best dynamic responsiveness and scaling
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Hero Card
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return _HeroCard(
                            nextPrayer: nextPrayer,
                            countdown: timeUntilNext,
                            arabicName: nextPrayer != null ? _getArabicName(nextPrayer.name) : '',
                            gregorianDate: entity.gregorianDate,
                            hijriDate: entity.hijriDate.formattedDate,
                          );
                        }
                      ),
                      const SizedBox(height: 28),

                      // Quick Actions
                      _QuickActionsGrid(onOpenTab: widget.onOpenTab),
                      const SizedBox(height: 32),

                      // Ayah of the day
                      const _AyahCard(),
                      const SizedBox(height: 40),

                      // List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text('مواقيت الصلاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C), fontFamily: 'Cairo')),
                          Text('عرض الكل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1C), fontFamily: 'Cairo')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Prayer List (Dynamic mapped)
                      ...mainPrayers.map((p) {
                        bool isNext = nextPrayer?.name == p.name;
                        final dt = _parseTime(p.time);
                        return _PrayerTile(
                          name: _getArabicName(p.name),
                          formattedTime: _formatTime12H(dt),
                          icon: _getIconForPrayer(p.name),
                          isNext: isNext,
                        );
                      }),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CustomLoader()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Color(0xFFBA1A1A), size: 48),
                const SizedBox(height: 16),
                const Text('تعذر جلب المواقيت، تحقق من الاتصال بالإنترنت', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(prayerTimesProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003527),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                )
              ],
            ),
          )
        ),
      ),
    );
  }
}

// --- SUB-WIDGETS ---

class _HeroCard extends StatelessWidget {
  final PrayerEntity? nextPrayer;
  final Duration countdown;
  final String arabicName;
  final String gregorianDate;
  final String hijriDate;

  const _HeroCard({
    required this.nextPrayer, 
    required this.countdown,
    required this.arabicName,
    required this.gregorianDate,
    required this.hijriDate,
  });

  @override
  Widget build(BuildContext context) {
    if (nextPrayer == null) return const SizedBox.shrink();

    // Use a robust formatting 
    int totalSeconds = countdown.inSeconds;
    if (totalSeconds < 0) totalSeconds = 0; // Prevent negative display
    
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;

    final String hStr = h.toString().padLeft(2, '0');
    final String mStr = m.toString().padLeft(2, '0');
    final String sStr = s.toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF003527),
        borderRadius: BorderRadius.circular(40), // Large smooth radius matching prompt Image 3
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'الصلاة القادمة',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            arabicName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontFamily: 'Cairo'
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown, // Ensures large fonts scale nicely on small phones
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$hStr:$mStr:$sStr',
                  style: const TextStyle(
                    color: Color(0xFFFFE088),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_filled, color: Color(0xFFFFE088), size: 28),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 24),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text(hijriDate, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                  ],
                ),
                const SizedBox(width: 24), // Ensure gap on smaller screens
                Text(gregorianDate, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final ValueChanged<int> onOpenTab;

  const _QuickActionsGrid({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    // Utilize LayoutBuilder or fixed Wrap to ensure it never overflows horizontally 
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2; // Responsive
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            _ActionCard(title: 'القرآن', icon: Icons.menu_book, onTap: () => onOpenTab(1)),
            _ActionCard(title: 'القبلة', icon: Icons.explore_outlined, onTap: () {}),
            _ActionCard(title: 'المسبحة', icon: Icons.adjust, onTap: () {}),
            _ActionCard(title: 'الأذكار', icon: Icons.auto_awesome, onTap: () => onOpenTab(2)),
          ],
        );
      }
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28), // Fully matching image corner radii
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: const Color(0xFF1A1C1C)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1C1C), fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F1), // M3 Surface Variant emulation
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        clipBehavior: Clip.none, // Allow watermark to peek out slightly
        children: [
          Positioned(
            bottom: -10,
            left: -10,
            child: Icon(Icons.menu_book, size: 140, color: Colors.black.withOpacity(0.04)),
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 32, height: 1.5, color: const Color(0xFF735C00)),
                  const SizedBox(width: 12),
                  const Text('آية اليوم', style: TextStyle(color: Color(0xFF735C00), fontWeight: FontWeight.w800, fontSize: 15, fontFamily: 'Cairo')),
                  const SizedBox(width: 12),
                  Container(width: 32, height: 1.5, color: const Color(0xFF735C00)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '"وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.8,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1C1C),
                  fontFamily: 'Quran', // Specific elegant text feeling if available, otherwise fallback to standard
                ),
              ),
              const SizedBox(height: 20),
              const Text('سورة الطلاق - ٢-٣', style: TextStyle(color: Color(0xFF707974), fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  final String name;
  final String formattedTime;
  final IconData icon;
  final bool isNext;

  const _PrayerTile({
    required this.name,
    required this.formattedTime,
    required this.icon,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22), // Matching the M3 massive pad format
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFF003527) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isNext ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: isNext ? Colors.white : const Color(0xFF1A1C1C), size: 28),
              const SizedBox(width: 16),
              Text(name, style: TextStyle(color: isNext ? Colors.white : const Color(0xFF1A1C1C), fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
            ],
          ),
          Text(formattedTime, style: TextStyle(color: isNext ? Colors.white : const Color(0xFF707974), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
