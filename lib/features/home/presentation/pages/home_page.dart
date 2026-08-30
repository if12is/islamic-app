import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/hijri_service.dart';
import '../../../../core/services/seasonal_theme.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/arc_gauge.dart';
import '../../../../core/widgets/ayah_block.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../core/widgets/seasonal_banner.dart';
import '../../../../core/widgets/story_rail.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/shell_header_buttons.dart';
import '../../../azkar/presentation/pages/azkar_page.dart';
import '../../../prayer_times/domain/entities/prayer_times_entity.dart';
import '../../../prayer_times/presentation/pages/hijri_calendar_page.dart';
import '../../../prayer_times/presentation/pages/prayer_times_page.dart';
import '../../../prayer_times/presentation/pages/qibla_page.dart';
import '../../../prayer_times/presentation/providers/prayer_times_providers.dart';
import '../../../quran/data/services/quran_local_service.dart';
import '../../../quran/presentation/pages/quran_page.dart';
import '../../../quran/presentation/pages/recitation_page.dart';
import '../../../quran/presentation/pages/surah_reader_page.dart';
import '../../../quran/presentation/providers/bookmarks_provider.dart';
import 'wird_page.dart';
import '../../../settings/presentation/widgets/app_update_dialog.dart';
import '../../../../shared/providers/app_update_provider.dart';
import '../providers/ayah_provider.dart';
import '../providers/daily_wird_provider.dart';
import '../widgets/daily_wird_card.dart';
import '../../../../core/widgets/now_playing_strip.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/ramadan_card.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_offerUpdateIfDue());
    });
  }

  Future<void> _offerUpdateIfDue() async {
    await ref.read(appUpdateProvider.notifier).checkIfDue();
    if (!mounted) {
      return;
    }
    if (ref.read(appUpdateProvider).status == AppUpdateStatus.available) {
      await AppUpdateDialog.present(context, ref);
    }
  }

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
      _tabAt(3, const WirdPage()),
      _tabAt(4, const PrayerTimesPage()),
    ];

    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Content runs under the floating bar, which is what gives the glass
        // something to blur.
        extendBody: true,
        body: IndexedStack(index: selectedNavIndex, children: tabs),
        // The strip sits between the content and the nav bar, so whatever is
        // playing is reachable from every tab rather than only from the screen
        // that started it. It takes no height when nothing is playing.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NowPlayingStrip(),
            GlassNavBar(
              selectedIndex: selectedNavIndex,
              onSelected: _onTabTapped,
              // Visual order; home sits in the middle and is drawn raised.
              items: [
                // The wird took the Settings slot. Settings was reachable
                // three ways from every screen and the wird none, which is the
                // weight of the two exactly backwards.
                GlassNavItem(
                  tabIndex: 3,
                  icon: Icons.task_alt_outlined,
                  selectedIcon: Icons.task_alt,
                  label: context.tr('wird_title'),
                ),
                GlassNavItem(
                  tabIndex: 2,
                  // A sparkle said nothing about adhkar; a rising sun is what
                  // the morning and evening portions actually are.
                  icon: Icons.wb_twilight_outlined,
                  selectedIcon: Icons.wb_twilight,
                  label: context.tr('azkar'),
                ),
                GlassNavItem(
                  tabIndex: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_filled,
                  label: context.tr('home'),
                ),
                GlassNavItem(
                  tabIndex: 1,
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  label: context.tr('quran'),
                ),
                GlassNavItem(
                  tabIndex: 4,
                  icon: Icons.mosque_outlined,
                  selectedIcon: Icons.mosque,
                  label: context.tr('prayer_times'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- HOME DASHBOARD (DYNAMIC CONNECTED) ---

/// The first screen: where the day is, what is waiting, and one tap to each.
///
/// The order is deliberate. The arc answers "how long do I have?" before
/// anything else asks for attention; the rail puts the four things people open
/// daily within one thumb reach; the cards below are things you may want, in
/// the order you are likely to want them.
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
    // One tick a second, only while this tab is built.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _canonicalPrayerId(String name) {
    final lower = name.toLowerCase();
    for (final id in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (lower.contains(id)) {
        return id;
      }
    }
    return '';
  }

  String _digits(BuildContext context, String input) {
    if (!context.isAppRtl) {
      return input;
    }
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var output = input;
    for (var i = 0; i < arabic.length; i++) {
      output = output.replaceAll('$i', arabic[i]);
    }
    return output;
  }

  DateTime _parseTime(String raw) {
    try {
      var clean = raw.split(' ').first;
      const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (var i = 0; i < arabic.length; i++) {
        clean = clean.replaceAll(arabic[i], '$i');
      }
      final parts = clean.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  String _prayerName(BuildContext context, String name) {
    final lower = name.toLowerCase();
    for (final id in ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (lower.contains(id)) {
        return context.tr(id);
      }
    }
    return name;
  }

  IconData _prayerIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fajr')) return Icons.wb_twilight_rounded;
    if (lower.contains('sunrise')) return Icons.wb_sunny_outlined;
    if (lower.contains('dhuhr')) return Icons.light_mode_rounded;
    if (lower.contains('asr')) return Icons.wb_cloudy_outlined;
    if (lower.contains('maghrib')) return Icons.nights_stay_outlined;
    if (lower.contains('isha')) return Icons.bedtime_rounded;
    return Icons.access_time_rounded;
  }

  /// The clock split from its marker, so the arc can set "٤:٣٨" large and
  /// "م" small beside it, the way a clock face does.
  (String, String) _clockParts(BuildContext context, DateTime time) {
    final suffix =
        time.hour >= 12 ? context.tr('pm_short') : context.tr('am_short');
    var hour = time.hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final minutes = time.minute.toString().padLeft(2, '0');
    return (_digits(context, '$hour:$minutes'), suffix);
  }

  String _clock(BuildContext context, DateTime time) {
    final parts = _clockParts(context, time);
    return '${parts.$1} ${parts.$2}';
  }

  String _remaining(BuildContext context, Duration duration) {
    if (duration.isNegative) {
      return '';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final text =
        hours > 0
            ? '$hours:${minutes.toString().padLeft(2, '0')}'
            : '$minutes ${context.tr('minute_short')}';
    return _digits(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final locationAsync = ref.watch(currentLocationCoordinatesProvider);
    final locationLabel = ref.watch(locationLabelProvider).value ?? '';
    final selectedMethod = ref.watch(prayerMethodProvider);
    final completedPrayers = ref.watch(dailyPrayerCompletionProvider);

    const fallback = UserCoordinates(
      latitude: 31.0345728,
      longitude: 30.4676864,
    );
    final coordinates = locationAsync.maybeWhen(
      data: (value) => value,
      orElse: () => fallback,
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

    return AppScaffold(
      titleWidget: const _Greeting(),
      leading: const ShellThemeButton(),
      actions: const [ShellProfileButton()],
      body: prayerTimesAsync.when(
        loading: () => const Center(child: CustomLoader()),
        error:
            (error, _) =>
                _ErrorState(onRetry: () => ref.invalidate(prayerTimesProvider)),
        data: (entity) {
          final order = {
            'fajr': 0,
            'dhuhr': 1,
            'asr': 2,
            'maghrib': 3,
            'isha': 4,
          };

          final slots =
              entity.prayers
                  .map((prayer) {
                    final id = _canonicalPrayerId(prayer.name);
                    if (id.isEmpty) {
                      return null;
                    }
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

          _PrayerSlot? current;
          _PrayerSlot? next;
          DateTime? nextTime;

          for (final slot in slots) {
            if (_currentTime.isBefore(slot.time)) {
              next = slot;
              nextTime = slot.time;
              break;
            }
            current = slot;
          }
          if (current == null && slots.isNotEmpty) {
            current = slots.last;
          }
          if (next == null && slots.isNotEmpty) {
            next = slots.first;
            nextTime = slots.first.time.add(const Duration(days: 1));
          }

          // The arc runs from the prayer just gone to the one coming, so its
          // fill is literally "how much of this window is spent".
          var progress = 0.0;
          if (current != null && nextTime != null) {
            final start =
                current.time.isAfter(_currentTime)
                    ? current.time.subtract(const Duration(days: 1))
                    : current.time;
            final span = nextTime.difference(start).inSeconds;
            if (span > 0) {
              progress = _currentTime.difference(start).inSeconds / span;
            }
          }

          final until =
              nextTime == null
                  ? Duration.zero
                  : nextTime.difference(_currentTime);

          return ListView(
            padding: AppScaffold.scrollPadding,
            children: [
              Center(
                child: ArcGauge(
                  progress: progress,
                  headline:
                      next == null ? '—' : _clockParts(context, next.time).$1,
                  headlineSuffix:
                      next == null ? null : _clockParts(context, next.time).$2,
                  caption:
                      next == null
                          ? null
                          : _prayerName(context, next.prayer.name),
                  remaining: next == null ? null : _remaining(context, until),
                  footnote: locationLabel.isEmpty ? null : locationLabel,
                  startLabel:
                      current == null
                          ? null
                          : _prayerName(context, current.prayer.name),
                  startTime:
                      current == null ? null : _clock(context, current.time),
                  startIcon:
                      current == null
                          ? Icons.wb_twilight_rounded
                          : _prayerIcon(current.prayer.name),
                  endLabel:
                      next == null
                          ? null
                          : _prayerName(context, next.prayer.name),
                  endTime: next == null ? null : _clock(context, next.time),
                  endIcon:
                      next == null
                          ? Icons.bedtime_rounded
                          : _prayerIcon(next.prayer.name),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _DashboardRail(onOpenTab: widget.onOpenTab),
              const SizedBox(height: AppSpacing.lg),

              const _SeasonalHeader(),
              const _LastReadHero(),
              const RamadanCard(),
              const DailyWirdCard(),
              const SizedBox(height: AppSpacing.lg),

              SectionHeader(
                title: context.tr('prayer_times'),
                trailingLabel: context.tr('view_all'),
                onTrailingTap: () => widget.onOpenTab(4),
              ),
              ...slots.map((slot) {
                final isCurrent = current?.id == slot.id;
                return _PrayerRow(
                  name: _prayerName(context, slot.prayer.name),
                  time: _clock(context, slot.time),
                  icon: _prayerIcon(slot.prayer.name),
                  isCurrent: isCurrent,
                  isDone: completedPrayers.contains(slot.id),
                  onToggleDone:
                      () => ref
                          .read(dailyPrayerCompletionProvider.notifier)
                          .togglePrayer(slot.id),
                );
              }),

              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: context.tr('ayah_of_day')),
              const _AyahCard(),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  _digits(context, entity.gregorianDate),
                  style: AppTextStyles.caption(context, color: tokens.inkFaint),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The greeting, in the header. The place lives inside the arc, next to the
/// times it belongs to.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final key =
        hour < 12
            ? 'greeting_morning'
            : (hour < 18 ? 'greeting_afternoon' : 'greeting_evening');

    return Text(
      context.tr(key),
      style: AppTextStyles.display(
        context,
        fontSize: 17,
        color: context.tokens.ink,
      ),
    );
  }
}

/// The four things people open every day, one tap away.
class _DashboardRail extends ConsumerWidget {
  const _DashboardRail({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRead = ref.watch(lastReadProvider);
    final wird = ref.watch(dailyWirdProvider).value;
    final left = wird == null ? 0 : wird.total - wird.completed;

    return StoryRail(
      items: [
        StoryItem(
          icon: Icons.auto_stories_outlined,
          label: context.tr('last_read'),
          highlighted: lastRead != null,
          onTap: () {
            if (lastRead == null) {
              onOpenTab(1);
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => SurahReaderPage(
                      surahNumber: lastRead.surahNumber,
                      initialVerse: lastRead.verseNumber,
                    ),
              ),
            );
          },
        ),
        StoryItem(
          icon: Icons.checklist_rtl,
          label: context.tr('daily_wird'),
          badge: left > 0 ? '$left' : null,
          highlighted: left > 0,
          onTap: () => onOpenTab(2),
        ),
        StoryItem(
          icon: Icons.explore_outlined,
          label: context.tr('qibla_direction'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QiblaPage()),
              ),
        ),
        StoryItem(
          icon: Icons.radio_button_checked,
          label: context.tr('tasbeeh_counter'),
          onTap: () => onOpenTab(2),
        ),
        StoryItem(
          icon: Icons.mic_none,
          label: context.tr('recite_mode_identify'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecitationPage.identify(),
                ),
              ),
        ),
        StoryItem(
          icon: Icons.calendar_month_outlined,
          label: context.tr('hijri_calendar'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HijriCalendarPage(),
                ),
              ),
        ),
      ],
    );
  }
}

/// The gold card at the top of the stack: pick up where you stopped.
class _LastReadHero extends ConsumerWidget {
  const _LastReadHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRead = ref.watch(lastReadProvider);
    if (lastRead == null) {
      return const SizedBox.shrink();
    }

    final surah = QuranLocalService.surahInfo(lastRead.surahNumber);
    final verse = lastRead.verseNumber.clamp(1, surah.versesCount);
    final languageCode = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HeroCard(
        label: context.tr('last_read'),
        title: languageCode == 'ar' ? surah.nameAr : surah.nameEn,
        subtitle: AppLocalizations.translate(
          languageCode,
          'last_read_position',
          replacements: {
            'verse': verse.toString(),
            'total': surah.versesCount.toString(),
            'page':
                QuranLocalService.verse(
                  lastRead.surahNumber,
                  verse,
                ).page.toString(),
          },
        ),
        actionLabel: context.tr('continue_reading'),
        ornament: HeroOrnament.book,
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => SurahReaderPage(
                      surahNumber: lastRead.surahNumber,
                      initialVerse: verse,
                    ),
              ),
            ),
      ),
    );
  }
}

/// One prayer in the day's list.
class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.icon,
    required this.isCurrent,
    required this.isDone,
    required this.onToggleDone,
  });

  final String name;
  final String time;
  final IconData icon;
  final bool isCurrent;
  final bool isDone;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppListRow(
      dense: true,
      selected: isCurrent,
      // The same tile as the prayer screen's list, which is the same list.
      // The two were drawn separately and had drifted into two different
      // shapes for the same row.
      leading: AppIconTile(
        icon,
        role: AppIconRole.row,
        tone: isCurrent ? AppIconTone.accent : AppIconTone.neutral,
        selected: isCurrent,
      ),
      title: name,
      meta: isCurrent ? context.tr('current_prayer') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: AppTextStyles.display(
              context,
              fontSize: 15,
              color: isCurrent ? tokens.ink : tokens.inkMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GhostIconButton(
            icon: isDone ? Icons.check_circle : Icons.circle_outlined,
            active: isDone,
            onTap: onToggleDone,
            tooltip: context.tr('mark_prayed'),
          ),
        ],
      ),
      onTap: onToggleDone,
    );
  }
}

/// Something went wrong and the user can do exactly one thing about it.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: tokens.inkFaint, size: 44),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('unable_load_prayer_times_connection'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          ],
        ),
      ),
    );
  }
}

