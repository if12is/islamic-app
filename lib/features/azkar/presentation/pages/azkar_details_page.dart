import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_loader.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/arabic_text_block.dart';
import '../../data/azkar_progress_store.dart';
import '../../data/models/azkar_models.dart';

class AzkarDetailsPage extends StatefulWidget {
  final AzkarCategory category;

  const AzkarDetailsPage({super.key, required this.category});

  @override
  State<AzkarDetailsPage> createState() => _AzkarDetailsPageState();
}

class _AzkarDetailsPageState extends State<AzkarDetailsPage> {
  Map<int, int> _counts = {};
  bool _isLoading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initAndLoadProgress();
    AzkarProgressStore.markOpened(widget.category.id);
  }

  /// Shared with the daily wird card, so both agree on when azkar reset.
  String get _currentSessionKey => AzkarProgressStore.sessionKey();

  Future<void> _initAndLoadProgress() async {
    _prefs = await SharedPreferences.getInstance();

    final categoryId = widget.category.id;
    final savedSession = _prefs!.getString('azkar_session_$categoryId');
    final currentSession = _currentSessionKey;

    if (savedSession == currentSession) {
      // Same period, load saved counts
      final savedCountsStr = _prefs!.getString('azkar_counts_$categoryId');
      if (savedCountsStr != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(savedCountsStr);
          final Map<int, int> loadedCounts = {};
          decoded.forEach((key, value) {
            loadedCounts[int.parse(key)] = value as int;
          });
          setState(() {
            _counts = loadedCounts;
          });
        } catch (e) {
          // Fallback to empty if parse fails
          _counts = {};
        }
      }
    } else {
      // New period, start fresh & save new session
      _counts = {};
      await _saveProgressData(); // Initial save avoids overwriting with old data later
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProgressData() async {
    if (_prefs == null) return;

    final categoryId = widget.category.id;
    final currentSession = _currentSessionKey;

    await _prefs!.setString('azkar_session_$categoryId', currentSession);

    final stringKeyedMap = _counts.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await _prefs!.setString(
      'azkar_counts_$categoryId',
      json.encode(stringKeyedMap),
    );
  }

  void _increment(ZekrItem zekr) {
    if ((_counts[zekr.id] ?? 0) < zekr.targetCount) {
      HapticFeedback.lightImpact();
      setState(() {
        _counts[zekr.id] = (_counts[zekr.id] ?? 0) + 1;
      });
      _saveProgressData();
    }
  }

  void _reset(ZekrItem zekr) {
    HapticFeedback.mediumImpact();
    setState(() {
      _counts[zekr.id] = 0;
    });
    _saveProgressData();
  }

  void _resetAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _counts.clear();
    });
    _saveProgressData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(body: Center(child: CustomLoader()));
    }

    return AppScaffold(
      showBack: true,
      titleWidget: Text(
        context.isAppRtl
            ? widget.category.nameAr
            : (widget.category.nameEn.isNotEmpty
                ? widget.category.nameEn
                : widget.category.nameAr),
        style: AppTextStyles.display(context, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _resetAll,
          tooltip: context.tr('reset_all'),
        ),
      ],
      body: ListView.builder(
        padding: AppScaffold.scrollPadding,
        itemCount: widget.category.azkar.length,
        itemBuilder: (context, index) {
          final zekr = widget.category.azkar[index];
          final currentCount = _counts[zekr.id] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ZekrCard(
              index: index + 1,
              zekr: zekr,
              count: currentCount,
              isDone: currentCount >= zekr.targetCount,
              onTap: () => _increment(zekr),
              onReset: () => _reset(zekr),
            ),
          );
        },
      ),
    );
  }
}

/// One dhikr: its text (revelation framed and in the Mushaf face), what it
/// brings, where it is narrated, and how many repetitions are left.
class _ZekrCard extends StatelessWidget {
  const _ZekrCard({
    required this.index,
    required this.zekr,
    required this.count,
    required this.isDone,
    required this.onTap,
    required this.onReset,
  });

  final int index;
  final ZekrItem zekr;
  final int count;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final remaining = (zekr.targetCount - count).clamp(0, zekr.targetCount);

    return AnimatedContainer(
      duration: AppMotion.base,
      decoration: BoxDecoration(
        // Finished ones step back rather than lighting up: what is left to say
        // should be what stands out.
        color: isDone ? tokens.groundAlt : tokens.surface,
        borderRadius: AppRadii.lgAll,
        boxShadow: isDone ? null : AppShadows.soft(tokens.ink),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.lgAll,
          onTap: isDone ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, colorScheme),
                const SizedBox(height: 14),
                ArabicTextBlock(text: zekr.textAr),
                if (zekr.virtue.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _virtue(context, colorScheme),
                ],
                if (zekr.reference.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${context.tr('narrated_by')}: ${zekr.reference}',
                          style: AppTextStyles.caption(context),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _footer(context, colorScheme, remaining),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: AppTextStyles.caption(
              context,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Spacer(),
        if (zekr.targetCount > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${context.tr('repeat_label')} ${zekr.targetCount}',
              style: AppTextStyles.caption(
                context,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _virtue(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(zekr.virtue, style: AppTextStyles.caption(context)),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, ColorScheme colorScheme, int remaining) {
    return Row(
      children: [
        if (count > 0)
          IconButton(
            tooltip: context.tr('reset_all'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: onReset,
          ),
        Expanded(
          child: Text(
            isDone
                ? context.tr('zekr_done')
                : '${context.tr('zekr_tap_to_count')} · $remaining',
            style: AppTextStyles.caption(
              context,
              color: isDone ? colorScheme.primary : null,
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                value: zekr.targetCount == 0 ? 1 : count / zekr.targetCount,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                strokeWidth: 4,
              ),
            ),
            isDone
                ? Icon(Icons.check, color: colorScheme.primary)
                : Text(
                  '$count',
                  style: AppTextStyles.body(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
