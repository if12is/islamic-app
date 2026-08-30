import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../../../core/widgets/app_section.dart';
import '../../data/prayer_log_store.dart';

/// Today's five, tapped once each to record how they were prayed.
///
/// It keeps no score and shows no red. A prayer made up late still reads as
/// prayed, because it was — an app that marked it as a failure would be both
/// wrong and the sort of thing that makes people stop opening it.
class PrayerLogCard extends StatefulWidget {
  const PrayerLogCard({super.key});

  @override
  State<PrayerLogCard> createState() => _PrayerLogCardState();
}

class _PrayerLogCardState extends State<PrayerLogCard> {
  SharedPreferences? _prefs;
  PrayerDay? _today;
  PrayerLogSummary _summary = PrayerLogSummary.empty;

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
      _today = PrayerLogStore.read(prefs, DateTime.now());
      _summary = PrayerLogStore.summarise(prefs, days: 30);
    });
  }

  Future<void> _cycle(String prayerId) async {
    final prefs = _prefs;
    final day = _today;
    if (prefs == null || day == null) {
      return;
    }

    HapticFeedback.selectionClick();
    final next = PrayerLogStore.next(day.recordFor(prayerId));
    await PrayerLogStore.set(prefs, DateTime.now(), prayerId, next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final day = _today;
    if (day == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: context.tr('prayer_log'),
          subtitle: context.tr('prayer_log_desc'),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final id in PrayerLogStore.prayerIds)
                    Expanded(child: _prayerButton(context, tokens, id, day)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              _summaryRow(context, tokens),
            ],
          ),
        ),
      ],
    );
  }

  Widget _prayerButton(
    BuildContext context,
    AppTokens tokens,
    String prayerId,
    PrayerDay day,
  ) {
    final record = day.recordFor(prayerId);
    final colour = _colourFor(record, tokens);

    return Semantics(
      button: true,
      label: '${context.tr(prayerId)} — ${context.tr(_labelKey(record))}',
      child: InkWell(
        onTap: () => _cycle(prayerId),
        borderRadius: AppRadii.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              // The tile's box and radius, with a ring added: this control has
              // five states, not two, and the ring is what tells "not recorded
              // yet" from "recorded as prayed alone" at a glance. The fill was
              // groundAlt when unset and a tinted circle otherwise — two
              // shapes and two colour families for one row of five.
              Container(
                width: AppIconTile.boxFor(AppIconRole.row),
                height: AppIconTile.boxFor(AppIconRole.row),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppIconTile.boxFor(AppIconRole.row) / 3,
                  ),
                  color: colour.withValues(
                    alpha: record == PrayerRecord.none ? 0.06 : 0.16,
                  ),
                  border: Border.all(
                    color:
                        record == PrayerRecord.none
                            ? tokens.line
                            : colour.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  _iconFor(record),
                  size: AppIconTile.glyphFor(AppIconRole.row),
                  color: colour,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr(prayerId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(context, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, AppTokens tokens) {
    final language = Localizations.localeOf(context).languageCode;

    return Row(
      children: [
        Expanded(
          child: Text(
            AppLocalizations.translate(
              language,
              'prayer_log_summary',
              replacements: {
                'percent': '${(_summary.onTimeShare * 100).round()}',
                'days': '${_summary.days}',
              },
            ),
            style: AppTextStyles.caption(context, color: tokens.inkMuted),
          ),
        ),
        if (_summary.streak > 0)
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 15,
                color: tokens.goldInk,
              ),
              const SizedBox(width: 2),
              Text(
                '${_summary.streak}',
                style: AppTextStyles.caption(context, color: tokens.goldInk),
              ),
            ],
          ),
      ],
    );
  }

  static IconData _iconFor(PrayerRecord record) => switch (record) {
    PrayerRecord.none => Icons.circle_outlined,
    PrayerRecord.mosque => Icons.mosque,
    PrayerRecord.congregation => Icons.groups,
    PrayerRecord.alone => Icons.person,
    PrayerRecord.missed => Icons.history,
  };

  static String _labelKey(PrayerRecord record) => switch (record) {
    PrayerRecord.none => 'prayer_log_none',
    PrayerRecord.mosque => 'prayer_log_mosque',
    PrayerRecord.congregation => 'prayer_log_congregation',
    PrayerRecord.alone => 'prayer_log_alone',
    PrayerRecord.missed => 'prayer_log_missed',
  };

  static Color _colourFor(PrayerRecord record, AppTokens tokens) =>
      switch (record) {
        PrayerRecord.none => tokens.inkFaint,
        PrayerRecord.mosque => tokens.brand,
        PrayerRecord.congregation => tokens.brand,
        PrayerRecord.alone => tokens.gold,
        // Amber, not red: it was prayed, only late.
        PrayerRecord.missed => tokens.inkMuted,
      };
}
