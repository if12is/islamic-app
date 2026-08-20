import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/domain/entities/recitation_match.dart';

void main() {
  const fatiha =
      'الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين إياك نعبد وإياك '
      'نستعين';

  RecitationResult check(String heard, {String expected = fatiha}) =>
      RecitationMatcher.compare(expected: expected, heard: heard);

  group('Word similarity', () {
    test('identical words score one', () {
      expect(RecitationMatcher.similarity('رب', 'رب'), 1);
    });

    test('spelling differences stay close', () {
      // What a recognizer typically returns against the Mushaf spelling.
      expect(
        RecitationMatcher.similarity('لعلمين', 'لعلمين'),
        greaterThan(RecitationMatcher.exactThreshold),
      );
      expect(
        RecitationMatcher.similarity('لرحمن', 'لرحمان'),
        greaterThan(RecitationMatcher.nearThreshold),
      );
    });

    test('unrelated words score low', () {
      expect(
        RecitationMatcher.similarity('لحمد', 'نستعين'),
        lessThan(RecitationMatcher.nearThreshold),
      );
      expect(RecitationMatcher.similarity('', 'رب'), 0);
    });
  });

  group('Grading a recitation', () {
    test('nothing heard leaves every word pending', () {
      final result = check('');

      expect(result.words, isNotEmpty);
      expect(
        result.words.every((w) => w.status == RecitationWordStatus.pending),
        isTrue,
      );
      expect(result.reached, 0);
      expect(result.accuracy, 0);
    });

    test('a perfect recitation marks everything correct', () {
      final result = check(fatiha);

      expect(result.correct, result.words.length);
      expect(result.wrong, 0);
      expect(result.accuracy, 1);
      expect(result.isComplete, isTrue);
    });

    test('a partial recitation grades only what was said', () {
      final result = check('الحمد لله رب العالمين');

      expect(result.reached, 4);
      expect(result.correct, 4);
      expect(
        result.words
            .skip(4)
            .every((w) => w.status == RecitationWordStatus.pending),
        isTrue,
      );
      expect(result.isComplete, isFalse);
      // Accuracy reflects what was attempted, not what is left.
      expect(result.accuracy, 1);
    });

    test('a skipped word is flagged and the rest stays aligned', () {
      // "رب" dropped.
      final result = check('الحمد لله العالمين الرحمن الرحيم');

      expect(result.words[2].text, 'رب');
      expect(result.words[2].status, RecitationWordStatus.wrong);
      expect(result.words[3].status, RecitationWordStatus.correct);
      expect(result.words[4].status, RecitationWordStatus.correct);
    });

    test('an inserted word does not knock the rest out of step', () {
      // The recognizer heard an extra word in the middle.
      final result = check('الحمد لله يا رب العالمين الرحمن');

      expect(result.words[2].status, RecitationWordStatus.correct);
      expect(result.words[3].status, RecitationWordStatus.correct);
      expect(result.words[4].status, RecitationWordStatus.correct);
    });

    test('a wrong word is marked without failing its neighbours', () {
      final result = check('الحمد لله رب السماوات الرحمن الرحيم');

      expect(result.words[3].status, RecitationWordStatus.wrong);
      expect(result.words[4].status, RecitationWordStatus.correct);
      expect(result.words[5].status, RecitationWordStatus.correct);
      expect(result.accuracy, lessThan(1));
      expect(result.accuracy, greaterThan(0.5));
    });

    test('modern spelling of the same words still passes', () {
      // No diacritics, alef spelled out — a typical recognizer transcript.
      final result = check(
        'الحمد لله رب العالمين الرحمان الرحيم مالك يوم الدين',
      );

      expect(result.wrong, 0);
      expect(result.accuracy, greaterThan(0.9));
    });

    test('counts near matches as half, not as failures', () {
      const result = RecitationResult(
        words: [
          RecitationWord(text: 'a', status: RecitationWordStatus.correct),
          RecitationWord(text: 'b', status: RecitationWordStatus.near),
          RecitationWord(text: 'c', status: RecitationWordStatus.pending),
        ],
        reached: 2,
      );

      expect(result.graded, 2);
      expect(result.accuracy, closeTo(0.75, 0.001));
    });
  });
}
