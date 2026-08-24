import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_cards.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/monthly_timetable.dart';
import '../widgets/monthly_timetable_poster.dart';

/// A whole month of prayer times, for planning ahead and for printing.
///
/// The daily screen answers "when is the next prayer"; this answers "what does
/// the week after next look like", which is the question someone asks when
/// booking a flight or arranging a shift. Every row comes from the same
/// on-device calculation as the daily screen, so the two can never disagree,
/// and it works with no connection because nothing here is fetched.
class MonthlyTimetablePage extends ConsumerStatefulWidget {
  const MonthlyTimetablePage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MonthlyTimetablePage()),
    );
  }

  @override
  ConsumerState<MonthlyTimetablePage> createState() =>
      _MonthlyTimetablePageState();
}

class _MonthlyTimetablePageState extends ConsumerState<MonthlyTimetablePage> {
  late int _year;
  late int _month;

  static const double _rowHeight = 44;
  static const double _headingHeight = 40;

  /// Widths the table would like. When the screen is wider they are scaled up
  /// to fill it; when it is narrower the whole table scrolls sideways as one
  /// piece.
  ///
  /// A pinned day column with the times scrolling beside it was the first
  /// shape tried, and it cannot be built honestly: one `ScrollController`
  /// cannot drive thirty-one scroll views, and syncing thirty-one of them is a
  /// jitter machine. Scrolling the table as a single object is both simpler
  /// and steadier.
  static const double _dayWidth = 98;
  static const double _timeWidth = 64;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _step(int by) {
    final (year, month) = MonthlyTimetable.shift(_year, _month, by);
    setState(() {
      _year = year;
      _month = month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = Localizations.localeOf(context).languageCode;
    final location = ref.watch(currentLocationCoordinatesProvider);
    final method = ref.watch(prayerMethodProvider);
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final place = ref.watch(locationLabelProvider).value ?? '';

    return AppScaffold(
      title: 'monthly_timetable',
      showBack: true,
      body: location.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error:
            (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  context.tr('imsakiya_unavailable'),
                  style: AppTextStyles.body(context),
                ),
              ),
            ),
        data: (coordinates) {
          final table = MonthlyTimetable.build(
            year: _year,
            month: _month,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            method: method,
            settings: settings,
          );

          return Column(
            children: [
              _MonthBar(
                label: _monthLabel(context, _year, _month),
                hijriLabel: _hijriLabel(context, table),
                onPrevious: () => _step(-1),
                onNext: () => _step(1),
                onShare: () => _shareSheet(table, place, language),
              ),
              if (place.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    place,
                    style: AppTextStyles.caption(
                      context,
                      color: tokens.inkFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              Expanded(child: _table(table, language)),
            ],
          );
        },
      ),
    );
  }

  Widget _table(MonthlyTimetable table, String language) {
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const natural = _dayWidth + _timeWidth * 6;
          final available = constraints.maxWidth;
          final scale = available > natural ? available / natural : 1.0;
          final dayWidth = _dayWidth * scale;
          final timeWidth = _timeWidth * scale;
          final tableWidth = natural * scale;

          return ClipRRect(
            borderRadius: AppRadii.mdAll,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics:
                  scale > 1
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    _HeadingRow(
                      dayWidth: dayWidth,
                      timeWidth: timeWidth,
                      height: _headingHeight,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: table.days.length,
                        itemExtent: _rowHeight,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final day = table.days[index];
                          return _DayRow(
                            day: day,
                            language: language,
                            isToday: day.isSameDayAs(today),
                            dayWidth: dayWidth,
                            timeWidth: timeWidth,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- sharing

  Future<void> _shareSheet(
    MonthlyTimetable table,
    String place,
    String language,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(sheet.tr('share_image')),
                  onTap: () => Navigator.of(sheet).pop('image'),
                ),
                ListTile(
                  leading: const Icon(Icons.notes_rounded),
                  title: Text(sheet.tr('share_text')),
                  onTap: () => Navigator.of(sheet).pop('text'),
                ),
              ],
            ),
          ),
    );

    if (!mounted || choice == null) {
      return;
    }
    if (choice == 'image') {
      await _shareImage(table, place, language);
    } else {
      await _shareText(table, place, language);
    }
  }

