import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/services/azkar_data_service.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../shared/widgets/shell_header_buttons.dart';
import '../../../home/presentation/providers/ayah_provider.dart';
import '../../data/azkar_progress_store.dart';
import '../../data/models/azkar_models.dart';
import 'all_azkar_categories_page.dart';
import 'azkar_details_page.dart';

class AzkarPage extends ConsumerStatefulWidget {
  const AzkarPage({super.key});

  @override
  ConsumerState<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends ConsumerState<AzkarPage> {
  final AzkarDataService _azkarDataService = AzkarDataService();
  bool _isLoading = true;
  List<AzkarCategory> _categories = [];
  AzkarProgressSnapshot? _lastAzkar;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _azkarDataService.loadAzkarData();
      final rawCategories = data['categories'] as List? ?? [];

      final parsedCategories =
          rawCategories.map((c) {
            final azkarList = c['azkar'] as List? ?? [];
            return AzkarCategory(
              id: c['id']?.toString() ?? '',
              nameAr: c['nameAr']?.toString() ?? '',
              nameEn: c['nameEn']?.toString() ?? '',
              azkar:
                  azkarList
                      .map(
                        (z) => ZekrItem(
                          id: (z['id'] as num?)?.toInt() ?? 0,
                          textAr: z['textAr']?.toString() ?? '',
                          textEn: z['textEn']?.toString() ?? '',
                          targetCount: (z['count'] as num?)?.toInt() ?? 1,
                          virtue: z['virtue']?.toString() ?? '',
                          reference: z['reference']?.toString() ?? '',
                        ),
                      )
                      .toList(),
            );
          }).toList();

      setState(() {
        _categories = parsedCategories;
        _isLoading = false;
      });
      await _refreshLastAzkar();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Improved category fetcher to handle remote API lists that may not use "morning" or "evening" as an exact ID
  AzkarCategory _getCategory(
    String exactId,
    String searchKeyword,
    String fallbackName,
  ) {
    try {
      return _categories.firstWhere(
        (c) => c.id == exactId || c.nameAr.contains(searchKeyword),
      );
    } catch (e) {
      // Fallback empty category specifically mapped to nothing if not found via ID or Keyword
      return AzkarCategory(
        id: exactId,
        nameAr: fallbackName,
        nameEn: '',
        azkar: [],
      );
    }
  }

  Future<void> _refreshLastAzkar() async {
    final snapshot = await AzkarProgressStore.lastOpened(
      categories: _categories,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _lastAzkar = snapshot;
    });
  }

