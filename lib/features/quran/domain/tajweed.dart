/// Tajweed rules worked out from the Mushaf text itself.
///
/// There is no tajweed-marked copy of the Qur'an in this app and no network
/// call behind this: the rules below are derived from the rasm, which carries
/// everything they need — sukoon is written, shadda is written, tanween is
/// written. That means colouring works for all 6236 verses offline, and it
/// means the engine can be tested against verses whose ruling is not in doubt.
///
/// What it deliberately does **not** do: anything that depends on where the
/// reader stops. Madd ʿarid li-s-sukoon is two, four or six counts depending on
/// the pause, and the app does not know where you will pause. Colouring it
/// would be inventing a ruling. The screen says so rather than leaving the
/// reader to assume the colouring is exhaustive.
library;

/// A rule the reader can see on the page.
enum TajweedRule {
  /// نّ or مّ — two counts of ghunnah, wherever they fall.
  ghunnah,

  /// نْ or tanween before ي ن م و.
  idghamGhunnah,

  /// نْ or tanween before ل ر — merged with no ghunnah.
  idghamNoGhunnah,

  /// نْ or tanween before ب — pronounced as a meem.
  iqlab,

  /// نْ or tanween before the remaining fifteen letters.
  ikhfa,

  /// مْ before ب.
  ikhfaShafawi,

  /// مْ before م.
  idghamShafawi,

  /// ق ط ب ج د carrying sukoon, or ending a verse.
  qalqalah,

  /// A madd letter followed by hamza in the same word — four or five counts.
  maddMuttasil,

  /// A madd letter ending a word whose next word opens with hamza.
  maddMunfasil,

  /// A madd letter followed by a shadda or a sukoon — six counts.
  maddLazim,

  /// The lam of ال that is written but not pronounced.
  silent,
}

extension TajweedRuleInfo on TajweedRule {
  /// Localization key for the rule's name.
  String get labelKey => 'tajweed_$name';

  /// Localization key for the one line explaining it.
  String get descriptionKey => 'tajweed_${name}_desc';

  /// How many counts it is held, where that is fixed. Null where it is not.
  String? get lengthAr => switch (this) {
    TajweedRule.ghunnah => 'حركتان',
    TajweedRule.idghamGhunnah => 'حركتان',
    TajweedRule.ikhfa => 'حركتان',
    TajweedRule.ikhfaShafawi => 'حركتان',
    TajweedRule.iqlab => 'حركتان',
    TajweedRule.maddMuttasil => '٤–٥ حركات',
    TajweedRule.maddMunfasil => '٤–٥ حركات',
    TajweedRule.maddLazim => '٦ حركات',
    _ => null,
  };
}

/// A run of characters carrying one rule.
class TajweedSpan {
  const TajweedSpan({
    required this.start,
    required this.end,
    required this.rule,
  });

  /// Indices into the original string; [end] is exclusive.
  final int start;
  final int end;

  final TajweedRule rule;

  bool get isEmpty => end <= start;

  @override
  String toString() => '$rule($start–$end)';
}

/// One letter of the text with the marks written on it.
class _Unit {
  _Unit({required this.letter, required this.start, required this.wordIndex});

  /// The base letter's code point.
  final int letter;

  /// Where the letter sits in the source string.
  final int start;

  /// Where the letter and its marks end, exclusive.
  int end = 0;

  /// The word this letter belongs to; two letters in different words cannot
  /// be merged, and that distinction decides several rules.
  final int wordIndex;

  final Set<int> marks = {};

  bool get hasSukoon => marks.contains(Tajweed.sukoon);
  bool get hasShadda => marks.contains(Tajweed.shadda);
  bool get hasFatha => marks.contains(Tajweed.fatha);
  bool get hasDamma => marks.contains(Tajweed.damma);
  bool get hasKasra => marks.contains(Tajweed.kasra);
  bool get hasDaggerAlif => marks.contains(Tajweed.daggerAlif);

  bool get hasTanween =>
      marks.contains(Tajweed.fathatan) ||
      marks.contains(Tajweed.dammatan) ||
      marks.contains(Tajweed.kasratan);

  /// A letter with no vowel written on it at all — how the Mushaf writes the
  /// long vowels ا و ي when they are madd letters.
  bool get isBare =>
      !hasSukoon &&
      !hasShadda &&
      !hasFatha &&
      !hasDamma &&
      !hasKasra &&
      !hasTanween;
}

/// The engine.
class Tajweed {
  Tajweed._();

