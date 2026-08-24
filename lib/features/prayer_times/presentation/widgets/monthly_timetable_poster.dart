import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// One row of the printable month.
class TimetableEntry {
  const TimetableEntry({
    required this.day,
    required this.weekday,
    required this.hijri,
    required this.times,
    this.isFriday = false,
    this.isToday = false,
  });

  /// Day of the Gregorian month.
  final int day;

  final String weekday;

  /// "١٢ صفر" — the Hijri date for the same day.
  final String hijri;

  /// Already formatted, in the same order as the column headings.
  final List<String> times;

  final bool isFriday;
  final bool isToday;
}

/// Column headings and captions, passed in so the poster carries no
/// localization plumbing of its own.
class TimetablePosterLabels {
  const TimetablePosterLabels({
    required this.title,
    required this.day,
    required this.weekday,
    required this.hijri,
    required this.columns,
    required this.footer,
    required this.appName,
  });

  final String title;
  final String day;
  final String weekday;
  final String hijri;

  /// Six headings: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.
  final List<String> columns;

  final String footer;
  final String appName;
}

/// A month of prayer times, drawn to be shared or printed.
///
/// Deliberately plainer than the Ramadan poster: this is a reference sheet
/// somebody pins to a wall and reads at a glance from across a room, so the
/// ornament is a thin frame and everything else is spent on making thirty-one
/// rows of small numbers legible — wide columns, alternating tints, and
/// Fridays marked.
class MonthlyTimetablePoster extends StatelessWidget {
  const MonthlyTimetablePoster({
    super.key,
    required this.entries,
    required this.monthLabel,
    required this.hijriLabel,
    required this.locationLabel,
    required this.labels,
  });

  final List<TimetableEntry> entries;

  /// "March 2027".
  final String monthLabel;

  /// "شعبان – رمضان ١٤٤٨" — the Hijri months this Gregorian month crosses.
  final String hijriLabel;

  final String locationLabel;
  final TimetablePosterLabels labels;

  static const double width = 1240;

  static const Color _paper = Color(0xFFFCF8F0);
  static const Color _ink = Color(0xFF23301F);
  static const Color _inkSoft = Color(0xFF6B7A63);
  static const Color _green = Color(0xFF14532D);
  static const Color _gold = Color(0xFFB08432);
  static const Color _rowTint = Color(0xFFF1EDE1);
  static const Color _fridayTint = Color(0xFFE4EEE2);
  static const Color _line = Color(0xFFD9D2C0);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: _paper,
        padding: const EdgeInsets.all(34),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: _gold, width: 3)),
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 22),
              _headingRow(),
              for (var i = 0; i < entries.length; i++)
                _row(entries[i], striped: i.isEven),
              const SizedBox(height: 18),
              Text(
                labels.footer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.bodyFamily,
                  fontSize: 19,
                  color: _inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Text(
          labels.title,
          style: const TextStyle(
            fontFamily: AppTextStyles.displayFamily,
            fontSize: 46,
            color: _green,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          monthLabel,
          style: const TextStyle(
            fontFamily: AppTextStyles.displayFamily,
            fontSize: 32,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hijriLabel,
          style: const TextStyle(
            fontFamily: AppTextStyles.bodyFamily,
            fontSize: 23,
            color: _gold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          locationLabel,
          style: const TextStyle(
            fontFamily: AppTextStyles.bodyFamily,
            fontSize: 21,
            color: _inkSoft,
          ),
        ),
      ],
    );
  }

  /// The day and weekday columns are wider because they hold words, not
  /// four-character clock readings.
  static const int _dayFlex = 5;
  static const int _weekdayFlex = 5;
  static const int _hijriFlex = 5;
  static const int _timeFlex = 4;

  Widget _headingRow() {
    Widget cell(String text, int flex) => Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTextStyles.displayFamily,
          fontSize: 21,
          color: _paper,
        ),
      ),
    );

    return Container(
      color: _green,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          cell(labels.day, _dayFlex),
          cell(labels.weekday, _weekdayFlex),
          cell(labels.hijri, _hijriFlex),
          for (final column in labels.columns) cell(column, _timeFlex),
        ],
      ),
    );
  }

  Widget _row(TimetableEntry entry, {required bool striped}) {
    final background =
        entry.isFriday ? _fridayTint : (striped ? _rowTint : _paper);

    Widget cell(String text, int flex, {bool strong = false}) => Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTextStyles.bodyFamily,
          fontSize: 20,
          height: 1.1,
          color: entry.isFriday ? _green : _ink,
          fontWeight: strong || entry.isFriday ? FontWeight.w700 : null,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: const Border(bottom: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          cell('${entry.day}', _dayFlex, strong: true),
          cell(entry.weekday, _weekdayFlex),
          cell(entry.hijri, _hijriFlex),
          for (final time in entry.times) cell(time, _timeFlex),
        ],
      ),
    );
  }
}
