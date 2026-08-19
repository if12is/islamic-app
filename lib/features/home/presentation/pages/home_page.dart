import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/providers/app_providers.dart';
import '../providers/ayah_provider.dart';
import '../../../azkar/presentation/pages/azkar_page.dart';
import '../../../prayer_times/presentation/pages/prayer_times_page.dart';
import '../../../prayer_times/domain/entities/prayer_times_entity.dart';
import '../../../prayer_times/presentation/providers/prayer_times_providers.dart';
import '../../../quran/presentation/pages/quran_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/widgets/shell_header_buttons.dart';

class _PrayerSlot {
  final String id;
  final PrayerEntity prayer;
  final DateTime time;

  const _PrayerSlot({
    required this.id,
    required this.prayer,
    required this.time,
  });
}

// --- MAIN PAGE (CONTROLS NAV) ---
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Set<int> _openedTabs = {0};

  void _onTabTapped(int index) {
    setState(() {
      _openedTabs.add(index);
    });
    ref.read(mainTabIndexProvider.notifier).setIndex(index);
  }

  Widget _tabAt(int index, Widget child) {
    if (!_openedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final selectedNavIndex = ref.watch(mainTabIndexProvider);
    _openedTabs.add(selectedNavIndex);
    final tabs = <Widget>[
      _tabAt(0, _HomeDashboard(onOpenTab: _onTabTapped)),
      _tabAt(1, const QuranPage()),
      _tabAt(2, const AzkarPage()),
      _tabAt(3, SettingsPage(onBackHome: () => _onTabTapped(0))),
    ];

    final theme = Theme.of(context);

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(index: selectedNavIndex, children: tabs),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: theme.scaffoldBackgroundColor,
            indicatorColor: theme.colorScheme.primary,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: theme.colorScheme.onPrimary);
              }
              return IconThemeData(color: theme.colorScheme.onSurfaceVariant);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo', // Assume Cairo if GoogleFonts issues
                );
              }
              return TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Cairo',
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: selectedNavIndex,
            onDestinationSelected: _onTabTapped,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_filled),
                label: context.tr('home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: context.tr('quran'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome),
                label: context.tr('azkar'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: context.tr('settings'),
              ),
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

  String _canonicalPrayerId(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('fajr')) return 'fajr';
    if (lowerName.contains('dhuhr')) return 'dhuhr';
    if (lowerName.contains('asr')) return 'asr';
    if (lowerName.contains('maghrib')) return 'maghrib';
    if (lowerName.contains('isha')) return 'isha';
    return '';
  }

  String _toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], arabic[i]);
    }
    return output;
  }

  String _normalizeToWesternDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < arabic.length; i++) {
      output = output.replaceAll(arabic[i], '$i');
    }
    return output;
  }

  String _localizeDigits(BuildContext context, String input) {
    return context.isAppRtl ? _toArabicDigits(input) : input;
  }

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
      final cleanTimeStr = _normalizeToWesternDigits(timeStr.split(' ').first);
      final parts = cleanTimeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _getPrayerDisplayName(BuildContext context, String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('fajr')) return context.tr('fajr');
    if (lowerName.contains('sunrise')) return context.tr('sunrise');
    if (lowerName.contains('dhuhr')) return context.tr('dhuhr');
    if (lowerName.contains('asr')) return context.tr('asr');
    if (lowerName.contains('maghrib')) return context.tr('maghrib');
    if (lowerName.contains('isha')) return context.tr('isha');
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

  String _formatTime12H(BuildContext context, DateTime time) {
    int h = time.hour;
    int m = time.minute;
    final ampm = h >= 12 ? context.tr('pm_short') : context.tr('am_short');
    h = h % 12;
    if (h == 0) h = 12;
    String mStr = m.toString().padLeft(2, '0');
    String hStr = h.toString().padLeft(2, '0');
    return _localizeDigits(context, '$hStr:$mStr $ampm');
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationCoordinatesProvider);
    final selectedMethod = ref.watch(prayerMethodProvider);
    final completedPrayers = ref.watch(dailyPrayerCompletionProvider);

    const fallbackCoordinates = UserCoordinates(
      latitude: 31.0345728,
      longitude: 30.4676864,
    );

    final coordinates = locationAsync.maybeWhen(
      data: (value) => value,
      orElse: () => fallbackCoordinates,
    );

    final method = ref
        .watch(sharedPreferencesProvider)
        .maybeWhen(
          data:
              (prefs) =>
                  prefs.getInt(AppConstants.prayerMethodKey) ?? selectedMethod,
          orElse: () => selectedMethod,
        );

    final prayerTimesAsync = ref.watch(
      prayerTimesProvider(
        PrayerTimesParams(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
          method: method,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const ShellMenuButton(iconSize: 32),
        title: Text(
          context.tr('app_title'),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
            fontFamily: 'Cairo', // Use App font
          ),
        ),
        centerTitle: false,
        actions: const [ShellProfileButton()],
      ),
      body: prayerTimesAsync.when(
        data: (entity) {
          final mainPrayers =
              entity.prayers
                  .where(
                    (p) => [
                      'fajr',
                      'dhuhr',
                      'asr',
                      'maghrib',
                      'isha',
                    ].any((valid) => p.name.toLowerCase().contains(valid)),
                  )
                  .toList();

          final order = {
            'fajr': 0,
            'dhuhr': 1,
            'asr': 2,
            'maghrib': 3,
            'isha': 4,
          };

          final prayerSlots =
              mainPrayers
                  .map((prayer) {
                    final id = _canonicalPrayerId(prayer.name);
                    if (id.isEmpty) return null;
                    return _PrayerSlot(
                      id: id,
                      prayer: prayer,
                      time: _parseTime(prayer.time),
                    );
                  })
                  .whereType<_PrayerSlot>()
                  .toList()
                ..sort(
                  (a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99),
                );

          _PrayerSlot? currentSlot;
          _PrayerSlot? nextSlot;
          DateTime? nextPrayerTime;
          Duration timeUntilNext = Duration.zero;

          for (final slot in prayerSlots) {
            if (_currentTime.isBefore(slot.time)) {
              nextSlot = slot;
              nextPrayerTime = slot.time;
              break;
            }

            currentSlot = slot;
          }

          if (currentSlot == null && prayerSlots.isNotEmpty) {
            // Before fajr, current prayer is considered Isha from previous day.
            currentSlot = prayerSlots.last;
          }

          if (nextSlot == null && prayerSlots.isNotEmpty) {
            nextSlot = prayerSlots.first;
            nextPrayerTime = prayerSlots.first.time.add(
              const Duration(days: 1),
            );
          }

          if (nextPrayerTime != null) {
            timeUntilNext = nextPrayerTime.difference(_currentTime);
          }

          return SafeArea(
            child: CustomScrollView(
              // Using CustomScrollView for best dynamic responsiveness and scaling
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Hero Card
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return _HeroCard(
                            nextPrayer: nextSlot?.prayer,
                            countdown: timeUntilNext,
                            arabicName:
                                nextSlot != null
                                    ? _getPrayerDisplayName(
                                      context,
                                      nextSlot.prayer.name,
                                    )
                                    : '',
                            gregorianDate: _localizeDigits(
                              context,
                              entity.gregorianDate,
                            ),
                            hijriDate: _localizeDigits(
                              context,
                              entity.hijriDate.formattedDate,
                            ),
                          );
                        },
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
                        children: [
                          Text(
                            context.tr('prayer_times'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).textTheme.bodyLarge!.color!,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrayerTimesPage(),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('view_all'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Prayer List (Dynamic mapped)
                      ...prayerSlots.map((slot) {
                        final prayer = slot.prayer;
                        final isCurrent = currentSlot?.id == slot.id;
                        final isDone = completedPrayers.contains(slot.id);

                        return _PrayerTile(
                          name: _getPrayerDisplayName(context, prayer.name),
                          formattedTime: _formatTime12H(context, slot.time),
                          icon: _getIconForPrayer(prayer.name),
                          isCurrent: isCurrent,
                          isDone: isDone,
                          onToggleDone:
                              () => ref
                                  .read(dailyPrayerCompletionProvider.notifier)
                                  .togglePrayer(slot.id),
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
        error:
            (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('unable_load_prayer_times_connection'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(prayerTimesProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr('retry'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontFamily: 'Cairo',
                        ),
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

  String _toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], arabic[i]);
    }
    return output;
  }

  String _localizeDigits(BuildContext context, String input) {
    return context.isAppRtl ? _toArabicDigits(input) : input;
  }

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
    final countdownText = _localizeDigits(context, '$hStr:$mStr:$sStr');
    final hijriDateText = _localizeDigits(context, hijriDate);
    final gregorianDateText = _localizeDigits(context, gregorianDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(
          40,
        ), // Large smooth radius matching prompt Image 3
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              context.tr('next_prayer'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            arabicName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit:
                BoxFit
                    .scaleDown, // Ensures large fonts scale nicely on small phones
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  countdownText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time_filled,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Container(
            height: 1,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
            margin: const EdgeInsets.only(bottom: 24),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hijriDateText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24), // Ensure gap on smaller screens
                Text(
                  gregorianDateText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
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
            _ActionCard(
              title: context.tr('quran'),
              icon: Icons.menu_book,
              onTap: () => onOpenTab(1),
            ),
            _ActionCard(
              title: context.tr('qibla_direction'),
              icon: Icons.explore_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrayerTimesPage()),
                );
              },
            ),
            _ActionCard(
              title: context.tr('tasbeeh_counter'),
              icon: Icons.adjust,
              onTap: () {},
            ),
            _ActionCard(
              title: context.tr('azkar'),
              icon: Icons.auto_awesome,
              onTap: () => onOpenTab(2),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(
            28,
          ), // Fully matching image corner radii
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color!,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahCard extends ConsumerWidget {
  const _AyahCard();

  String _toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], arabic[i]);
    }
    return output;
  }

  String _cleanSurahName(String rawName) {
    return rawName.replaceFirst('سُورَةُ ', '').replaceFirst('سورة ', '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayahAsync = ref.watch(dailyAyahProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        clipBehavior: Clip.none, // Allow watermark to peek out slightly
        children: [
          Positioned(
            bottom: -10,
            left: -10,
            child: Icon(
              Icons.menu_book,
              size: 140,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.05),
            ),
          ),
          ayahAsync.when(
            skipLoadingOnReload: true,
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CustomLoader()),
                ),
            error:
                (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        context.tr('error_loading_ayah'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      IconButton(
                        tooltip: context.tr('random_ayah'),
                        onPressed: () =>
                            ref.read(dailyAyahIndexProvider.notifier).shuffle(),
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
            data: (ayahData) {
              final ayahText = (ayahData['text'] as String? ?? '').trim();
              final numberInSurah =
                  (ayahData['numberInSurah'] as int? ?? 1).toString();
              final surahMap =
                  ayahData['surah'] is Map<String, dynamic>
                      ? ayahData['surah'] as Map<String, dynamic>
                      : <String, dynamic>{};
              final surahNameAr = _cleanSurahName(
                surahMap['name'] as String? ?? '',
              );
              final surahNameEn = surahMap['englishName'] as String? ?? '';
              final verseNumberText =
                  context.isAppRtl
                      ? _toArabicDigits(numberInSurah)
                      : numberInSurah;
              final reference =
                  context.isAppRtl
                      ? 'سورة $surahNameAr - آية $verseNumberText'
                      : 'Surah $surahNameEn - Verse $verseNumberText';
              final isShuffling = ayahAsync.isLoading;

              return Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 1.5,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.tr('ayah_of_the_day'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 32,
                              height: 1.5,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          tooltip: context.tr('random_ayah'),
                          onPressed: isShuffling
                              ? null
                              : () => ref
                                  .read(dailyAyahIndexProvider.notifier)
                                  .shuffle(),
                          icon: isShuffling
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                )
                              : Icon(
                                  Icons.shuffle_rounded,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '"$ayahText"',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.amiriQuran(
                      fontSize: 30,
                      height: 1.9,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    reference,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiriQuran(
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
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
  final bool isCurrent;
  final bool isDone;
  final VoidCallback onToggleDone;

  const _PrayerTile({
    required this.name,
    required this.formattedTime,
    required this.icon,
    required this.isCurrent,
    required this.isDone,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 22,
      ), // Matching the M3 massive pad format
      decoration: BoxDecoration(
        color: isCurrent ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow:
            isCurrent
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isCurrent ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                size: 28,
              ),
              const SizedBox(width: 16),
              Text(
                name,
                style: TextStyle(
                  color: isCurrent ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          Text(
            formattedTime,
            style: TextStyle(
              color:
                  isCurrent
                      ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.84)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggleDone,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isDone
                          ? Theme.of(context).colorScheme.secondary
                          : (isCurrent
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.45)
                              : Theme.of(context).colorScheme.outline),
                  width: 2,
                ),
                color: isDone ? Theme.of(context).colorScheme.secondary : Colors.transparent,
              ),
              child:
                  isDone
                      ? Icon(
                        Icons.check,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondary,
                      )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