  // Marks.
  static const int fathatan = 0x064B;
  static const int dammatan = 0x064C;
  static const int kasratan = 0x064D;
  static const int fatha = 0x064E;
  static const int damma = 0x064F;
  static const int kasra = 0x0650;
  static const int shadda = 0x0651;
  static const int sukoon = 0x0652;
  static const int maddah = 0x0653;
  static const int daggerAlif = 0x0670;
  static const int tatweel = 0x0640;

  // Letters this engine names.
  static const int alif = 0x0627;
  static const int waw = 0x0648;
  static const int ya = 0x064A;
  static const int alifMaqsura = 0x0649;
  static const int noon = 0x0646;
  static const int meem = 0x0645;
  static const int lam = 0x0644;
  static const int ba = 0x0628;
  static const int hamza = 0x0621;
  static const int alifHamzaAbove = 0x0623;
  static const int alifHamzaBelow = 0x0625;
  static const int alifMadda = 0x0622;
  static const int wawHamza = 0x0624;
  static const int yaHamza = 0x0626;
  static const int alifWasla = 0x0671;

  /// نْ / tanween before any of these is pronounced clearly.
  ///
  /// The six letters of the throat. Every written form of hamza belongs here,
  /// not only the bare ء: أ إ آ ؤ ئ are the same letter wearing a seat, and a
  /// table that lists only ء quietly turns every `مِنْ أَ` into ikhfa.
  static const Set<int> izharLetters = {
    0x0621, // ء
    0x0623, // أ
    0x0624, // ؤ
    0x0625, // إ
    0x0626, // ئ
    0x0622, // آ
    0x0647, // ه
    0x0639, // ع
    0x062D, // ح
    0x063A, // غ
    0x062E, // خ
  };

  /// Merged, with ghunnah — the letters of يرملون minus ل and ر.
  static const Set<int> idghamGhunnahLetters = {ya, noon, meem, waw};

  /// Merged, without ghunnah.
  static const Set<int> idghamNoGhunnahLetters = {lam, 0x0631};

  /// The five letters of قطب جد.
  static const Set<int> qalqalahLetters = {
    0x0642, // ق
    0x0637, // ط
    0x0628, // ب
    0x062C, // ج
    0x062F, // د
  };

  /// Letters that begin a word with a hamza sound.
  static const Set<int> hamzaLetters = {
    hamza,
    alifHamzaAbove,
    alifHamzaBelow,
    alifMadda,
    wawHamza,
    yaHamza,
  };

  /// The fourteen sun letters: ال before one of these has a silent lam.
  static const Set<int> sunLetters = {
    0x062A, // ت
    0x062B, // ث
    0x062F, // د
    0x0630, // ذ
    0x0631, // ر
    0x0632, // ز
    0x0633, // س
    0x0634, // ش
    0x0635, // ص
    0x0636, // ض
    0x0637, // ط
    0x0638, // ظ
    0x0644, // ل
    0x0646, // ن
  };

  static bool isMark(int rune) =>
      (rune >= 0x064B && rune <= 0x065F) ||
      rune == daggerAlif ||
      rune == 0x0653 ||
      (rune >= 0x06D6 && rune <= 0x06ED);

  static bool isLetter(int rune) =>
      (rune >= 0x0621 && rune <= 0x063A) ||
      (rune >= 0x0641 && rune <= 0x064A) ||
      (rune >= 0x0671 && rune <= 0x06D3);

  /// Every rule the engine can find in [text], in reading order.
  ///
  /// Spans never overlap: where two rules would touch the same letters the
  /// more specific one wins, because two colours on one letter is not a
  /// teaching aid, it is a smear.
  ///
  /// [endsAtStop] says whether the text runs to a place the reader may stop.
  /// A whole verse does — the end of an ayah is always a permissible pause —
  /// and that is what makes its final letter sakin, which is the whole of
  /// qalqalah kubra. Pass false for a fragment cut out of the middle of one,
  /// or the cut itself is mistaken for a stop.
  static List<TajweedSpan> analyse(String text, {bool endsAtStop = true}) {
    final units = _parse(text);
    if (units.isEmpty) {
      return const [];
    }

    final spans = <TajweedSpan>[];
    _findGhunnah(units, spans);
    _findNoonRules(units, spans, text);
    _findMeemRules(units, spans, text);
    _findMadd(units, spans);
    _findQalqalah(units, spans, endsAtStop);
    _findSilentLam(units, spans);

    spans.sort((a, b) => a.start.compareTo(b.start));
    return _dropOverlaps(spans);
  }

