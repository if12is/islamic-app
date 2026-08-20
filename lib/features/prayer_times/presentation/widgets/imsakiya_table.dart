import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/hijri_service.dart';
import '../../../../core/services/notification_scheduler.dart';
import '../../../../core/services/prayer_calculation_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/providers/app_providers.dart';
import 'imsakiya_poster.dart';

/// The Ramadan timetable: imsak, fajr, and iftar for every day of the month.
///
/// Every row is calculated on the device from the user's own location and
/// method, so the table matches the app's prayer times exactly — and works
/// with no connection.
class ImsakiyaTable extends ConsumerWidget {
  const ImsakiyaTable({
    super.key,
    required this.hijriYear,
    required this.hijriMonth,
  });

  final int hijriYear;
  final int hijriMonth;

  /// Minutes before Fajr that imsakiyas traditionally print as "الإمساك".
  static const int imsakOffsetMinutes = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = ref.watch(currentLocationCoordinatesProvider);
    final method = ref.watch(prayerMethodProvider);
    final settings = ref.watch(prayerCalculationSettingsProvider);
    final languageCode = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: location.when(
        loading:
            () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
        error:
            (_, _) => Text(
              context.tr('imsakiya_unavailable'),
              style: AppTextStyles.body(context),
            ),
        data: (coordinates) {
          final rows = _buildRows(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            method: method,
            settings: settings,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.nights_stay,
                    color: colorScheme.secondary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('imsakiya'),
                      style: AppTextStyles.display(context, fontSize: 18),
                    ),
                  ),
                  MenuAnchor(
                    builder:
                        (context, controller, child) => IconButton(
                          tooltip: context.tr('share_image'),
                          icon: const Icon(Icons.ios_share, size: 20),
                          onPressed:
                              () =>
                                  controller.isOpen
                                      ? controller.close()
                                      : controller.open(),
                        ),
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.image, size: 18),
                        onPressed:
                            () => _shareImage(
                              context,
                              rows,
                              languageCode,
                              ref.read(locationLabelProvider).value ?? '',
                            ),
                        child: Text(context.tr('share_image')),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.notes, size: 18),
                        onPressed: () => _share(context, rows, languageCode),
                        child: Text(context.tr('share_text')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('imsakiya_desc'),
                style: AppTextStyles.caption(context),
              ),
              const SizedBox(height: 14),
              _headerRow(context, colorScheme),
              const SizedBox(height: 6),
              for (final row in rows) _dataRow(context, row, languageCode),
              const SizedBox(height: 10),
              Text(
                context.tr('imsakiya_note'),
                style: AppTextStyles.caption(context),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_ImsakiyaRow> _buildRows({
    required double latitude,
    required double longitude,
    required int method,
    required PrayerCalculationSettings settings,
  }) {
    final days = HijriService.daysInMonth(hijriYear, hijriMonth);

    return List<_ImsakiyaRow>.generate(days, (index) {
      final hijriDay = index + 1;
      final gregorian = HijriService.toGregorian(
        hijriYear,
        hijriMonth,
        hijriDay,
        offsetDays: settings.hijriOffsetDays,
      );

      final computed = PrayerCalculationService.computeDay(
        latitude: latitude,
        longitude: longitude,
        method: method,
        date: gregorian,
        settings: settings,
      );

      final fajr = computed.timeOf(PrayerIds.fajr)!;
      return _ImsakiyaRow(
        hijriDay: hijriDay,
        gregorian: gregorian,
        imsak: fajr.subtract(const Duration(minutes: imsakOffsetMinutes)),
        fajr: fajr,
        maghrib: computed.timeOf(PrayerIds.maghrib)!,
      );
    });
  }

  Widget _headerRow(BuildContext context, ColorScheme colorScheme) {
    Widget cell(String text, {int flex = 2}) => Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption(
          context,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          cell(context.tr('imsakiya_day'), flex: 3),
          cell(context.tr('weekday'), flex: 3),
          cell(context.tr('imsak')),
          cell(context.tr('iftar')),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, _ImsakiyaRow row, String languageCode) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = HijriService.fromGregorian(DateTime.now());
    final isToday =
        today.hYear == hijriYear &&
        today.hMonth == hijriMonth &&
        today.hDay == row.hijriDay;
    final isLastTen = HijriService.isLastTenOfRamadan(hijriMonth, row.hijriDay);

    Widget cell(String text, {int flex = 2, bool emphasise = false}) =>
        Expanded(
          flex: flex,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption(
              context,
              color: emphasise ? colorScheme.primary : null,
            ).copyWith(fontWeight: isToday ? FontWeight.bold : null),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color:
            isToday
                ? colorScheme.primary.withValues(alpha: 0.12)
                : isLastTen
                ? colorScheme.secondary.withValues(alpha: 0.06)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          cell(
            '${row.hijriDay} · ${row.gregorian.day}/${row.gregorian.month}',
            flex: 3,
            emphasise: isToday,
          ),
          cell(_weekdayName(context, row.gregorian), flex: 3),
          cell(NotificationPlanner.formatClock(row.imsak, languageCode)),
          cell(NotificationPlanner.formatClock(row.maghrib, languageCode)),
        ],
      ),
    );
  }

  /// Weekday names in the reader's language, Sunday first.
  static List<String> weekdayNames(BuildContext context) => [
    context.tr('weekday_sunday'),
    context.tr('weekday_monday'),
    context.tr('weekday_tuesday'),
    context.tr('weekday_wednesday'),
    context.tr('weekday_thursday'),
    context.tr('weekday_friday'),
    context.tr('weekday_saturday'),
  ];

  String _weekdayName(BuildContext context, DateTime date) =>
      weekdayNames(context)[date.weekday % 7];

  /// Render the poster off-screen and share it as an image.
  Future<void> _shareImage(
    BuildContext context,
    List<_ImsakiyaRow> rows,
    String languageCode,
    String locationLabel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final preparing = context.tr('preparing_image');
    final failed = context.tr('share_failed');

    final poster = ImsakiyaPoster(
      hijriYear: hijriYear,
      locationLabel:
          locationLabel.isEmpty
              ? context.tr('location_unknown')
              : locationLabel,
      labels: ImsakiyaPosterLabels(
        title: context.tr('imsakiya'),
        dayNumber: context.tr('ramadan_month'),
        date: context.tr('gregorian'),
        weekday: context.tr('weekday'),
        imsak: context.tr('imsak'),
        fajr: context.tr('fajr'),
        iftar: context.tr('iftar'),
        footer: context.tr('imsakiya_footer'),
      ),
      entries: [
        for (final row in rows)
          ImsakiyaEntry(
            hijriDay: row.hijriDay,
            gregorian: row.gregorian,
            weekday: _weekdayName(context, row.gregorian),
            imsak: NotificationPlanner.formatClock(row.imsak, languageCode),
            fajr: NotificationPlanner.formatClock(row.fajr, languageCode),
            maghrib: NotificationPlanner.formatClock(row.maghrib, languageCode),
          ),
      ],
    );

    messenger.showSnackBar(SnackBar(content: Text(preparing)));

    try {
      // Measured, not guessed: a guessed height clipped the last days of the
      // month and left Flutter's overflow stripes across the image.
      final bytes = await ScreenshotController().captureFromLongWidget(
        poster,
        delay: const Duration(milliseconds: 200),
        pixelRatio: 1,
        constraints: const BoxConstraints(
          minWidth: ImsakiyaPoster.width,
          maxWidth: ImsakiyaPoster.width,
        ),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: 'imsakiya.png'),
          ],
          fileNameOverrides: const ['imsakiya.png'],
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to render the imsakiya poster', e, stack);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _share(
    BuildContext context,
    List<_ImsakiyaRow> rows,
    String languageCode,
  ) async {
    final buffer =
        StringBuffer()
          ..writeln(
            '${context.tr('imsakiya')} — ${HijriService.monthName(hijriMonth)} $hijriYear',
          )
          ..writeln();

    for (final row in rows) {
      buffer.writeln(
        '${row.hijriDay} ${HijriService.monthName(hijriMonth)} '
        '(${row.gregorian.day}/${row.gregorian.month} · '
        '${_weekdayName(context, row.gregorian)}) — '
        '${context.tr('imsak')}: '
        '${NotificationPlanner.formatClock(row.imsak, languageCode)} · '
        '${context.tr('iftar')}: '
        '${NotificationPlanner.formatClock(row.maghrib, languageCode)}',
      );
    }

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }
}

class _ImsakiyaRow {
  const _ImsakiyaRow({
    required this.hijriDay,
    required this.gregorian,
    required this.imsak,
    required this.fajr,
    required this.maghrib,
  });

  final int hijriDay;
  final DateTime gregorian;
  final DateTime imsak;
  final DateTime fajr;
  final DateTime maghrib;
}
