import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/follow_up_reminders.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_icon_tile.dart';
import '../../data/prayer_log_store.dart';

/// "How did you pray Fajr?" — the four answers, one tap each.
///
/// Opened by the reminder that comes after each prayer, and by a long press
/// on the log card. The card's single tap steps through the options, which is
/// quick for someone who knows the order and a riddle for someone who does
/// not; this names them all at once.
class PrayerLogSheet extends StatelessWidget {
  const PrayerLogSheet({
    super.key,
    required this.prayerId,
    required this.date,
    required this.current,
  });

  final String prayerId;
  final DateTime date;
  final PrayerRecord current;

  static const List<PrayerRecord> choices = [
    PrayerRecord.mosque,
    PrayerRecord.congregation,
    PrayerRecord.alone,
    PrayerRecord.missed,
  ];

  static Future<void> show(
    BuildContext context, {
    required String prayerId,
    DateTime? date,
  }) async {
    final day = date ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) {
      return;
    }
    final current = PrayerLogStore.read(prefs, day).recordFor(prayerId);

    final chosen = await showModalBottomSheet<PrayerRecord>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Directionality(
            textDirection: sheetContext.appTextDirection,
            child: PrayerLogSheet(
              prayerId: prayerId,
              date: day,
              current: current,
            ),
          ),
    );
    if (chosen == null) {
      return;
    }
    await record(prefs, prayerId: prayerId, date: day, record: chosen);
    if (context.mounted && chosen.isPrayed) {
      confirm(context, prayerId: prayerId, record: chosen);
    }
  }

  /// Write the answer and stop the reminders asking for it.
  static Future<void> record(
    SharedPreferences prefs, {
    required String prayerId,
    required DateTime date,
    required PrayerRecord record,
  }) async {
    await PrayerLogStore.set(prefs, date, prayerId, record);
    await FollowUpReminders.prayerLogged(date, prayerId, record);
  }

  /// "Fajr logged: at the mosque."
  static void confirm(
    BuildContext context, {
    required String prayerId,
    required PrayerRecord record,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    final language = Localizations.localeOf(context).languageCode;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.translate(
              language,
              'prayer_log_saved',
              replacements: {
                'prayer': AppLocalizations.translate(language, prayerId),
                'how': AppLocalizations.translate(language, labelKey(record)),
              },
            ),
          ),
        ),
      );
  }

  static String labelKey(PrayerRecord record) => switch (record) {
    PrayerRecord.none => 'prayer_log_none',
    PrayerRecord.mosque => 'prayer_log_mosque',
    PrayerRecord.congregation => 'prayer_log_congregation',
    PrayerRecord.alone => 'prayer_log_alone',
    PrayerRecord.missed => 'prayer_log_missed',
  };

  static IconData iconFor(PrayerRecord record) => switch (record) {
    PrayerRecord.none => Icons.circle_outlined,
    PrayerRecord.mosque => Icons.mosque,
    PrayerRecord.congregation => Icons.groups,
    PrayerRecord.alone => Icons.person,
    PrayerRecord.missed => Icons.history,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.translate(
                language,
                'notif_log_title',
                replacements: {
                  'prayer': AppLocalizations.translate(language, prayerId),
                },
              ),
              style: AppTextStyles.display(context, fontSize: 18),
            ),
            if (!isToday)
              Text(
                PrayerLogStore.dayKey(date),
                style: AppTextStyles.caption(context, color: tokens.inkFaint),
              ),
            const SizedBox(height: AppSpacing.md),
            for (final choice in choices)
              AppListRow(
                dense: true,
                selected: choice == current,
                leading: AppIconTile(
                  iconFor(choice),
                  role: AppIconRole.row,
                  tone:
                      choice == current
                          ? AppIconTone.brand
                          : AppIconTone.neutral,
                  selected: choice == current,
                ),
                title: context.tr(labelKey(choice)),
                trailing:
                    choice == current
                        ? Icon(Icons.check_rounded, color: tokens.brand)
                        : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(choice);
                },
              ),
            if (current.isPrayed)
              TextButton(
                onPressed: () => Navigator.of(context).pop(PrayerRecord.none),
                child: Text(context.tr('prayer_log_clear')),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('prayer_log_not_yet')),
              ),
          ],
        ),
      ),
    );
  }
}
