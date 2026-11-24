import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/domain/entities/passage_progress.dart';
import 'package:islamic_app/features/quran/domain/entities/tilawa_event.dart';

Map<String, int> _w(String at) {
  final p = at.split(':').map(int.parse).toList();
  return {'s': 1, 'a': p[0], 'w': p[1]};
}

String _position(
  int ayah,
  int word, {
  String state = 'locked',
  double conf = 0.9,
  String spanStart = '1:1',
}) => jsonEncode({
  't': 'position',
  'state': state,
  'expected': null,
  'observed': [
    {
      'word': {'s': 1, 'a': ayah, 'w': word},
      'span': {
        'start': _w(spanStart),
        'end': {'s': 1, 'a': ayah, 'w': word},
      },
      'confidence': conf,
    },
  ],
});

String _checker(
  String id,
  String state,
  int ayah,
  int word, {
  double conf = 0.8,
}) => jsonEncode({
  't': 'checker',
  'id': id,
  'state': state,
  'errorClass': 'wrong_word',
  'location': {'s': 1, 'a': ayah, 'w': word},
  'confidence': conf,
});

PassageProgress _passage() => PassageProgress(
  surah: 1,
  words: {
    1: ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ'],
    2: ['ٱلْحَمْدُ', 'لِلَّهِ', 'رَبِّ', 'ٱلْعَٰلَمِينَ'],
  },
);

void main() {
  group('TilawaEvent.parse', () {
    test('reads a position with its best candidate', () {
      final event = TilawaEvent.parse(_position(2, 3)) as TilawaPosition;
      expect(event.state, TrackState.locked);
      expect(event.observed, const WordPosition(1, 2, 3));
      expect(event.confidence, closeTo(0.9, 1e-9));
    });

    test('reads the four slip kinds and the checker states', () {
      for (final (name, kind) in [
        ('wrong_word', MistakeKind.wrongWord),
        ('omitted_word', MistakeKind.omittedWord),
        ('added_word', MistakeKind.addedWord),
        ('skipped_passage', MistakeKind.skippedPassage),
      ]) {
        final raw = jsonEncode({
          't': 'checker',
          'id': 'x',
          'state': 'confirmed',
          'errorClass': name,
          'location': {'s': 1, 'a': 1, 'w': 1},
        });
        final event = TilawaEvent.parse(raw) as TilawaChecker;
        expect(event.kind, kind);
        expect(event.state, CheckerState.confirmed);
      }
    });

    test('collects the confirmed slips when the session ends', () {
      final raw = jsonEncode({
        't': 'done',
        'mistakes': [
          {
            'id': 'a',
            'errorClass': 'omitted_word',
            'location': {'s': 2, 'a': 5, 'w': 2},
          },
          {'id': 'b', 'errorClass': 'nonsense', 'location': null},
        ],
      });
      final done = TilawaEvent.parse(raw) as TilawaDone;
      expect(done.mistakes, hasLength(1));
      expect(done.mistakes.single.location, const WordPosition(2, 5, 2));
    });

    test('carries load failures through', () {
      final failure =
          TilawaEvent.parse(
                jsonEncode({
                  't': 'error',
                  'stage': 'load',
                  'name': 'TilawaLoadError',
                  'message': 'offline',
                }),
              )
              as TilawaFailure;
      expect(failure.stage, 'load');
      expect(failure.name, 'TilawaLoadError');
    });

    test('ignores anything it does not understand', () {
      expect(TilawaEvent.parse('not json'), isNull);
      expect(TilawaEvent.parse('[]'), isNull);
      expect(TilawaEvent.parse('{"t":"mystery"}'), isNull);
    });
  });

  group('PassageProgress', () {
    test('splits display text into words and drops bare marks', () {
      expect(PassageProgress.splitWords('بِسْمِ ٱللَّهِ ۞ ١ ٱلرَّحِيمِ'), [
        'بِسْمِ',
        'ٱللَّهِ',
        'ٱلرَّحِيمِ',
      ]);
    });

    test(
      'a word is tentative first, and settles once the engine is past it',
      () {
        final progress = _passage();
        progress.apply(TilawaEvent.parse(_position(1, 2))!);
        expect(progress.statusAt(0), WordStatus.tentative);
        expect(progress.statusAt(1), WordStatus.tentative);
        expect(progress.statusAt(2), WordStatus.pending);

        progress.apply(TilawaEvent.parse(_position(1, 4))!);
        expect(progress.statusAt(0), WordStatus.recited);
        expect(progress.statusAt(1), WordStatus.recited);
        expect(progress.statusAt(2), WordStatus.tentative);
        expect(progress.statusAt(3), WordStatus.tentative);
        expect(progress.heardCount, 4);
      },
    );

    test('ignores positions that are not locked or not confident', () {
      final progress = _passage();
      expect(
        progress.apply(TilawaEvent.parse(_position(1, 3, state: 'acquiring'))!),
        isFalse,
      );
      expect(
        progress.apply(TilawaEvent.parse(_position(1, 3, conf: 0.6))!),
        isFalse,
      );
      expect(progress.heardCount, 0);
    });

    test('a hesitant guess is taken back when the span moves on', () {
      final progress = _passage();
      progress.apply(TilawaEvent.parse(_position(1, 3, conf: 0.76))!);
      expect(progress.statusAt(2), WordStatus.tentative);
      // The engine now says the third word was never recited.
      progress.apply(TilawaEvent.parse(_position(2, 2, spanStart: '1:4'))!);
      expect(progress.statusAt(2), WordStatus.unverified);
    });

    test('a word the reciter moved past unheard is not called correct', () {
      final progress = _passage();
      progress.apply(TilawaEvent.parse(_position(2, 4, spanStart: '1:4'))!);
      expect(progress.statusAt(0), WordStatus.unverified);
      expect(progress.statusAt(2), WordStatus.unverified);
      expect(progress.statusAt(3), WordStatus.recited);
    });

    test('marks a confirmed slip, and clears it when the reciter corrects', () {
      final progress = _passage();
      progress.apply(TilawaEvent.parse(_position(1, 4))!);
      progress.apply(TilawaEvent.parse(_checker('m1', 'confirmed', 1, 2))!);
      expect(progress.statusAt(1), WordStatus.wrong);
      expect(progress.wrongCount, 1);

      progress.apply(TilawaEvent.parse(_checker('m1', 'resolved', 1, 2))!);
      expect(progress.statusAt(1), WordStatus.recited);
      expect(progress.wrongCount, 0);
    });

    test('ignores a suspected slip and a low-confidence confirmation', () {
      final progress = _passage();
      progress.apply(TilawaEvent.parse(_position(1, 3))!);
      progress.apply(TilawaEvent.parse(_checker('m1', 'suspected', 1, 2))!);
      progress.apply(
        TilawaEvent.parse(_checker('m2', 'confirmed', 1, 2, conf: 0.6))!,
      );
      expect(progress.wrongCount, 0);
    });

    test('ignores another surah and clamps a word past the ayah end', () {
      final progress = _passage();
      final other = jsonEncode({
        't': 'position',
        'state': 'locked',
        'observed': [
          {
            'word': {'s': 2, 'a': 1, 'w': 1},
            'confidence': 1,
          },
        ],
      });
      expect(progress.apply(TilawaEvent.parse(other)!), isFalse);

      progress.apply(TilawaEvent.parse(_position(1, 9))!);
      expect(progress.statusAt(3), WordStatus.tentative);
    });
  });
}
