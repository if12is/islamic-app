import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/domain/entities/passage_progress.dart';
import 'package:islamic_app/features/quran/domain/entities/tilawa_event.dart';

/// Replays what the real engine emitted on real recordings (Surat An-Nas by
/// Alafasy, Husary and Minshawy, spliced to skip or swap a verse, and with
/// noise added), through the same code the screen uses.
///
/// The traces in test/fixtures/tilawa were captured by running the Tilawa
/// full model over the audio in a browser; they are the engine's own events,
/// slimmed to what the host page forwards.
PassageProgress _replay(String name) {
  final trace =
      jsonDecode(File('test/fixtures/tilawa/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, int>? w(Object? at) {
    if (at == null) {
      return null;
    }
    final p = (at as String).split(':').map(int.parse).toList();
    return {'s': p[0], 'a': p[1], 'w': p[2]};
  }

  final events = <(int, int, String)>[];
  for (final p in (trace['pos'] as List).cast<Map<String, dynamic>>()) {
    final span = (p['sp'] as String?)?.split('-');
    events.add((
      p['t'] as int,
      0,
      jsonEncode({
        't': 'position',
        'state': switch (p['st']) {
          'locked' => 'locked',
          'ambiguous' => 'ambiguous',
          'lost' => 'lost',
          _ => 'acquiring',
        },
        'expected': w(p['exp']),
        'observed': [
          {
            'word': w(p['obs']),
            'span':
                span == null ? null : {'start': w(span[0]), 'end': w(span[1])},
            'confidence': p['conf'],
          },
        ],
      }),
    ));
  }
  for (final c in (trace['chk'] as List).cast<Map<String, dynamic>>()) {
    events.add((
      c['t'] as int,
      1,
      jsonEncode({
        't': 'checker',
        'id': c['id'],
        'state': c['st'],
        'errorClass': c['cls'],
        'location': w(c['at']),
        'confidence': c['conf'],
      }),
    ));
  }
  events.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });

  final progress = PassageProgress(
    surah: 114,
    words: {
      for (var a = 1; a <= 6; a++)
        a: PassageProgress.splitWords(QuranLocalService.verse(114, a).text),
    },
  );
  for (final (_, _, raw) in events) {
    progress.apply(TilawaEvent.parse(raw)!);
  }
  return progress;
}

int _indexOfWord(PassageProgress p, int ayah, int word) {
  for (var i = 0; i < p.length; i++) {
    final key = p.keyAt(i);
    if (key.ayah == ayah && key.word == word) {
      return i;
    }
  }
  throw StateError('no word $ayah:$word');
}

void main() {
  group('A correct recitation is never called wrong', () {
    for (final name in [
      'correct-alafasy',
      'correct-husary_noisy12',
      'correct-husary_noisy6',
      'correct-minshawy_noisy6',
    ]) {
      test(name, () {
        final progress = _replay(name);
        expect(progress.wrongCount, 0);
      });
    }

    test('and, in clean audio, ends with every word heard', () {
      final progress = _replay('correct-alafasy');
      for (var i = 0; i < progress.length; i++) {
        expect(
          progress.statusAt(i),
          anyOf(WordStatus.recited, WordStatus.tentative),
          reason: 'word $i',
        );
      }
      // Everything but the last couple of words has settled.
      expect(
        List.generate(
          progress.length - PassageProgress.settleWords,
          progress.statusAt,
        ).every((s) => s == WordStatus.recited),
        isTrue,
      );
    });
  });

  group('A mistake is only called once the engine confirms it', () {
    test('a skipped verse is not counted as recited, and is confirmed', () {
      final progress = _replay('skip-ayah3');
      final skipped = _indexOfWord(progress, 3, 1);
      expect(progress.statusAt(skipped), WordStatus.wrong);
      expect(progress.wrongCount, 1);
      // What was recited before the skip stays recited.
      expect(
        progress.statusAt(_indexOfWord(progress, 1, 1)),
        WordStatus.recited,
      );
      expect(
        progress.statusAt(_indexOfWord(progress, 2, 1)),
        WordStatus.recited,
      );
    });

    test('a wrong verse is marked on its first word', () {
      final progress = _replay('wrong-ayah_falaq5_for_nas4_');
      expect(progress.statusAt(_indexOfWord(progress, 4, 1)), WordStatus.wrong);
    });

    test(
      'a skip the engine is unsure of is shown as not heard, not as right',
      () {
        final progress = _replay('skip-ayah3_noisy12');
        final skipped = _indexOfWord(progress, 3, 1);
        expect(progress.statusAt(skipped), WordStatus.unverified);
        expect(progress.wrongCount, 0);
      },
    );
  });
}