  /// Split the string into letters carrying their marks.
  static List<_Unit> _parse(String text) {
    final units = <_Unit>[];
    var wordIndex = 0;
    _Unit? current;

    final runes = text.runes.toList();
    var offset = 0;

    for (final rune in runes) {
      final width = String.fromCharCode(rune).length;

      if (isMark(rune)) {
        current?.marks.add(rune);
        current?.end = offset + width;
      } else if (rune == tatweel) {
        current?.end = offset + width;
      } else if (isLetter(rune)) {
        current = _Unit(letter: rune, start: offset, wordIndex: wordIndex)
          ..end = offset + width;
        units.add(current);
      } else {
        // A space or anything else ends the word.
        if (rune == 0x20) {
          wordIndex++;
        }
        current = null;
      }

      offset += width;
    }

    return units;
  }

  /// نّ and مّ — ghunnah for two counts wherever they appear.
  static void _findGhunnah(List<_Unit> units, List<TajweedSpan> spans) {
    for (final unit in units) {
      if ((unit.letter == noon || unit.letter == meem) && unit.hasShadda) {
        spans.add(
          TajweedSpan(
            start: unit.start,
            end: unit.end,
            rule: TajweedRule.ghunnah,
          ),
        );
      }
    }
  }

  /// The next letter that is actually pronounced.
  ///
  /// Three written letters are silent and must not be read as the following
  /// letter, or every ruling that depends on what comes next is wrong:
  ///  * the alif that carries fathatan — `أَزْوَاجًا لِ` is tanween then lam,
  ///    not tanween then alif;
  ///  * the alif that closes a plural verb — `لِتَسْكُنُوا إِ`;
  ///  * the hamzat wasl that opens a word — `الْحَمْدُ`, elided when joined.
  static int? _nextSounded(List<_Unit> units, int from) {
    for (var i = from + 1; i < units.length; i++) {
      if (_isSilentAlif(units, i)) {
        continue;
      }
      return i;
    }
    return null;
  }

  static bool _isSilentAlif(List<_Unit> units, int index) {
    final unit = units[index];
    if (unit.letter != alif && unit.letter != alifWasla) {
      return false;
    }
    if (unit.letter == alifWasla) {
      return true;
    }
    if (!unit.isBare) {
      return false;
    }

    final previous = index > 0 ? units[index - 1] : null;
    final sameWord = previous != null && previous.wordIndex == unit.wordIndex;

    // Word-initial and bare: hamzat wasl.
    if (!sameWord) {
      return true;
    }
    // The alif written after fathatan, and the one closing a plural verb.
    if (previous.marks.contains(fathatan)) {
      return true;
    }
    if (previous.letter == waw && _isLastOfWord(units, index)) {
      return true;
    }
    // The definite article behind a joined prefix — وَالْأَرْض, فَالَّذِينَ,
    // بِالْحَقِّ. Its alif is written but elided, and without this it looks
    // exactly like a madd letter sitting before a sukoon, which turns every
    // such word into a six-count madd.
    return _startsDefiniteArticle(units, index);
  }

  /// Whether the alif at [index] opens ال — the lam either carries a sukoon or
  /// is followed by a doubled sun letter.
  static bool _startsDefiniteArticle(List<_Unit> units, int index) {
    final unit = units[index];
    final l = index + 1 < units.length ? units[index + 1] : null;
    if (l == null || l.letter != lam || l.wordIndex != unit.wordIndex) {
      return false;
    }
    if (l.hasSukoon) {
      return true;
    }
    final after = index + 2 < units.length ? units[index + 2] : null;
    return after != null &&
        after.wordIndex == unit.wordIndex &&
        after.hasShadda &&
        sunLetters.contains(after.letter);
  }

  /// Whether the gap between two letters is nothing but spaces.
  static bool _onlySpacesBetween(String text, int from, int to) {
    if (to <= from) {
      return true;
    }
    for (var i = from; i < to; i++) {
      if (text[i] != ' ') {
        return false;
      }
    }
    return true;
  }

  /// The four rulings of نْ and tanween.
  static void _findNoonRules(
    List<_Unit> units,
    List<TajweedSpan> spans,
    String text,
  ) {
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];

      // A noon carrying shadda is ghunnah, already handled.
      final isNoonSakinah =
          unit.letter == noon && unit.hasSukoon && !unit.hasShadda;
      if (!isNoonSakinah && !unit.hasTanween) {
        continue;
      }

