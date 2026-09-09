import 'package:flutter/widgets.dart';

import '../localization/app_localizations.dart';
import 'arabic_numerals.dart';

/// A counted quantity and the word for what it counts.
///
/// Kept apart so a gauge can set the number large and the word small — which
/// is the only way a duration in words stays big enough to read. Written as
/// one string, "ساعتان و٥٩ دقيقة" has to shrink to about a third of the size
/// the digits alone would take, and ends up smaller than the caption under it.
///
/// [value] is null where the word already carries the count: Arabic's dual
/// needs no numeral, and "ساعتان" is complete on its own.
class DurationPart {
  const DurationPart({required this.unit, this.value});

  final String? value;
  final String unit;
}

/// How long is left, split into its counted parts.
///
/// This used to come out as "2:59" whenever more than an hour was left — the
/// exact shape of a time of day, sitting among three real times of day. People
/// read it as five to three. Only the under-an-hour case ever carried a unit,
/// so the bug was invisible for most of the hour before every prayer and
/// appeared for the two hours before it.
///
/// Arabic counts in four forms, and getting them wrong is the difference
/// between an app that speaks and an app that fills in a template: one is
/// ساعة, two is ساعتان with no numeral at all, three to ten take the plural
/// ساعات, and eleven up go back to the singular. Prayer gaps never exceed a
/// handful of hours, so all four forms show up in a single day.
///
/// Comes back empty when nothing is left; the caller decides what to say at
/// the moment itself.
List<DurationPart> remainingParts(BuildContext context, Duration duration) {
  if (duration.isNegative) {
    return const [];
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  DurationPart hourPart() =>
      isArabic
          ? _arabicPart(
            context,
            hours,
            one: 'hour_one',
            two: 'hour_two',
            few: 'hour_few',
            many: 'hour_many',
          )
          : DurationPart(value: '$hours', unit: context.tr('hour_short'));

  DurationPart minutePart() =>
      isArabic
          ? _arabicPart(
            context,
            minutes,
            one: 'minute_one',
            two: 'minute_two',
            few: 'minute_few',
            many: 'minute_many',
          )
          : DurationPart(value: '$minutes', unit: context.tr('minute_short'));

  return [
    if (hours > 0) hourPart(),
    if (minutes > 0 || hours == 0) minutePart(),
  ];
}

/// The same countdown as one line of text, for a screen reader and for
/// anywhere a single string is what is wanted.
String remainingInWords(BuildContext context, Duration duration) {
  final parts = remainingParts(context, duration);
  if (parts.isEmpty) {
    return '';
  }

  String render(DurationPart part) =>
      part.value == null ? part.unit : '${part.value} ${part.unit}';

  if (parts.length == 1) {
    return render(parts.first);
  }

  // "ساعتان و٥٩ دقيقة" — the conjunction is written joined to the word after
  // it, so it belongs to that word rather than to the separator.
  return Localizations.localeOf(context).languageCode == 'ar'
      ? '${render(parts.first)} و${render(parts.last)}'
      : '${render(parts.first)} ${render(parts.last)}';
}

/// One counted noun in the form Arabic asks for at this number.
DurationPart _arabicPart(
  BuildContext context,
  int count, {
  required String one,
  required String two,
  required String few,
  required String many,
}) {
  if (count == 1) {
    return DurationPart(unit: context.tr(one));
  }
  if (count == 2) {
    return DurationPart(unit: context.tr(two));
  }
  // Three to ten take the plural of paucity. Zero is not in that band and
  // reads as the singular — "٠ دقيقة", the way a clock at the adhan does.
  final plural = count >= 3 && count <= 10 ? few : many;
  return DurationPart(
    value: localizeDigits(context, '$count'),
    unit: context.tr(plural),
  );
}
