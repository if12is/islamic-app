import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/utils/quran_text_detector.dart';

void main() {
  setUp(QuranTextDetector.resetCache);

  group('Telling revelation from du\'a', () {
    test('recognises a verse quoted inside a dhikr', () {
      const ayatAlKursi =
          'اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ '
          'سِنَةٌ وَلاَ نَوْمٌ';
      expect(QuranTextDetector.isQuranic(ayatAlKursi), isTrue);
    });

    test('recognises a short surah', () {
      const ikhlas =
          'قُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ، لَمْ يَلِدْ وَلَمْ '
          'يُولَدْ';
      expect(QuranTextDetector.isQuranic(ikhlas), isTrue);
    });

    test('does not mistake supplication for revelation', () {
      const isti3atha = 'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ';
      const dua =
          'اللّهـمَّ أَنْتَ رَبِّـي لا إلهَ إلاّ أَنْتَ، خَلَقْتَنـي وَأَنا '
          'عَبْـدُك';
      const dhikr = 'سُبْحـانَ اللهِ وَبِحَمْـدِهِ عَدَدَ خَلْـقِه';

      expect(QuranTextDetector.isQuranic(isti3atha), isFalse);
      expect(QuranTextDetector.isQuranic(dua), isFalse);
      expect(QuranTextDetector.isQuranic(dhikr), isFalse);
    });

    test('ignores fragments too short to judge', () {
      expect(QuranTextDetector.isQuranic('الحمد لله'), isFalse);
      expect(QuranTextDetector.isQuranic(''), isFalse);
    });

    test('matches through diacritics and hamza spellings', () {
      // Same verse, written without any diacritics at all.
      expect(
        QuranTextDetector.isQuranic('الحمد لله رب العالمين الرحمن الرحيم'),
        isTrue,
      );
    });
  });

  group('Segmenting mixed text', () {
    test('splits a dhikr that opens with a verse', () {
      const text =
          'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ\n'
          'اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ '
          'سِنَةٌ وَلاَ نَوْمٌ';

      final segments = QuranTextDetector.segment(text);
      expect(segments, hasLength(2));
      expect(segments.first.isQuran, isFalse);
      expect(segments.last.isQuran, isTrue);
    });

    test('pulls a bracketed verse out of a longer line', () {
      const text =
          'ثم يقول ﴿الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ﴾ ثم يكمل دعاءه';

      final segments = QuranTextDetector.segment(text);
      expect(segments.any((segment) => segment.isQuran), isTrue);
      expect(segments.length, greaterThan(1));
    });

    test('leaves pure supplication as one plain block', () {
      const text = 'اللهم إني أسألك العفو والعافية في الدنيا والآخرة';
      final segments = QuranTextDetector.segment(text);

      expect(segments, hasLength(1));
      expect(segments.single.isQuran, isFalse);
    });

    test('merges neighbouring runs of the same kind', () {
      const text = 'سطر أول من الدعاء\nسطر ثانٍ من الدعاء';
      final segments = QuranTextDetector.segment(text);

      expect(segments, hasLength(1));
      expect(segments.single.text, contains('\n'));
    });
  });

  group('Real quotations from the collections', () {
    test('Ayat al-Kursi as the azkar spell it', () {
      const text =
          'اللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ '
          'سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ '
          'مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ';
      expect(QuranTextDetector.isQuranic(text), isTrue);
      expect(QuranTextDetector.quranicScore(text), greaterThan(0.8));
    });

    test('Al-Falaq with Uthmani dagger alefs', () {
      const text =
          'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ '
          'غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ';
      expect(QuranTextDetector.isQuranic(text), isTrue);
    });

    test('An-Nas and Al-Ikhlas', () {
      expect(
        QuranTextDetector.isQuranic(
          'قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ، مَلِكِ ٱلنَّاسِ، إِلَٰهِ ٱلنَّاسِ',
        ),
        isTrue,
      );
      expect(
        QuranTextDetector.isQuranic(
          'قُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ',
        ),
        isTrue,
      );
    });

    test('supplication that borrows a Quranic phrase stays supplication', () {
      const morningDhikr =
          'أَصْبَحْنا وَأَصْبَحَ الْمُلْكُ لله وَالْحَمدُ لله، لا إلهَ إلاّ '
          'اللّهُ وَحْدَهُ لا شَريكَ لهُ، لهُ الْمُلْكُ ولهُ الْحَمْد، وهُوَ '
          'على كلّ شَيءٍ قَدير';
      const dua =
          'اللّهُمَّ أَنْتَ رَبِّي لا إلهَ إلاّ أَنْتَ، خَلَقْتَنِي وَأَنا '
          'عَبْدُك، وَأَنا عَلى عَهْدِكَ وَوَعْدِكَ ما اسْتَطَعْت';

      expect(QuranTextDetector.isQuranic(morningDhikr), isFalse);
      expect(QuranTextDetector.isQuranic(dua), isFalse);
      expect(QuranTextDetector.quranicScore(dua), lessThan(0.3));
    });

    test('scores separate verses from prose by a wide margin', () {
      final verse = QuranTextDetector.quranicScore(
        'وَنُنَزِّلُ مِنَ الْقُرْآنِ مَا هُوَ شِفَاءٌ وَرَحْمَةٌ لِلْمُؤْمِنِينَ',
      );
      final prose = QuranTextDetector.quranicScore(
        'اللهم إني أسألك العفو والعافية في الدنيا والآخرة يا رب العالمين',
      );

      expect(verse, greaterThan(0.8));
      expect(prose, lessThan(0.4));
    });
  });

  group('Against the bundled azkar', () {
    test('finds revelation in the morning azkar, and not everywhere', () {
      final data =
          jsonDecode(File('assets/data/azkar.json').readAsStringSync())
              as Map<String, dynamic>;
      final morning = (data['categories'] as List).cast<Map>().firstWhere(
        (category) => category['id'] == 'morning',
      );
      final items = (morning['azkar'] as List).cast<Map>();

      final quranic =
          items
              .where(
                (item) => QuranTextDetector.segment(
                  item['textAr'] as String,
                ).any((segment) => segment.isQuran),
              )
              .length;

      // The morning set opens with Ayat al-Kursi and the three quls, and the
      // rest is supplication — so some, but nowhere near all.
      expect(quranic, greaterThanOrEqualTo(4));
      expect(quranic, lessThan(items.length ~/ 2));
    });
  });
}