  void _navigateToDetails(AzkarCategory category) {
    if (category.azkar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('no_azkar_in_section'))),
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AzkarDetailsPage(category: category),
          ),
        )
        .then((_) => _refreshLastAzkar());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'azkar',
      leading: const ShellMenuButton(),
      actions: const [ShellProfileButton()],
      body:
          _isLoading
              ? const Center(child: CustomLoader())
              : ListView(
                padding: AppScaffold.scrollPadding,
                children: [
                  const SmartTasbeehWidget(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildAdhkarSectionHeader(),
                  if (_lastAzkar != null) ...[
                    _buildContinueAzkarCard(_lastAzkar!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _buildAdhkarGrid(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildAyahOfTheDayCard(),
                ],
              ),
    );
  }

  Widget _buildAdhkarSectionHeader() {
    return SectionHeader(
      title: context.tr('muslim_azkar'),
      subtitle: '${_categories.length} ${context.tr('category_word')}',
      trailingLabel: context.tr('view_all'),
      onTrailingTap:
          () => Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => AllAzkarCategoriesPage(categories: _categories),
                ),
              )
              .then((_) => _refreshLastAzkar()),
    );
  }

  String _displayCategoryName(
    BuildContext context,
    AzkarCategory category,
    String fallbackKey,
  ) {
    if (context.isAppRtl) {
      return category.nameAr.isNotEmpty
          ? category.nameAr
          : context.tr(fallbackKey);
    }

    if (category.nameEn.isNotEmpty) {
      return category.nameEn;
    }

    if (category.nameAr.isNotEmpty) {
      return category.nameAr;
    }

    return context.tr(fallbackKey);
  }

  Widget _buildContinueAzkarCard(AzkarProgressSnapshot snapshot) {
    final category = snapshot.category;
    final title = _displayCategoryName(context, category, 'sleep_azkar');
    final progressLabel =
        snapshot.isComplete
            ? context.tr('azkar_session_complete')
            : '${context.tr('continue_azkar')} • ${snapshot.completedCount}/${snapshot.totalCount}';

    // Resuming an unfinished session is the one thing worth a gold card here.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HeroCard(
        label: context.tr('continue_azkar'),
        title: title,
        subtitle: progressLabel,
        ornament: HeroOrnament.crescent,
        height: 118,
        onTap: () => _navigateToDetails(category),
      ),
    );
  }

  Widget _buildAdhkarGrid() {
    final morning = _getCategory(
      'morning',
      'صباح',
      context.tr('morning_azkar'),
    );
    final prayer = _getCategory(
      'prayer',
      'صلاة',
      context.tr('after_prayer_azkar'),
    );
    final evening = _getCategory(
      'evening',
      'مساء',
      context.tr('evening_azkar'),
    );
    final sleep = _getCategory('sleep', 'نوم', context.tr('sleep_azkar'));

    // Two big ones for the two that anchor the day, two smaller for the rest.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(context, morning, 'morning_azkar'),
                subtitle: context.tr('morning_azkar_subtitle'),
                count: morning.azkar.length.toString(),
                icon: Icons.wb_twilight,
                onTap: () => _navigateToDetails(morning),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(context, evening, 'evening_azkar'),
                subtitle: context.tr('evening_azkar_subtitle'),
                count: evening.azkar.length.toString(),
                icon: Icons.nights_stay_outlined,
                onTap: () => _navigateToDetails(evening),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(
                  context,
                  prayer,
                  'after_prayer_azkar',
                ),
                subtitle: context.tr('after_prayer_azkar_subtitle'),
                count: prayer.azkar.length.toString(),
                icon: Icons.mosque_outlined,
                onTap: () => _navigateToDetails(prayer),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildAdhkarCard(
                title: _displayCategoryName(context, sleep, 'sleep_azkar'),
                subtitle: context.tr('sleep_azkar_subtitle'),
                count: sleep.azkar.length.toString(),
                icon: Icons.bedtime_outlined,
                onTap: () => _navigateToDetails(sleep),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdhkarCard({
    required String title,
    required String subtitle,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tokens.brand.withValues(alpha: 0.12),
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, size: 19, color: tokens.brand),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: tokens.groundAlt,
                  borderRadius: AppRadii.pillAll,
                ),
                child: Text(
                  count,
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 11,
                    color: tokens.inkFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.display(context, fontSize: 15.5),
          ),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(context, color: tokens.inkFaint),
          ),
        ],
      ),
    );
  }

  /// The verse of the day, on a drawn card.
  ///
  /// It used to pull a stock photo off the network — in an app whose whole
  /// point is working offline, and behind text that then needed a shadow to
  /// stay legible. A painted card owes nothing to a CDN.
  Widget _buildAyahOfTheDayCard() {
    final ayahAsync = ref.watch(dailyAyahProvider);

    String verseText(Map<String, dynamic>? data) {
      final text = (data?['text'] as String? ?? '').trim();
      return text.isEmpty ? context.tr('azkar_ayah_of_day_text') : text;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('ayah_of_the_day'),
                  style: AppTextStyles.display(context, fontSize: 15),
                ),
              ),
              if (ayahAsync.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GhostIconButton(
                  icon: Icons.shuffle_rounded,
                  tooltip: context.tr('random_ayah'),
                  onTap:
                      () => ref.read(dailyAyahIndexProvider.notifier).shuffle(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            verseText(ayahAsync.value),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.quran(context, fontSize: 21),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
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
      _currentZekrIndex =
          (_currentZekrIndex - 1) < 0
              ? phrasesLength - 1
              : _currentZekrIndex - 1;
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
    final tokens = context.tokens;

    return Material(
      color: tokens.groundAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18, color: tokens.inkMuted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final azkarList = _azkarList(context);
    final progress = (_tasbeehCount / _target).clamp(0.0, 1.0);
    final remaining = (_target - _tasbeehCount).clamp(0, _target);
    final currentZekr = azkarList[_currentZekrIndex];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('smart_tasbeeh'),
                  style: AppTextStyles.display(context, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: tokens.groundAlt,
                  borderRadius: AppRadii.pillAll,
                ),
                child: Text(
                  '$_tasbeehCount / $_target',
                  style: AppTextStyles.caption(
                    context,
                    fontSize: 12,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // The dhikr being counted, above the thing that counts it.
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: Text(
              currentZekr,
              key: ValueKey(currentZekr),
              textAlign: TextAlign.center,
              style: AppTextStyles.quran(
                context,
                fontSize: 22,
                height: 1.7,
                color: tokens.ink,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.chevron_right,
                onTap: () => _previousZekr(azkarList.length),
              ),
              const SizedBox(width: AppSpacing.lg),
              // One big target, because counting happens without looking.
              GestureDetector(
                onTap: () => _increment(azkarList.length),
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress.toDouble()),
                        duration: AppMotion.base,
                        builder:
                            (context, value, _) => SizedBox(
                              width: 190,
                              height: 190,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                backgroundColor: tokens.groundAlt,
                                valueColor: AlwaysStoppedAnimation(
                                  tokens.goldBright,
                                ),
                              ),
                            ),
                      ),
                      Container(
                        width: 154,
                        height: 154,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: [tokens.brand, tokens.brandDeep],
                          ),
                          boxShadow: AppShadows.glow(tokens.brand, alpha: 0.28),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_tasbeehCount',
                              style: const TextStyle(
                                fontFamily: AppTextStyles.displayFamily,
                                fontSize: 48,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$remaining ${context.tr('count')}',
                              style: TextStyle(
                                fontFamily: AppTextStyles.bodyFamily,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              _buildControlButton(
                icon: Icons.chevron_left,
                onTap: () => _nextZekr(azkarList.length),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GhostIconButton(
            icon: Icons.refresh_rounded,
            onTap: _reset,
            tooltip: context.tr('reset'),
          ),
        ],
      ),
    );
  }
}