  Future<void> _shareText(
    MonthlyTimetable table,
    String place,
    String language,
  ) async {
    final buffer =
        StringBuffer()..writeln(
          '${context.tr('monthly_timetable')} — '
          '${_monthLabel(context, _year, _month)}',
        );
    if (place.isNotEmpty) {
      buffer.writeln(place);
    }
    buffer.writeln();

    for (final day in table.days) {
      final times = [
        for (final id in PrayerIds.all)
          '${context.tr(id)} ${formatTableClock(day[id], language)}',
      ].join(' · ');
      buffer.writeln(
        '${day.date.day} ${weekdayName(context, day.date)} — $times',
      );
    }

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _shareImage(
    MonthlyTimetable table,
    String place,
    String language,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final preparing = context.tr('preparing_image');
    final failed = context.tr('share_failed');
    final today = DateTime.now();

    final poster = MonthlyTimetablePoster(
      monthLabel: _monthLabel(context, _year, _month),
      hijriLabel: _hijriLabel(context, table),
      locationLabel: place.isEmpty ? context.tr('location_unknown') : place,
      labels: TimetablePosterLabels(
        title: context.tr('monthly_timetable'),
        day: context.tr('imsakiya_day'),
        weekday: context.tr('weekday'),
        hijri: context.tr('hijri'),
        columns: [for (final id in PrayerIds.all) context.tr(id)],
        footer: context.tr('imsakiya_footer'),
        appName: context.tr('app_title'),
      ),
      entries: [
        for (final day in table.days)
          TimetableEntry(
            day: day.date.day,
            weekday: weekdayName(context, day.date),
            hijri:
                '${day.hijri.day} '
                '${language == 'ar' ? day.hijri.monthNameAr : day.hijri.monthNameEn}',
            isFriday: day.isFriday,
            isToday: day.isSameDayAs(today),
            times: [
              for (final id in PrayerIds.all)
                formatTableClock(day[id], language),
            ],
          ),
      ],
    );

    messenger.showSnackBar(SnackBar(content: Text(preparing)));

    try {
      // Measured rather than guessed: thirty-one rows overflowed a fixed
      // canvas and the last days of the month came out under Flutter's
      // overflow stripes.
      final bytes = await ScreenshotController().captureFromLongWidget(
        poster,
        delay: const Duration(milliseconds: 200),
        pixelRatio: 1,
        constraints: const BoxConstraints(
          minWidth: MonthlyTimetablePoster.width,
          maxWidth: MonthlyTimetablePoster.width,
        ),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: 'timetable.png'),
          ],
          fileNameOverrides: const ['timetable.png'],
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to render the monthly timetable', e, stack);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  // ----------------------------------------------------------------- labels

  static String _monthLabel(BuildContext context, int year, int month) =>
      '${context.tr('gregorian_month_$month')} $year';

  /// "شعبان – رمضان ١٤٤٨". A Gregorian month almost always straddles two
  /// Hijri months, and naming only one of them would misdate half the sheet.
  static String _hijriLabel(BuildContext context, MonthlyTimetable table) {
    final span = table.hijriSpan;
    if (span.isEmpty) {
      return '';
    }
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String name(HijriParts parts) =>
        arabic ? parts.monthNameAr : parts.monthNameEn;

    final first = span.first;
    final last = span.last;
    if (span.length == 1) {
      return '${name(first)} ${first.year}';
    }
    final years =
        first.year == last.year
            ? '${last.year}'
            : '${first.year} – ${last.year}';
    return '${name(first)} – ${name(last)} $years';
  }
}

/// Sunday-first, matching `DateTime.weekday % 7`.
String weekdayName(BuildContext context, DateTime date) => context.tr(
  const [
    'weekday_sunday',
    'weekday_monday',
    'weekday_tuesday',
    'weekday_wednesday',
    'weekday_thursday',
    'weekday_friday',
    'weekday_saturday',
  ][date.weekday % 7],
);

/// A compact reading for a table: no am/pm marker.
///
/// Every column is unambiguous on its own — Fajr is never in the afternoon,
/// Isha never in the morning — and six suffixes across a phone-width row cost
/// more room than they explain. This is also how printed timetables have
/// always done it.
String formatTableClock(DateTime? time, String language) {
  if (time == null) {
    return '—';
  }
  var hour = time.hour % 12;
  if (hour == 0) {
    hour = 12;
  }
  final text = '$hour:${time.minute.toString().padLeft(2, '0')}';
  return language == 'ar' ? _arabicDigits(text) : text;
}

String _arabicDigits(String value) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = int.tryParse(char);
    buffer.write(index == null ? char : digits[index]);
  }
  return buffer.toString();
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow({
    required this.dayWidth,
    required this.timeWidth,
    required this.height,
  });

  final double dayWidth;
  final double timeWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption(
            context,
            color: tokens.ink,
            fontSize: 11.5,
          ),
        ),
      ),
    );

    return Container(
      // brandSoft, not brand: brand is a dark green in the light theme and a
      // bright one in the dark theme, so a single foreground colour cannot be
      // legible on both. brandSoft tracks the theme and takes plain ink.
      color: tokens.brandSoft,
      height: height,
      child: Row(
        children: [
          cell(context.tr('imsakiya_day'), dayWidth),
          for (final id in PrayerIds.all) cell(context.tr(id), timeWidth),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.language,
    required this.isToday,
    required this.dayWidth,
    required this.timeWidth,
  });

  final TimetableDay day;
  final String language;
  final bool isToday;
  final double dayWidth;
  final double timeWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final background =
        isToday
            ? tokens.brand.withValues(alpha: 0.14)
            : day.isFriday
            ? tokens.gold.withValues(alpha: 0.08)
            : tokens.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: dayWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.date.day} · ${weekdayName(context, day.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(
                      context,
                      color: isToday ? tokens.brand : tokens.ink,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    '${day.hijri.day} '
                    '${language == 'ar' ? day.hijri.monthNameAr : day.hijri.monthNameEn}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          for (final id in PrayerIds.all)
            SizedBox(
              width: timeWidth,
              child: Center(
                child: Text(
                  formatTableClock(day[id], language),
                  maxLines: 1,
                  style: AppTextStyles.caption(
                    context,
                    // Sunrise is not a prayer, so it is present but quieter —
                    // otherwise the eye counts six prayers on this sheet.
                    color:
                        id == PrayerIds.sunrise ? tokens.inkFaint : tokens.ink,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.hijriLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onShare,
  });

  final String label;
  final String hijriLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // A Row already lays its children out in reading order, so "previous"
    // lands on the correct side by itself — but the chevron has to be told,
    // or it points into the month it just came from.
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: context.tr('previous_month'),
              onPressed: onPrevious,
              icon: Icon(
                rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.display(context, fontSize: 16.5),
                  ),
                  if (hijriLabel.isNotEmpty)
                    Text(
                      hijriLabel,
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
            ),
            IconButton(
              tooltip: context.tr('next_month'),
              onPressed: onNext,
              icon: Icon(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              ),
            ),
            IconButton(
              tooltip: context.tr('share_image'),
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
