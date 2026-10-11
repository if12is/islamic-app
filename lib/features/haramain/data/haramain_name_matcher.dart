import '../domain/haramain_roster.dart';
import '../domain/haramain_week.dart';

/// Arabic text reduced to what survives the announcement's typos.
///
/// Alef forms and ta marbuta are folded, diacritics and punctuation become
/// spaces, Arabic-Indic digits become Western ones. Used for names, prayer
/// words, month names and section headings alike, so they all agree on what
/// "the same word" means.
String normalizeArabic(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    final ch = String.fromCharCode(unit);
    if (unit >= 0x064B && unit <= 0x065F || unit == 0x0670 || unit == 0x0640) {
      continue; // diacritics and tatweel
    }
    if ('أإآٱ'.contains(ch)) {
      out.write('ا');
    } else if (ch == 'ة') {
      out.write('ه');
    } else if (ch == 'ى') {
      out.write('ي');
    } else if (unit >= 0x0660 && unit <= 0x0669) {
      out.write(unit - 0x0660);
    } else if ((unit >= 0x0621 && unit <= 0x064A) ||
        (unit >= 0x30 && unit <= 0x39)) {
      out.write(ch);
    } else {
      out.write(' ');
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Honorifics the announcement puts in front of a name, normalised. They only
/// ever come first, which matters: «الشيخ» is also the last word of the family
/// name «آل الشيخ», and must survive there.
const Set<String> _honorifics = {
  'فضيله',
  'معالي',
  'سماحه',
  'الشيخ',
  'شيخ',
  'الدكتور',
  'دكتور',
  'د',
  // «أ.د.» arrives as two letters once the dots are gone.
  'ا',
  'الاستاذ',
  'استاذ',
  'بروفيسور',
  'الاستاذه',
};

/// The words of a name with leading honorifics removed.
List<String> nameTokens(String raw) {
  final tokens = normalizeArabic(raw).split(' ').where((t) => t.isNotEmpty);
  final list = tokens.toList();
  var start = 0;
  while (start < list.length && _honorifics.contains(list[start])) {
    start++;
  }
  return list.sublist(start);
}

/// Words that join a given name to its father's or family name.
const Set<String> _linkWords = {'بن', 'ابن'};

/// The comparison form of a name: link words dropped, the definite article
/// removed from each word, everything joined without spaces.
///
/// Joining without spaces is what makes «عبدالرحمنالسديس» (a space lost in the
/// source) equal «عبدالرحمن السديس» without guessing where the gap belonged.
List<String> _keyWords(List<String> tokens) {
  return [
    for (final token in tokens)
      if (!_linkWords.contains(token))
        token.startsWith('ال') && token.length - 2 >= 3
            ? token.substring(2)
            : token,
  ];
}

/// Edit distance counting a swapped pair of neighbours as one slip, which is
/// how «غزواي» for «غزاوي» happens.
int editDistance(String a, String b) {
  if (a == b) {
    return 0;
  }
  final rows = List.generate(
    a.length + 1,
    (_) => List<int>.filled(b.length + 1, 0),
  );
  for (var i = 0; i <= a.length; i++) {
    rows[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    rows[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = [
        rows[i - 1][j] + 1,
        rows[i][j - 1] + 1,
        rows[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final swapped = rows[i - 2][j - 2] + 1;
        if (swapped < best) {
          best = swapped;
        }
      }
      rows[i][j] = best;
    }
  }
  return rows[a.length][b.length];
}

class _Candidate {
  _Candidate(this.imam)
    : words = _keyWords(nameTokens(imam.nameAr)),
      key = _keyWords(nameTokens(imam.nameAr)).join();

  final RosterImam imam;
  final List<String> words;
  final String key;
}

/// Matches a name from the announcement to the roster.
///
/// Three steps, strictest first, and a step only answers when exactly one
/// imam fits — a guess between two people is worse than showing the source's
/// own spelling:
///   1. the same letters once spaces, titles and «بن» are ignored;
///   2. a shorter form of a longer roster name («أحمد الحذيفي» for
///      «أحمد بن علي الحذيفي»), first and last word agreeing;
///   3. a few letters wrong.
class HaramainNameMatcher {
  HaramainNameMatcher([Iterable<RosterImam> roster = haramainRoster])
    : _candidates = [for (final imam in roster) _Candidate(imam)];

  final List<_Candidate> _candidates;

  /// The name without titles and trailing punctuation, spelled as written.
  static String cleanName(String raw) {
    final tokens = nameTokens(raw);
    return tokens.join(' ');
  }

  RosterImam? match(String raw, HaramainMosque mosque) {
    final pool = [
      for (final c in _candidates)
        if (c.imam.mosque == mosque) c,
    ];
    final words = _keyWords(nameTokens(raw));
    if (words.isEmpty) {
      return null;
    }
    final key = words.join();

    final exact = pool.where((c) => c.key == key).toList();
    if (exact.length == 1) {
      return exact.single.imam;
    }

    if (words.length >= 2) {
      final partial =
          pool
              .where(
                (c) =>
                    c.words.length > words.length &&
                    c.words.first == words.first &&
                    c.words.last == words.last &&
                    words.every(c.words.contains),
              )
              .toList();
      if (partial.length == 1) {
        return partial.single.imam;
      }
    }

    // A tolerance that grows with the name: one slip in a short name is a
    // different name, two in a long one is still the same.
    final tolerance = key.length >= 10 ? 2 : 1;
    final scored = [for (final c in pool) (c, editDistance(key, c.key))]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    if (scored.isNotEmpty && scored.first.$2 <= tolerance) {
      final tied = scored.length > 1 && scored[1].$2 == scored.first.$2;
      if (!tied) {
        return scored.first.$1.imam;
      }
    }
    return null;
  }

  /// An [ImamEntry] for the text after the colon on one announcement line.
  ImamEntry entryFor(String rawLineTail, HaramainMosque mosque) {
    final cleaned = cleanName(rawLineTail);
    final matched = match(rawLineTail, mosque);
    return ImamEntry(
      rawName: cleaned,
      displayName: matched?.nameAr ?? cleaned,
      rosterId: matched?.id,
    );
  }
}
