import '../../../core/services/hijri_service.dart';
import '../domain/haramain_week.dart';
import 'haramain_name_matcher.dart';

/// Turns the weekly announcement into a [HaramainWeek].
///
/// Pure: text in, value out, no I/O. The announcement is free text reposted
/// by a newspaper, so the parser is strict about the SHAPE (five prayers for
/// each mosque, a date range) and forgiving about the wording (bullets,
/// titles, typos, «للمدة» or «للفترة»). When the shape is wrong it returns
/// null instead of a partial table — half a schedule shown as a whole one is
/// worse than showing last week's.
class HaramainScheduleParser {
  HaramainScheduleParser({HaramainNameMatcher? matcher})
    : _matcher = matcher ?? HaramainNameMatcher();

  final HaramainNameMatcher _matcher;

  static const Map<String, HaramainPrayer> _prayerWords = {
    'الفجر': HaramainPrayer.fajr,
    'الظهر': HaramainPrayer.dhuhr,
    'العصر': HaramainPrayer.asr,
    'المغرب': HaramainPrayer.maghrib,
    'العشاء': HaramainPrayer.isha,
  };

  // Keys are normalised (see [normalizeArabic]); the second spelling of the
  // two «ربيع» and two «جمادى» months is the one some newspapers use.
  static const Map<String, int> _months = {
    'محرم': 1,
    'صفر': 2,
    'ربيع الاول': 3,
    'ربيع الاخر': 4,
    'ربيع الثاني': 4,
    'جمادي الاولي': 5,
    'جمادي الاخره': 6,
    'جمادي الثانيه': 6,
    'رجب': 7,
    'شعبان': 8,
    'رمضان': 9,
    'شوال': 10,
    'ذو القعده': 11,
    'ذو الحجه': 12,
  };

  /// The article text inside the AMP page's body element, with line breaks
  /// kept as newlines. Null when the page no longer has that element, which
  /// is how a redesign shows up: as a parse failure, not as garbage.
  static String? extractBodyText(String html) {
    final start = RegExp(r'<div[^>]*class="abody"[^>]*>').firstMatch(html);
    if (start == null) {
      return null;
    }
    final end = html.indexOf('</div>', start.end);
    if (end < 0) {
      return null;
    }
    var body = html.substring(start.end, end);
    body = body
        .replaceAll(RegExp(r'<amp-img[^>]*>(</amp-img>)?'), '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return _unescape(body);
  }

  static String _unescape(String text) {
    return text
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          return String.fromCharCode(int.parse(m.group(1)!));
        })
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  /// Parses the plain article text. Null unless it holds a date range and
  /// exactly five distinct prayers for each mosque.
  HaramainWeek? parse(
    String text, {
    required String sourceUrl,
    required DateTime fetchedAt,
  }) {
    final dates = _parseDates(text);
    if (dates == null) {
      return null;
    }

    final haram = <HaramainPrayer, ImamEntry>{};
    final nabawi = <HaramainPrayer, ImamEntry>{};
    Map<HaramainPrayer, ImamEntry>? current;
    HaramainMosque? mosque;

    for (final line in text.split('\n')) {
      final colon = line.indexOf(RegExp('[:：]'));
      final head = normalizeArabic(colon < 0 ? line : line.substring(0, colon));

      // «صلاة الفجر» on the Haram block, plain «المغرب» on the Nabawi one.
      final prayerMatch = RegExp(r'^(?:صلاه )?(\S+)$').firstMatch(head);
      final prayer =
          colon < 0 || prayerMatch == null
              ? null
              : _prayerWords[prayerMatch.group(1)];

      if (prayer != null) {
        if (current == null || mosque == null) {
          continue;
        }
        if (current.containsKey(prayer)) {
          return null; // a prayer listed twice: the block is not what we think
        }
        final entry = _matcher.entryFor(line.substring(colon + 1), mosque);
        if (entry.displayName.isEmpty) {
          return null;
        }
        current[prayer] = entry;
        continue;
      }

      final whole = normalizeArabic(line);
      final isHeading = line.trimRight().endsWith(':') || colon >= 0;
      if (whole.startsWith('اولا') ||
          (isHeading &&
              whole.contains('المسجد الحرام') &&
              !whole.contains('النبوي'))) {
        current = haram;
        mosque = HaramainMosque.haram;
      } else if (whole.startsWith('ثانيا') ||
          (isHeading &&
              whole.contains('المسجد النبوي') &&
              !whole.contains('الحرام'))) {
        current = nabawi;
        mosque = HaramainMosque.nabawi;
      }
    }

    if (haram.length != 5 || nabawi.length != 5) {
      return null;
    }

    return HaramainWeek(
      startHijri: dates.start,
      endHijri: dates.end,
      hijriYear: dates.year,
      endsOn: dates.endsOn,
      fetchedAt: fetchedAt,
      sourceUrl: sourceUrl,
      haram: haram,
      nabawi: nabawi,
    );
  }

  _Dates? _parseDates(String text) {
    final flat = normalizeArabic(text);
    final match = RegExp(
      r'(?:^| )من (?:يوم )?\S+ (\d{1,2}) (.+?) الي (?:يوم )?\S+ (\d{1,2}) (.+?) (\d{4})',
    ).firstMatch(flat);
    if (match == null) {
      return null;
    }
    final startMonth = _months[match.group(2)!.trim()];
    final endMonth = _months[match.group(4)!.trim()];
    final endDay = int.parse(match.group(3)!);
    final year = int.parse(match.group(5)!);
    if (startMonth == null || endMonth == null) {
      return null;
    }

    final endsOn = _saturdayFor(year, endMonth, endDay);
    if (endsOn == null) {
      return null;
    }

    return _Dates(
      start: '${match.group(1)} ${HijriService.monthName(startMonth)}',
      end: '${match.group(3)} ${HijriService.monthName(endMonth)}',
      year: year,
      endsOn: endsOn,
    );
  }

  /// The Gregorian day for the Hijri end date.
  ///
  /// The announcement says the week ends on a Saturday, so the conversion has
  /// to land on one. The Umm al-Qura tables the app uses are Saudi Arabia's
  /// own and normally agree, but a month start can move a day; trying the
  /// neighbours before giving up keeps one such week from being thrown away.
  static DateTime? _saturdayFor(int year, int month, int day) {
    try {
      final base = HijriService.toGregorian(year, month, day);
      for (final shift in const [0, -1, 1]) {
        final candidate = DateTime.utc(base.year, base.month, base.day + shift);
        if (candidate.weekday == DateTime.saturday) {
          return candidate;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }
}

class _Dates {
  const _Dates({
    required this.start,
    required this.end,
    required this.year,
    required this.endsOn,
  });

  final String start;
  final String end;
  final int year;
  final DateTime endsOn;
}
