import 'dart:convert';

/// A word in the Mushaf, as the listening engine names it. [word] is 1-based
/// within the ayah.
class WordPosition {
  const WordPosition(this.surah, this.ayah, this.word);

  final int surah;
  final int ayah;
  final int word;

  static WordPosition? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final s = json['s'];
    final a = json['a'];
    final w = json['w'];
    if (s is! num || a is! num || w is! num) {
      return null;
    }
    return WordPosition(s.toInt(), a.toInt(), w.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is WordPosition &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.word == word;

  @override
  int get hashCode => Object.hash(surah, ayah, word);

  @override
  String toString() => '$surah:$ayah:$word';
}

/// What kind of slip the engine found.
enum MistakeKind { wrongWord, omittedWord, addedWord, skippedPassage }

MistakeKind? mistakeKindFrom(String? name) => switch (name) {
  'wrong_word' => MistakeKind.wrongWord,
  'omitted_word' => MistakeKind.omittedWord,
  'added_word' => MistakeKind.addedWord,
  'skipped_passage' => MistakeKind.skippedPassage,
  _ => null,
};

/// Where the engine thinks it is: still searching, sure, torn between two
/// places, or has lost the reciter.
enum TrackState { acquiring, locked, ambiguous, lost }

/// Life of one suspected slip. It is [suspected] first, then settles.
enum CheckerState { suspected, confirmed, resolved, uncertain }

/// A message from the listening engine running in the WebView.
sealed class TilawaEvent {
  const TilawaEvent();

  /// Decode one channel message; null for anything unrecognised, which is
  /// ignored rather than treated as an error.
  static TilawaEvent? parse(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) {
      return null;
    }
    switch (json['t']) {
      case 'booted':
        return const TilawaBooted();
      case 'progress':
        return TilawaProgress(
          stage: '${json['stage']}',
          fraction: (json['fraction'] as num?)?.toDouble() ?? 0,
          fromCache: json['fromCache'] == true,
        );
      case 'ready':
        return TilawaReady('${json['tier']}');
      case 'listening':
        return const TilawaListening();
      case 'level':
        return TilawaLevel((json['db'] as num?)?.toDouble() ?? -90);
      case 'position':
        final observed = json['observed'];
        final top =
            observed is List && observed.isNotEmpty && observed.first is Map
                ? observed.first as Map
                : null;
        final span = top?['span'];
        return TilawaPosition(
          spanStart: span is Map ? WordPosition.fromJson(span['start']) : null,
          spanEnd: span is Map ? WordPosition.fromJson(span['end']) : null,
          state: switch (json['state']) {
            'locked' => TrackState.locked,
            'ambiguous' => TrackState.ambiguous,
            'lost' => TrackState.lost,
            _ => TrackState.acquiring,
          },
          expected: WordPosition.fromJson(json['expected']),
          observed: top == null ? null : WordPosition.fromJson(top['word']),
          confidence: (top?['confidence'] as num?)?.toDouble() ?? 0,
        );
      case 'checker':
        final kind = mistakeKindFrom(json['errorClass'] as String?);
        final location = WordPosition.fromJson(json['location']);
        if (kind == null || location == null) {
          return null;
        }
        return TilawaChecker(
          id: '${json['id']}',
          state: switch (json['state']) {
            'confirmed' => CheckerState.confirmed,
            'resolved' => CheckerState.resolved,
            'uncertain' => CheckerState.uncertain,
            _ => CheckerState.suspected,
          },
          kind: kind,
          location: location,
          confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        );
      case 'done':
        final list = json['mistakes'];
        return TilawaDone([
          if (list is List)
            for (final item in list)
              if (item is Map)
                if (mistakeKindFrom(item['errorClass'] as String?)
                    case final kind?)
                  if (WordPosition.fromJson(item['location']) case final at?)
                    TilawaMistake(kind, at),
        ]);
      case 'error':
        return TilawaFailure(
          stage: '${json['stage']}',
          name: '${json['name']}',
          message: '${json['message']}',
        );
    }
    return null;
  }
}

class TilawaBooted extends TilawaEvent {
  const TilawaBooted();
}

/// Model download / warm-up. [fraction] is 0..1 within [stage].
class TilawaProgress extends TilawaEvent {
  const TilawaProgress({
    required this.stage,
    required this.fraction,
    required this.fromCache,
  });

  final String stage;
  final double fraction;
  final bool fromCache;
}

class TilawaReady extends TilawaEvent {
  const TilawaReady(this.tier);

  final String tier;
}

class TilawaListening extends TilawaEvent {
  const TilawaListening();
}

class TilawaLevel extends TilawaEvent {
  const TilawaLevel(this.db);

  final double db;
}

class TilawaPosition extends TilawaEvent {
  const TilawaPosition({
    required this.state,
    required this.expected,
    required this.observed,
    required this.confidence,
    this.spanStart,
    this.spanEnd,
  });

  final TrackState state;

  /// The words the engine currently believes were recited, first to last. It
  /// is cumulative, and it jumps forward when something was skipped.
  final WordPosition? spanStart;
  final WordPosition? spanEnd;

  /// Where a memorisation session expects the reciter to be.
  final WordPosition? expected;

  /// The most recent word the reciter actually said.
  final WordPosition? observed;
  final double confidence;
}

class TilawaChecker extends TilawaEvent {
  const TilawaChecker({
    required this.id,
    required this.state,
    required this.kind,
    required this.location,
    this.confidence = 0,
  });

  final String id;
  final CheckerState state;
  final MistakeKind kind;
  final WordPosition location;
  final double confidence;
}

class TilawaMistake {
  const TilawaMistake(this.kind, this.location);

  final MistakeKind kind;
  final WordPosition location;
}

/// The session ended; these are the confirmed slips.
class TilawaDone extends TilawaEvent {
  const TilawaDone(this.mistakes);

  final List<TilawaMistake> mistakes;
}

class TilawaFailure extends TilawaEvent {
  const TilawaFailure({
    required this.stage,
    required this.name,
    required this.message,
  });

  /// `load`, `microphone` or `stop`.
  final String stage;

  /// The JavaScript error class, e.g. `MicrophoneError`, `TilawaLoadError`.
  final String name;
  final String message;
}
