import 'tilawa_event.dart';

/// How one word of the passage stands.
enum WordStatus { pending, recited, wrong }

/// The passage on screen, word by word, and what the engine has said about it.
///
/// Pure Dart: feed it [TilawaEvent]s and read [statuses].
class PassageProgress {
  PassageProgress({required this.surah, required Map<int, List<String>> words})
    : _keys = [],
      _texts = [] {
    final ayahs = words.keys.toList()..sort();
    for (final ayah in ayahs) {
      final list = words[ayah]!;
      for (var i = 0; i < list.length; i++) {
        _keys.add(WordPosition(surah, ayah, i + 1));
        _texts.add(list[i]);
      }
    }
    _status = List.filled(_keys.length, WordStatus.pending);
  }

  /// Split ayah text into display words, dropping tokens that carry no
  /// letters (stop-mark glyphs and verse numbers sit between words in some
  /// texts and are not words to the engine).
  static List<String> splitWords(String text) => [
    for (final token in text.split(RegExp(r'\s+')))
      if (RegExp(r'[ء-يٱ-ۓ]').hasMatch(token)) token,
  ];

  final int surah;
  final List<WordPosition> _keys;
  final List<String> _texts;
  late final List<WordStatus> _status;
  int _reached = 0;
  final Map<String, int> _openMistakes = {};

  int get length => _keys.length;

  /// Words up to and including the furthest one heard.
  int get reached => _reached;

  WordPosition keyAt(int index) => _keys[index];
  String textAt(int index) => _texts[index];
  WordStatus statusAt(int index) => _status[index];

  int get wrongCount => _status.where((s) => s == WordStatus.wrong).length;

  int indexOf(WordPosition at) {
    if (at.surah != surah) {
      return -1;
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
    return last;
  }

  /// Apply one engine event; returns whether anything changed.
  bool apply(TilawaEvent event) {
    switch (event) {
      case TilawaPosition(:final observed?):
        final index = indexOf(observed);
        if (index < 0 || index + 1 <= _reached) {
          return false;
        }
        for (var i = _reached; i <= index; i++) {
          if (_status[i] == WordStatus.pending) {
            _status[i] = WordStatus.recited;
          }
        }
        _reached = index + 1;
        return true;
      case TilawaChecker():
        final index = indexOf(event.location);
        if (index < 0) {
          return false;
        }
        if (event.state == CheckerState.confirmed) {
          _openMistakes[event.id] = index;
          _status[index] = WordStatus.wrong;
          return true;
        }
        if (event.state == CheckerState.resolved) {
          final at = _openMistakes.remove(event.id);
          if (at != null) {
            _status[at] =
                at < _reached ? WordStatus.recited : WordStatus.pending;
            return true;
          }
        }
        return false;
      default:
        return false;
    }
  }
}
