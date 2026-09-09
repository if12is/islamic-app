import 'package:flutter/widgets.dart';

const List<String> _arabicIndic = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

/// Western digits rewritten as Arabic-Indic ones, whatever the locale.
///
/// Separate from [localizeDigits] because the two answer different questions.
/// Search matching needs this one: someone typing ٢ into the surah field is
/// looking for al-Baqarah whichever language the interface happens to be in,
/// so the comparison converts unconditionally. Display needs the other.
String toArabicDigits(String input) {
  var output = input;
  for (var i = 0; i < _arabicIndic.length; i++) {
    output = output.replaceAll('$i', _arabicIndic[i]);
  }
  return output;
}

/// Arabic-Indic digits rewritten as Western ones, whatever the locale.
///
/// The inverse, for parsing back a number the app itself printed.
String toWesternDigits(String input) {
  var output = input;
  for (var i = 0; i < _arabicIndic.length; i++) {
    output = output.replaceAll(_arabicIndic[i], '$i');
  }
  return output;
}

/// Numbers written the way the reader's own language writes them.
///
/// Six screens had grown their own private copy of this — `_digits`,
/// `_localizeDigits`, `_toArabicDigits`, `_formatNumber`, `_localizedNumber`,
/// and one more `_digits` — which is six chances to forget one. Several had
/// been forgotten: the daily wird counted "0/31" in an Arabic interface, and
/// so did the adhkar due now.
String localizeDigits(BuildContext context, String input) =>
    localizeDigitsFor(Localizations.localeOf(context).languageCode, input);

/// The same, for code with no widget to ask.
///
/// The notification scheduler composes its text headless, hours before anyone
/// opens the app, so it carries the language code rather than a context.
String localizeDigitsFor(String languageCode, String input) =>
    languageCode == 'ar' ? toArabicDigits(input) : input;
