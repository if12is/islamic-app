import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_section.dart';
import '../../domain/weekly_report.dart';

/// The week, on screen and as a picture worth sending to someone.
///
/// It reports what happened and stops there. No target, no red, no "you fell
/// behind" — a reading log that scolds is one people stop opening, and the
/// number it would be scolding about is nobody else's business anyway.
class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({
    super.key,
    required this.report,
    required this.previous,
    this.onShare,
  });

  final WeeklyReport report;

  /// Last week, for the one comparison worth making.
  final WeeklyReport previous;

  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 20, color: tokens.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('weekly_report'),
                  style: AppTextStyles.display(
                    context,
                    fontSize: 17,
                    color: tokens.ink,
                  ),
                ),
              ),
              if (onShare != null)
                GhostIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: context.tr('share_image'),
                  onTap: onShare,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _dateRange(context),
            style: AppTextStyles.caption(context, color: tokens.inkFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (report.isEmpty)
            Text(
              context.tr('weekly_report_empty'),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            )
          else ...[
            Row(
              children: [
                _stat(
                  context,
                  tokens,
                  value: '${report.pages}',
                  labelKey: 'pages_read',
                ),
                _stat(
                  context,
                  tokens,
                  value: '${report.minutes}',
                  labelKey: 'minutes_short',
                ),
                _stat(
                  context,
                  tokens,
                  value: '${report.daysRead}/7',
                  labelKey: 'weekly_days_read',
                ),
                _stat(
                  context,
                  tokens,
                  value: '${report.streak}',
                  labelKey: 'reading_streak',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _WeekBars(report: report),
            const SizedBox(height: AppSpacing.md),
            Text(
              _comparison(context),
              style: AppTextStyles.caption(context, color: tokens.inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    AppTokens tokens, {
    required String value,
    required String labelKey,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.display(
              context,
              fontSize: 20,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(labelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              context,
              color: tokens.inkFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _dateRange(BuildContext context) {
    String format(DateTime date) => '${date.day}/${date.month}';
    return '${format(report.start)} – ${format(report.end)}';
  }

  /// The only comparison the card makes, and only when there is one to make.
  String _comparison(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final change = WeeklyReport.changeInPages(report, previous);

    if (previous.isEmpty) {
      return AppLocalizations.translate(
        language,
        'weekly_first_week',
        replacements: {'pages': '${report.pages}'},
      );
    }
    if (change == 0) {
      return AppLocalizations.translate(language, 'weekly_same');
    }
    return AppLocalizations.translate(
      language,
      change > 0 ? 'weekly_more' : 'weekly_fewer',
      replacements: {'pages': '${change.abs()}'},
    );
  }
}

/// Seven bars, Saturday first, each as tall as that day's share of the best
/// day — so a light week still shows its own shape rather than a flat line.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.report});

  final WeeklyReport report;

  static const List<String> _dayKeys = [
    'weekday_saturday',
    'weekday_sunday',
    'weekday_monday',
    'weekday_tuesday',
    'weekday_wednesday',
    'weekday_thursday',
    'weekday_friday',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final best = report.pagesPerDay.fold(0, (a, b) => a > b ? a : b);
    final today = DateTime.now().difference(report.start).inDays.clamp(-1, 7);

    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Semantics(
                label:
                    '${context.tr(_dayKeys[i])}: '
                    '${report.pagesPerDay[i]} ${context.tr('pages_read')}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${report.pagesPerDay[i]}',
                      style: AppTextStyles.caption(
                        context,
                        color:
                            report.pagesPerDay[i] > 0
                                ? tokens.inkMuted
                                : tokens.inkFaint,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height:
                          best == 0
                              ? 3
                              : 3 + 50 * (report.pagesPerDay[i] / best),
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.pillAll,
                        color:
                            report.pagesPerDay[i] == 0
                                ? tokens.line
                                : (i == today ? tokens.gold : tokens.brand),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      // The first letter is enough here; the full name would
                      // wrap or be clipped on a narrow phone.
                      context.tr(_dayKeys[i]).characters.first,
                      style: AppTextStyles.caption(
                        context,
                        color: tokens.inkFaint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The poster version: the same numbers, sized for a phone screenshot.
class WeeklyReportPoster extends StatelessWidget {
  const WeeklyReportPoster({
    super.key,
    required this.report,
    required this.previous,
    required this.language,
  });

  final WeeklyReport report;
  final WeeklyReport previous;
  final String language;

  static const double width = 1080;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Localizations.override(
        context: context,
        locale: Locale(language),
        child: Builder(
          builder: (inner) {
            final tokens = inner.tokens;
            return Container(
              width: width,
              padding: const EdgeInsets.all(64),
              color: tokens.ground,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    inner.tr('weekly_report'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(
                      inner,
                      fontSize: 46,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 40),
                  MediaQuery.withNoTextScaling(
                    child: WeeklyReportCard(report: report, previous: previous),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'الفجر · تطبيق إسلامي',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(
                      inner,
                      color: tokens.inkFaint,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders the poster and hands it to the share sheet.
class WeeklyReportSharing {
  WeeklyReportSharing._();

  static Future<bool> share({
    required BuildContext context,
    required WeeklyReport report,
    required WeeklyReport previous,
  }) async {
    try {
      final language = Localizations.localeOf(context).languageCode;
      final Uint8List bytes = await ScreenshotController().captureFromWidget(
        WeeklyReportPoster(
          report: report,
          previous: previous,
          language: language,
        ),
        context: context,
        pixelRatio: 1,
        delay: const Duration(milliseconds: 120),
      );

      const name = 'weekly_report.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: const [name],
        ),
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('Sharing the weekly report failed', e, stack);
      return false;
    }
  }
}
