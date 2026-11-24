import 'tilawa_event.dart';

/// How one word of the passage stands.
///
/// A word is only called [recited] once the engine is both sure of it and well
/// past it; until then it is [tentative]. A word is only [wrong] once the
/// engine has confirmed it. A word the reciter has clearly moved beyond
/// without the engine ever hearing it is [unverified] — not an accusation,
/// just "not heard clearly".
enum WordStatus { pending, tentative, recited, unverified, wrong }

/// The passage on screen, word by word, and what the engine has said about it.
///
/// Pure Dart: feed it [TilawaEvent]s and read [statusAt].
///
/// The rules come from running the engine on real recitations:
///  * positions below [minPositionConfidence], or not locked, are ignored —
///    they are the engine's transient guesses, and trusting them painted
///    skipped words green;
///  * what was recited is the engine's span, not its last-word pointer, which
///    never names the final word of an ayah;
///  * a word turns green only when it is [settleWords] behind the span's end;
///  * only a confirmed mistake turns a word red. Suspected ones are not shown:
///    under noise they flickered and mostly came to nothing.
class PassageProgress {
  PassageProgress({required this.surah, required Map<int, List<String>> words})
    : _keys = [],
      _texts = [] {
    final ayahs = words.keys.toList()..sort();
    _firstAyah = ayahs.first;
    _lastAyah = ayahs.last;
    for (final ayah in ayahs) {
      final list = words[ayah]!;
      for (var i = 0; i < list.length; i++) {
        _keys.add(WordPosition(surah, ayah, i + 1));
        _texts.add(list[i]);
      }
    }
    _status = List.filled(_keys.length, WordStatus.pending);
  }

  /// Positions below this, or not locked, are ignored.
  static const double minPositionConfidence = 0.7;

  /// Confirmed mistakes below this are ignored.
  static const double minMistakeConfidence = 0.75;

  /// A word must be this many words behind the span's end to count as recited.
  static const int settleWords = 2;

  /// Split display text into words, dropping tokens that carry no letters
  /// (stop-mark glyphs and verse numbers sit between words in some texts and
  /// are not words to the engine).
  static List<String> splitWords(String text) => [
    for (final token in text.split(RegExp(r'\s+')))
      if (RegExp(r'[ء-يٱ-ۓ]').hasMatch(token)) token,
  ];

  final int surah;
  final List<WordPosition> _keys;
  final List<String> _texts;
  late final int _firstAyah;
  late final int _lastAyah;
  late final List<WordStatus> _status;
  final Map<String, int> _openMistakes = {};

  int get length => _keys.length;

  WordPosition keyAt(int index) => _keys[index];
  String textAt(int index) => _texts[index];

  /// The furthest word the engine has heard, or -1.
  int get _furthest {
    for (var i = length - 1; i >= 0; i--) {
      if (_status[i] == WordStatus.recited ||
          _status[i] == WordStatus.tentative) {
        return i;
      }
    }
    return -1;
  }

  WordStatus statusAt(int index) {
    final status = _status[index];
    if (status == WordStatus.pending && index <= _furthest - settleWords) {
      return WordStatus.unverified;
    }
    return status;
  }

  /// Words the engine has heard, for the progress bar.
  int get heardCount =>
      _status
          .where((s) => s == WordStatus.recited || s == WordStatus.tentative)
          .length;

  int get wrongCount => _status.where((s) => s == WordStatus.wrong).length;

  /// The word's index, with its ayah and word clamped into the passage; null
  /// when it is in another surah altogether.
  int? _indexOf(WordPosition at) {
    if (at.surah != surah) {
      return null;
    }
    if (at.ayah < _firstAyah) {
      return 0;
    }
    if (at.ayah > _lastAyah) {
      return length - 1;
    }
    // Clamp the word to the ayah, in case the display text splits differently
    // from the engine's reference.
    var last = -1;
    for (var i = 0; i < _keys.length; i++) {
      if (_keys[i].ayah != at.ayah) {
        continue;
      }
      if (_keys[i].word == at.word) {
        return i;
      }
      last = i;
    }
    return last < 0 ? null : last;
  }

  /// Apply one engine event; returns whether anything changed.
  bool apply(TilawaEvent event) {
    switch (event) {
      case TilawaPosition(:final observed?):
        if (event.state != TrackState.locked ||
            event.confidence < minPositionConfidence ||
            _indexOf(observed) == null) {
          return false;
        }
        final end = _indexOf(event.spanEnd ?? observed) ?? _indexOf(observed)!;
        final start =
            event.spanStart == null ? 0 : (_indexOf(event.spanStart!) ?? 0);
        if (end < start) {
          return false;
        }
        var changed = false;
        for (var i = 0; i < length; i++) {
          final current = _status[i];
          if (current == WordStatus.wrong || current == WordStatus.recited) {
            continue;
          }
          final next =
              i >= start && i <= end
                  ? (i <= end - settleWords
                      ? WordStatus.recited
                      : WordStatus.tentative)
                  : WordStatus.pending;
          if (next != current) {
            _status[i] = next;
            changed = true;
          }
        }
        return changed;
      case TilawaChecker():
        final index = _indexOf(event.location);
        if (index == null) {
          return false;
        }
        if (event.state == CheckerState.confirmed &&
            event.confidence >= minMistakeConfidence) {
          _openMistakes[event.id] = index;
          _status[index] = WordStatus.wrong;
          return true;
        }
        if (event.state == CheckerState.resolved) {
          final at = _openMistakes.remove(event.id);
          if (at != null) {
            _status[at] = WordStatus.recited;
            return true;
          }
        }
        return false;
      default:
        return false;
    }
  }
}
