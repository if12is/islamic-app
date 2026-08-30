import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/tasbeeh_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../home/domain/custom_wird.dart';
import '../../../home/presentation/widgets/add_to_wird_button.dart';
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
import 'divine_names_page.dart';
import 'dua_library_page.dart';
import 'ruqyah_page.dart';
import 'salawat_page.dart';

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
      leading: const ShellThemeButton(),
      actions: const [ShellProfileButton()],
      body:
          _isLoading
              ? const Center(child: CustomLoader())
              : ListView(
                padding: AppScaffold.scrollPadding,
                children: [
                  const SmartTasbeehWidget(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDevotionShortcuts(),
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

  /// The devotions that are neither a chapter of the Hisn nor a tasbeeh
  /// phrase, plus the two other ways into the chapters themselves.
  Widget _buildDevotionShortcuts() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _shortcut(
                icon: Icons.auto_awesome,
                label: context.tr('divine_names'),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DivineNamesPage(),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _shortcut(
                icon: Icons.favorite_outline,
                label: context.tr('salawat'),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SalawatPage(),
                      ),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _shortcut(
                icon: Icons.menu_book_outlined,
                label: context.tr('dua_library'),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DuaLibraryPage(categories: _categories),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _shortcut(
                icon: Icons.shield_outlined,
                label: context.tr('ruqyah'),
                onTap: () => RuqyahPage.open(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shortcut({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(context, fontSize: 14),
            ),
          ),
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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildAdhkarCard(
                  title: _displayCategoryName(
                    context,
                    morning,
                    'morning_azkar',
                  ),
                  subtitle: context.tr('morning_azkar_subtitle'),
                  count: morning.azkar.length.toString(),
                  icon: Icons.wb_twilight,
                  onTap: () => _navigateToDetails(morning),
                  category: morning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildAdhkarCard(
                  title: _displayCategoryName(
                    context,
                    evening,
                    'evening_azkar',
                  ),
                  subtitle: context.tr('evening_azkar_subtitle'),
                  count: evening.azkar.length.toString(),
                  icon: Icons.nights_stay_outlined,
                  onTap: () => _navigateToDetails(evening),
                  category: evening,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  category: prayer,
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
                  category: sleep,
                ),
              ),
            ],
          ),
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
    AzkarCategory? category,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The icon and the count now sit on the same wash. They were a
              // brand tint and `groundAlt` — two unrelated backgrounds a few
              // pixels apart, which is why this card looked designed in the
              // dark theme and assembled from parts in the light one.
              AppIconTile(icon, role: AppIconRole.card),
              const Spacer(),
              AppIconCount(count: count),
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
            style: AppTextStyles.caption(context),
          ),
          if (category != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AddToWirdButton(
                kind: WirdKind.azkar,
                reference: category.id.isEmpty ? title : category.id,
                title: title,
              ),
            ),
          ],
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
      corners: true,
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
  const SmartTasbeehWidget({super.key, this.onRoundsChanged});

  /// Fired when a round moves, so the daily wird can re-read it.
  final VoidCallback? onRoundsChanged;

  @override
  State<SmartTasbeehWidget> createState() => _SmartTasbeehWidgetState();
}

class _SmartTasbeehWidgetState extends State<SmartTasbeehWidget> {
  static const int _target = TasbeehStore.roundTarget;

  /// Kept in step with [_azkarList].
  static const int _phraseCount = 6;

  TasbeehMode _mode = TasbeehMode.rounds;
  int _tasbeehCount = 0;
  int _currentZekrIndex = 0;

  /// The lifetime total for the phrase on screen — the big number.
  int _phraseTotal = 0;

  /// Every phrase added together — the small number underneath.
  int _total = 0;
  int _today = 0;

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _prefs = prefs;
      _mode = TasbeehStore.mode(prefs);
      _total = TasbeehStore.total(prefs);
      _today = TasbeehStore.today(prefs);
      _currentZekrIndex = TasbeehStore.phraseIndex(prefs);
      _phraseTotal = TasbeehStore.totalFor(prefs, _currentZekrIndex);
      // Rounds survive leaving the screen and stepping between phrases now,
      // so read today's count back rather than starting from nothing.
      _tasbeehCount = TasbeehStore.roundCount(prefs, _currentZekrIndex);
    });
  }

  /// Counts read in the digits of the language on screen.
  static String _formatCount(BuildContext context, int value) {
    if (!context.isAppRtl) {
      return '$value';
    }
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }

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

  bool get _isEndless => _mode == TasbeehMode.endless;

  Future<void> _setMode(TasbeehMode mode) async {
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);

    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await TasbeehStore.setMode(prefs, mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentZekrIndex = TasbeehStore.phraseIndex(prefs);
      _total = TasbeehStore.total(prefs);
      _today = TasbeehStore.today(prefs);
      _phraseTotal = TasbeehStore.totalFor(prefs, _currentZekrIndex);
      _tasbeehCount = TasbeehStore.roundCount(prefs, _currentZekrIndex);
    });
  }

  Future<void> _increment(int phrasesLength) async {
    HapticFeedback.lightImpact();

    final prefs = _prefs;

    if (_isEndless) {
      // Written on every tap: a lifetime count lost to a force-quit is a
      // count nobody trusts again.
      final next =
          prefs == null
              ? _phraseTotal + 1
              : await TasbeehStore.increment(
                prefs,
                phraseIndex: _currentZekrIndex,
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _phraseTotal = next;
        _total++;
        _today++;
      });
      if (next % 100 == 0) {
        HapticFeedback.heavyImpact();
      }
      return;
    }

    // Rounds are per phrase and per day, and they are written down — so the
    // count is still there after stepping to the next phrase and back, and the
    // daily wird reads the same numbers.
    final next =
        prefs == null
            ? (_tasbeehCount + 1).clamp(0, _target)
            : await TasbeehStore.incrementRound(prefs, _currentZekrIndex);
    if (!mounted) {
      return;
    }

    setState(() => _tasbeehCount = next);

    if (next >= _target) {
      HapticFeedback.heavyImpact();
    }
    widget.onRoundsChanged?.call();
  }

  Future<void> _reset() async {
    if (_isEndless) {
      await _confirmClearTotal();
      return;
    }
    HapticFeedback.mediumImpact();
    final prefs = _prefs;
    if (prefs != null) {
      await TasbeehStore.resetRounds(prefs, phraseIndex: _currentZekrIndex);
    }
    if (mounted) {
      setState(() => _tasbeehCount = 0);
      widget.onRoundsChanged?.call();
    }
  }

  /// The lifetime total only goes away on purpose, and only after saying so.
  Future<void> _confirmClearTotal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('tasbeeh_endless_reset_title')),
            content: Text(dialogContext.tr('tasbeeh_endless_reset_body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.tr('cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: dialogContext.tokens.danger,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.tr('reset')),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }
    final prefs = _prefs;
    if (prefs != null) {
      await TasbeehStore.clearTotal(prefs, phraseCount: _phraseCount);
    }
    if (!mounted) {
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _total = 0;
      _phraseTotal = 0;
      _today = 0;
    });
  }

  Future<void> _changePhrase(int phrasesLength, int step) async {
    HapticFeedback.lightImpact();
    final next = (_currentZekrIndex + step + phrasesLength) % phrasesLength;
    final prefs = _prefs;

    // Every phrase carries its own numbers, in both modes. Stepping away used
    // to zero the round, so thirty-three of سبحان الله vanished on the way to
    // الحمد لله and back.
    setState(() {
      _currentZekrIndex = next;
      _phraseTotal = prefs == null ? 0 : TasbeehStore.totalFor(prefs, next);
      _tasbeehCount = prefs == null ? 0 : TasbeehStore.roundCount(prefs, next);
    });

    if (prefs != null) {
      await TasbeehStore.setPhraseIndex(prefs, next);
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final tokens = context.tokens;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.groundAlt,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22, color: tokens.ink),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final azkarList = _azkarList(context);
    final currentZekr = azkarList[_currentZekrIndex];
    final progress =
        _isEndless
            ? ((_phraseTotal % 100) / 100)
            : (_tasbeehCount / _target).clamp(0.0, 1.0);

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
              // The phrase on screen can be committed to daily from here,
              // which is where someone decides they want it every day.
              AddToWirdButton(
                kind: WirdKind.tasbih,
                reference: 'phrase:$_currentZekrIndex',
                title: currentZekr,
                target: _target,
                compact: true,
              ),
              PillSelector<TasbeehMode>(
                compact: true,
                scrollable: false,
                value: _mode,
                onChanged: _setMode,
                options: [
                  PillOption(
                    value: TasbeehMode.rounds,
                    label: context.tr('tasbeeh_mode_rounds'),
                  ),
                  PillOption(
                    value: TasbeehMode.endless,
                    label: context.tr('tasbeeh_mode_endless'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

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
            children: [
              _buildControlButton(
                icon:
                    context.isAppRtl ? Icons.chevron_right : Icons.chevron_left,
                tooltip: context.tr('tasbeeh_prev_phrase'),
                onTap: () => _changePhrase(azkarList.length, -1),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _increment(azkarList.length),
                    child:
                        _isEndless
                            ? _endlessDial(context, progress)
                            : _roundsDial(context, progress),
                  ),
                ),
              ),
              _buildControlButton(
                icon:
                    context.isAppRtl ? Icons.chevron_left : Icons.chevron_right,
                tooltip: context.tr('tasbeeh_next_phrase'),
                onTap: () => _changePhrase(azkarList.length, 1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_isEndless) ...[
            // Below the string, above today's line — clear of the artwork.
            Text(
              '${context.tr('tasbeeh_grand_total')}: '
              '${_formatCount(context, _total)}',
              style: AppTextStyles.caption(
                context,
                color: tokens.inkMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${context.tr('tasbeeh_today')}: '
              '${_formatCount(context, _today)}',
              style: AppTextStyles.caption(context, color: tokens.inkFaint),
            ),
          ],
          GhostIconButton(
            icon: _isEndless ? Icons.restart_alt : Icons.refresh_rounded,
            onTap: _reset,
            tooltip:
                _isEndless
                    ? context.tr('tasbeeh_endless_reset_title')
                    : context.tr('reset'),
          ),
        ],
      ),
    );
  }

  /// Rounds of 33: a ring that fills and a solid green disc.
  Widget _roundsDial(BuildContext context, double progress) {
    final tokens = context.tokens;
    final remaining = (_target - _tasbeehCount).clamp(0, _target);

    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: AppMotion.base,
            builder:
                (context, value, _) => SizedBox(
                  width: 168,
                  height: 168,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: tokens.groundAlt,
                    valueColor: AlwaysStoppedAnimation(tokens.goldBright),
                  ),
                ),
          ),
          Container(
            width: 136,
            height: 136,
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
                  _formatCount(context, _tasbeehCount),
                  style: const TextStyle(
                    fontFamily: AppTextStyles.displayFamily,
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_formatCount(context, remaining)} ${context.tr('count')}',
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
    );
  }

  /// Endless: the number is the whole design, on a string of beads. There is
  /// no ring to fill because there is nothing to finish.
  Widget _endlessDial(BuildContext context, double progress) {
    final tokens = context.tokens;

    return SizedBox(
      width: 168,
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BeadStringPainter(
                colour: tokens.gold,
                highlight: tokens.goldBright,
                progress: progress,
              ),
            ),
          ),
          // Lifted well clear of the arc. The number used to sit low enough
          // that the beads ran through it, and the total underneath crossed
          // the string entirely.
          Padding(
            padding: const EdgeInsets.only(bottom: 62),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('tasbeeh_lifetime'),
                  style: AppTextStyles.caption(
                    context,
                    color: tokens.inkFaint,
                    fontSize: 11,
                  ),
                ),
                // The phrase on screen, not every phrase added together —
                // someone who has said سبحان الله four thousand times wants
                // that number, and the sum goes below the beads.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatCount(context, _phraseTotal),
                    style: TextStyle(
                      fontFamily: AppTextStyles.displayFamily,
                      fontSize: 54,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: tokens.brand,
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
}

/// A string of beads arcing under the number; the next hundred lights up as it
/// is counted.
class _BeadStringPainter extends CustomPainter {
  const _BeadStringPainter({
    required this.colour,
    required this.highlight,
    required this.progress,
  });

  final Color colour;
  final Color highlight;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const beads = 9;
    final centre = Offset(size.width / 2, size.height * 0.18);
    final radius = size.width * 0.46;

    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final angle = math.pi * 0.16 + t * math.pi * 0.68;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final lit = (progress * beads).floor();
    for (var i = 0; i < beads; i++) {
      final t = i / (beads - 1);
      final angle = math.pi * 0.16 + t * math.pi * 0.68;
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      final isLit = i < lit;

      canvas.drawCircle(
        point,
        isLit ? 9 : 7.5,
        Paint()..color = isLit ? highlight : colour.withValues(alpha: 0.35),
      );
      if (isLit) {
        canvas.drawCircle(
          point,
          13,
          Paint()
            ..color = highlight.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BeadStringPainter old) =>
      old.progress != progress || old.colour != colour;
}
