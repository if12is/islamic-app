import 'package:flutter/material.dart';

import '../../../../core/services/hijri_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/islamic_ornaments.dart';

/// One row of the poster.
class ImsakiyaEntry {
  const ImsakiyaEntry({
    required this.hijriDay,
    required this.gregorian,
    required this.weekday,
    required this.imsak,
    required this.fajr,
    required this.maghrib,
  });

  final int hijriDay;
  final DateTime gregorian;
  final String weekday;
  final String imsak;
  final String fajr;
  final String maghrib;
}

/// A printable Ramadan timetable, drawn to be shared as an image.
///
/// The look is the one people already recognise from mosque and shop posters:
/// a pointed arch, hanging lanterns, and a gold table — with the times
/// calculated for this user's own city rather than a generic list.
class ImsakiyaPoster extends StatelessWidget {
  const ImsakiyaPoster({
    super.key,
    required this.entries,
    required this.hijriYear,
    required this.locationLabel,
    required this.labels,
  });

  final List<ImsakiyaEntry> entries;
  final int hijriYear;
  final String locationLabel;

  /// Column headings and captions, passed in so the poster stays free of
  /// localization plumbing.
  final ImsakiyaPosterLabels labels;

  static const double width = 1080;

  static const Color _paper = Color(0xFFFBF5E9);
  static const Color _ink = Color(0xFF4A2F13);
  static const Color _gold = Color(0xFFB8860B);
  static const Color _goldSoft = Color(0xFFE8C77E);
  static const Color _rowTint = Color(0xFFF3E7CE);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: _paper,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: const _PosterFramePainter()),
            ),
            Padding(
              // The inner gold arch sits 46px inside the outer frame, which
              // starts 28px from the edge — so anything closer than 74px to a
              // side is drawn on top of that border rather than inside it.
              // The footer used to land 18px past it, straddling the line.
              padding: const EdgeInsets.fromLTRB(92, 210, 92, 104),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                    style: const TextStyle(
                      fontFamily: AppTextStyles.quranFamily,
                      fontSize: 34,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    labels.title,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.displayFamily,
                      fontSize: 54,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'رمضان $hijriYear هـ',
                    style: const TextStyle(
                      fontFamily: AppTextStyles.displayFamily,
                      fontSize: 30,
                      color: _gold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      locationLabel,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.bodyFamily,
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _table(),
                  const SizedBox(height: 22),
                  Text(
                    labels.footer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTextStyles.bodyFamily,
                      fontSize: 19,
                      height: 1.5,
                      color: _ink.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The name reads as a signature on the poster rather than
                  // as the tail of a sentence about how the times were worked
                  // out — which is what it was.
                  Text(
                    labels.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.displayFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _gold, width: 3),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _row(
            cells: [
              labels.dayNumber,
              labels.date,
              labels.weekday,
              labels.imsak,
              labels.fajr,
              labels.iftar,
            ],
            background: _gold,
            textColor: Colors.white,
            bold: true,
          ),
          for (var i = 0; i < entries.length; i++)
            _row(
              cells: [
                _arabicNumber(entries[i].hijriDay),
                '${entries[i].gregorian.day}/${entries[i].gregorian.month}',
                entries[i].weekday,
                entries[i].imsak,
                entries[i].fajr,
                entries[i].maghrib,
              ],
              background: i.isEven ? Colors.white : _rowTint,
              textColor: _ink,
              bold: entries[i].hijriDay >= 21,
            ),
        ],
      ),
    );
  }

  Widget _row({
    required List<String> cells,
    required Color background,
    required Color textColor,
    bool bold = false,
  }) {
    const flexes = [2, 3, 3, 3, 3, 3];

    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flexes[i],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start:
                        i == 0
                            ? BorderSide.none
                            : BorderSide(color: _goldSoft, width: 1),
                  ),
                ),
                child: Text(
                  cells[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTextStyles.bodyFamily,
                    fontSize: 24,
                    height: 1.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _arabicNumber(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }

  /// Weekday name for a date, in the poster's language.
  static String weekdayName(DateTime date, List<String> names) =>
      names[date.weekday % 7];

  /// Build the rows from calculated days.
  static List<ImsakiyaEntry> entriesFrom({
    required int hijriYear,
    required int hijriMonth,
    required List<String> weekdayNames,
    required DateTime Function(int hijriDay) gregorianFor,
    required String Function(DateTime date) imsakFor,
    required String Function(DateTime date) fajrFor,
    required String Function(DateTime date) maghribFor,
  }) {
    final days = HijriService.daysInMonth(hijriYear, hijriMonth);

    return List<ImsakiyaEntry>.generate(days, (index) {
      final hijriDay = index + 1;
      final gregorian = gregorianFor(hijriDay);

      return ImsakiyaEntry(
        hijriDay: hijriDay,
        gregorian: gregorian,
        weekday: weekdayName(gregorian, weekdayNames),
        imsak: imsakFor(gregorian),
        fajr: fajrFor(gregorian),
        maghrib: maghribFor(gregorian),
      );
    });
  }
}

/// Text the poster needs, resolved by the caller.
class ImsakiyaPosterLabels {
  const ImsakiyaPosterLabels({
    required this.title,
    required this.dayNumber,
    required this.date,
    required this.weekday,
    required this.imsak,
    required this.fajr,
    required this.iftar,
    required this.footer,
    required this.appName,
  });

  final String title;
  final String dayNumber;
  final String date;
  final String weekday;
  final String imsak;
  final String fajr;
  final String iftar;
  final String footer;

  /// Shown on its own line as the poster's signature.
  final String appName;
}

/// The arch, the lattice inside it, and the hanging lanterns.
class _PosterFramePainter extends CustomPainter {
  const _PosterFramePainter();

  /// Height of the pointed head, in pixels rather than a fraction, so a
  /// 30-row poster keeps the same silhouette as a 29-row one.
  static const double _archHead = 300;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(28, 96, size.width - 56, size.height - 124);
    final arch = IslamicOrnaments.archPath(frame, pointPixels: _archHead);

    // Outer arch band.
    canvas.drawPath(
      arch,
      Paint()
        ..color = ImsakiyaPoster._gold.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );

    canvas
      ..save()
      ..clipPath(arch);
    IslamicOrnaments.lattice(
      canvas,
      frame,
      ImsakiyaPoster._gold.withValues(alpha: 0.35),
      cell: 62,
    );
    canvas.restore();

    canvas.drawPath(
      arch,
      Paint()
        ..color = ImsakiyaPoster._gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    // Inner panel the content sits on.
    final inner = frame.deflate(46);
    final innerArch = IslamicOrnaments.archPath(
      inner,
      pointPixels: _archHead - 46,
    );
    canvas
      ..drawPath(innerArch, Paint()..color = ImsakiyaPoster._paper)
      ..drawPath(
        innerArch,
        Paint()
          ..color = ImsakiyaPoster._gold.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

    // Lanterns hanging from the top corners.
    IslamicOrnaments.lantern(
      canvas,
      top: Offset(size.width * 0.12, 0),
      width: 78,
      cordLength: 96,
      color: ImsakiyaPoster._gold,
    );
    IslamicOrnaments.lantern(
      canvas,
      top: Offset(size.width * 0.24, 0),
      width: 58,
      cordLength: 42,
      color: ImsakiyaPoster._goldSoft,
    );
    IslamicOrnaments.lantern(
      canvas,
      top: Offset(size.width * 0.88, 0),
      width: 78,
      cordLength: 96,
      color: ImsakiyaPoster._gold,
    );
    IslamicOrnaments.lantern(
      canvas,
      top: Offset(size.width * 0.76, 0),
      width: 58,
      cordLength: 42,
      color: ImsakiyaPoster._goldSoft,
    );
  }

  @override
  bool shouldRepaint(covariant _PosterFramePainter oldDelegate) => false;
}