      final nextIndex = _nextSounded(units, i);
      final next = nextIndex == null ? null : units[nextIndex];
      if (next == null) {
        continue;
      }

      // إظهار مطلق: within one word, نْ before و or ي is pronounced clearly —
      // the four words دنيا، بنيان، صنوان، قنوان. Treating them as idgham
      // would be a plain mistake, and it is the one exception a rule table
      // always forgets.
      final sameWord = next.wordIndex == unit.wordIndex;
      if (isNoonSakinah &&
          sameWord &&
          (next.letter == waw || next.letter == ya)) {
        continue;
      }

      final rule = ruleAfterNoon(next.letter);
      if (rule == null) {
        // إظهار: nothing changes, so nothing is coloured. A colour for "read
        // it as written" teaches nothing.
        continue;
      }

      // The span covers the noon (or the tanween's letter) and, for idgham,
      // the letter the sound merges into — but only when nothing but spaces
      // lies between them. A pause mark inside a coloured run reads as though
      // the mark itself were part of the rule.
      final joins =
          rule == TajweedRule.idghamGhunnah ||
          rule == TajweedRule.idghamNoGhunnah;
      spans.add(
        TajweedSpan(
          start: unit.start,
          end:
              joins && _onlySpacesBetween(text, unit.end, next.start)
                  ? next.end
                  : unit.end,
          rule: rule,
        ),
      );
    }
  }

  /// What نْ or tanween does before [following]. Null means izhar.
  static TajweedRule? ruleAfterNoon(int following) {
    if (izharLetters.contains(following)) {
      return null;
    }
    if (following == ba) {
      return TajweedRule.iqlab;
    }
    if (idghamGhunnahLetters.contains(following)) {
      return TajweedRule.idghamGhunnah;
    }
    if (idghamNoGhunnahLetters.contains(following)) {
      return TajweedRule.idghamNoGhunnah;
    }
    return TajweedRule.ikhfa;
  }

  /// The two rulings of مْ that change the sound.
  static void _findMeemRules(
    List<_Unit> units,
    List<TajweedSpan> spans,
    String text,
  ) {
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit.letter != meem || !unit.hasSukoon || unit.hasShadda) {
        continue;
      }
      final nextIndex = _nextSounded(units, i);
      final next = nextIndex == null ? null : units[nextIndex];
      if (next == null) {
        continue;
      }

      if (next.letter == ba) {
        spans.add(
          TajweedSpan(
            start: unit.start,
            end: unit.end,
            rule: TajweedRule.ikhfaShafawi,
          ),
        );
      } else if (next.letter == meem) {
        spans.add(
          TajweedSpan(
            start: unit.start,
            end:
                _onlySpacesBetween(text, unit.end, next.start)
                    ? next.end
                    : unit.end,
            rule: TajweedRule.idghamShafawi,
          ),
        );
      }
      // Everything else is izhar shafawi — read as written, so uncoloured.
    }
  }

  /// ق ط ب ج د with a sukoon, and at the end of a verse where the reader stops.
  static void _findQalqalah(
    List<_Unit> units,
    List<TajweedSpan> spans,
    bool endsAtStop,
  ) {
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (!qalqalahLetters.contains(unit.letter)) {
        continue;
      }

      // Qalqalah sughra is written: the letter carries a sukoon. Qalqalah
      // kubra is not written at all — it happens because the reader stops, and
      // the end of a verse is always a place one may stop, so the last letter
      // is sakin there whatever comes next.
      final isLast = endsAtStop && i == units.length - 1;
      if (unit.hasSukoon || isLast) {
        spans.add(
          TajweedSpan(
            start: unit.start,
            end: unit.end,
            rule: TajweedRule.qalqalah,
          ),
        );
      }
    }
  }

  /// The three madds whose length is fixed by the writing.
  static void _findMadd(List<_Unit> units, List<TajweedSpan> spans) {
    for (var i = 0; i < units.length; i++) {
      if (!_isMaddLetter(units, i)) {
        continue;
      }

      final unit = units[i];
      final nextIndex = _nextSounded(units, i);
      final next = nextIndex == null ? null : units[nextIndex];
      if (next == null) {
        continue;
      }

      if (next.wordIndex == unit.wordIndex) {
        if (hamzaLetters.contains(next.letter)) {
          spans.add(
            TajweedSpan(
              start: unit.start,
              end: next.end,
              rule: TajweedRule.maddMuttasil,
            ),
          );
          continue;
        }
        // A shadda or a written sukoon straight after a madd letter is the
        // six-count madd: الضَّالِّينَ, الْحَاقَّةُ.
        if (next.hasShadda || next.hasSukoon) {
          spans.add(
            TajweedSpan(
              start: unit.start,
              end: next.end,
              rule: TajweedRule.maddLazim,
            ),
          );
        }
        continue;
      }

      // Across a word boundary, only a hamza opening the next word lengthens
      // it. Anything else is the natural two counts, left uncoloured.
      if (hamzaLetters.contains(next.letter)) {
        spans.add(
          TajweedSpan(
            start: unit.start,
            end: unit.end,
            rule: TajweedRule.maddMunfasil,
          ),
        );
      }
    }
  }

  static bool _isLastOfWord(List<_Unit> units, int index) =>
      index == units.length - 1 ||
      units[index + 1].wordIndex != units[index].wordIndex;

  /// Whether the letter at [index] is a long vowel rather than a consonant.
  ///
  /// The Mushaf writes them bare: an alif with nothing on it after a fatha, a
  /// waw with nothing on it after a damma, a ya with nothing on it after a
  /// kasra.
  ///
  /// The vowel it lengthens must be **in the same word**. Without that check a
  /// word opening with hamzat wasl — `الَّذِينَ` after `صِرَاطَ` — looks like an
  /// alif after a fatha, and every `ال` in the Mushaf is mis-coloured as a
  /// six-count madd.
  static bool _isMaddLetter(List<_Unit> units, int index) {
    final unit = units[index];
    if (!unit.isBare) {
      return false;
    }

    final previous = index > 0 ? units[index - 1] : null;
    if (previous == null || previous.wordIndex != unit.wordIndex) {
      return false;
    }

    if (unit.letter == alif) {
      // The silent alif that closes a plural verb — قَالُوا — is not a madd,
      // and neither is the one written after fathatan.
      if (_isSilentAlif(units, index)) {
        return false;
      }
      return previous.hasFatha;
    }
    if (unit.letter == waw) {
      return previous.hasDamma;
    }
    if (unit.letter == ya || unit.letter == alifMaqsura) {
      return previous.hasKasra;
    }
    return false;
  }

  /// The lam of ال that is written but never pronounced.
  ///
  /// Sun letter: the lam is written, the next letter doubles, the lam is not
  /// said. Moon letter: the lam carries a sukoon and is pronounced, so there
  /// is nothing to mark. The article is found wherever it sits, including
  /// behind a joined و or ف or ب.
  static void _findSilentLam(List<_Unit> units, List<TajweedSpan> spans) {
    for (var i = 0; i + 2 < units.length; i++) {
      final unit = units[i];
      if (unit.letter != alif && unit.letter != alifWasla) {
        continue;
      }
      if (!_startsDefiniteArticle(units, i)) {
        continue;
      }

      final l = units[i + 1];
      final after = units[i + 2];
      if (sunLetters.contains(after.letter) && after.hasShadda) {
        spans.add(
          TajweedSpan(start: l.start, end: l.end, rule: TajweedRule.silent),
        );
      }
    }
  }

  /// Keep the first span of any overlapping pair, by priority then position.
  static List<TajweedSpan> _dropOverlaps(List<TajweedSpan> spans) {
    const priority = {
      TajweedRule.maddLazim: 0,
      TajweedRule.maddMuttasil: 1,
      TajweedRule.maddMunfasil: 2,
      TajweedRule.idghamGhunnah: 3,
      TajweedRule.idghamNoGhunnah: 3,
      TajweedRule.iqlab: 3,
      TajweedRule.ikhfa: 3,
      TajweedRule.idghamShafawi: 4,
      TajweedRule.ikhfaShafawi: 4,
      TajweedRule.ghunnah: 5,
      TajweedRule.qalqalah: 6,
      TajweedRule.silent: 7,
    };

    final ordered = [...spans]..sort((a, b) {
      final byPriority = (priority[a.rule] ?? 9).compareTo(
        priority[b.rule] ?? 9,
      );
      return byPriority != 0 ? byPriority : a.start.compareTo(b.start);
    });

    final kept = <TajweedSpan>[];
    for (final span in ordered) {
      final clashes = kept.any(
        (other) => span.start < other.end && other.start < span.end,
      );
      if (!clashes) {
        kept.add(span);
      }
    }

    kept.sort((a, b) => a.start.compareTo(b.start));
    return kept;
  }
}