/// The verse of the day, as a quiet card rather than a shouting one.
class _AyahCard extends ConsumerWidget {
  const _AyahCard();

  String _cleanSurahName(String raw) =>
      raw.replaceFirst('سُورَةُ ', '').replaceFirst('سورة ', '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayahAsync = ref.watch(dailyAyahProvider);

    return AppCard(
      corners: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: ayahAsync.when(
        skipLoadingOnReload: true,
        loading:
            () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CustomLoader()),
            ),
        error:
            (_, _) => Column(
              children: [
                Text(
                  context.tr('error_loading_ayah'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(context, fontSize: 14),
                ),
                GhostIconButton(
                  icon: Icons.shuffle_rounded,
                  tooltip: context.tr('random_ayah'),
                  onTap:
                      () => ref.read(dailyAyahIndexProvider.notifier).shuffle(),
                ),
              ],
            ),
        data: (ayahData) {
          final text = (ayahData['text'] as String? ?? '').trim();
          final numberInSurah = (ayahData['numberInSurah'] as int? ?? 1);
          final surahMap =
              ayahData['surah'] is Map<String, dynamic>
                  ? ayahData['surah'] as Map<String, dynamic>
                  : const <String, dynamic>{};
          final surahNameAr = _cleanSurahName(
            surahMap['name'] as String? ?? '',
          );
          final surahNameEn = surahMap['englishName'] as String? ?? '';
          final label =
              context.isAppRtl
                  ? '$surahNameAr · $numberInSurah'
                  : '$surahNameEn · $numberInSurah';

          return AyahBlock(
            numberLabel: label,
            arabic: text,
            actions: [
              GhostIconButton(
                icon: Icons.shuffle_rounded,
                tooltip: context.tr('random_ayah'),
                onTap:
                    () => ref.read(dailyAyahIndexProvider.notifier).shuffle(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ramadan and the Eids dress the top of the dashboard.
class _SeasonalHeader extends ConsumerWidget {
  const _SeasonalHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(seasonalEventProvider);
    final override = ref.watch(seasonalOverrideProvider);
    if (season == SeasonalEvent.none) {
      return const SizedBox.shrink();
    }

    final offset = ref.watch(prayerCalculationSettingsProvider).hijriOffsetDays;
    final hijri = HijriService.fromGregorian(
      DateTime.now(),
      offsetDays: offset,
    );
    final isRamadan = HijriService.isRamadan(hijri.hMonth);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          if (override != null) _previewStrip(context, ref),
          SeasonalBanner(
            event: season,
            hijriDay: isRamadan ? hijri.hDay : null,
          ),
        ],
      ),
    );
  }

  /// A forced season is easy to forget and would ship as a bug, so it says so
  /// on the home screen and offers the way back in the same tap.
  Widget _previewStrip(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.12),
        borderRadius: AppRadii.smAll,
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 15, color: tokens.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.tr('seasonal_preview_active'),
              style: AppTextStyles.caption(context, color: tokens.danger),
            ),
          ),
          TextButton(
            onPressed:
                () => ref.read(seasonalOverrideProvider.notifier).set(null),
            child: Text(context.tr('seasonal_preview_exit')),
          ),
        ],
      ),
    );
  }
}
