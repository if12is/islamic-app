import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/domain/tajweed.dart';
import 'package:islamic_app/features/quran/domain/tajweed_palette.dart';

/// The rules found in a fragment, as (rule, the letters it covers).
///
/// Fragments are cut out of the middle of a verse, so they do not end at a
/// stop — otherwise the cut itself would be read as a pause and every fragment
/// ending in ق ط ب ج د would come back with a qalqalah that is not there.
List<(TajweedRule, String)> _rules(String text) => [
  for (final span in Tajweed.analyse(text, endsAtStop: false))
    (span.rule, text.substring(span.start, span.end)),
];

Set<TajweedRule> _kinds(String text) =>
    Tajweed.analyse(text, endsAtStop: false).map((span) => span.rule).toSet();

/// A whole verse, which does end where the reader may stop.
Set<TajweedRule> _verseKinds(String text) =>
    Tajweed.analyse(text).map((span) => span.rule).toSet();

void main() {
  group('The four rulings of a silent noon', () {
    test('izhar before a throat letter is left alone', () {
      // مِنْ عِلْمِهِ — read exactly as written, so colouring it would teach
      // nothing. Nothing changes, nothing is marked.
      expect(_kinds('مِنْ عِلْمِهِ'), isEmpty);
      expect(_kinds('أَنْعَمْتَ'), isEmpty);
    });

    test(
      'every written form of hamza counts as izhar, not just the bare ء',
      () {
        // أ إ آ ؤ ئ are the same letter wearing a seat. A rule table that lists
        // only ء turns every one of these into ikhfa.
        for (final text in [
          'مِنْ أَهْلِهَا',
          'مِنْ إِلَـٰهٍ',
          'رَحْمَةً ۚ إِنَّ',
        ]) {
          expect(
            _kinds(text).contains(TajweedRule.ikhfa),
            isFalse,
            reason: text,
          );
        }
      },
    );

    test('iqlab before a ba', () {
      expect(_rules('أَنْبِئْهُمْ').first.$1, TajweedRule.iqlab);
    });

    test('idgham with ghunnah before ي ن م و', () {
      expect(_rules('فَمَنْ يَعْمَلْ').first.$1, TajweedRule.idghamGhunnah);
      expect(_rules('بِشَيْءٍ مِنْ').first.$1, TajweedRule.idghamGhunnah);
    });

    test('idgham without ghunnah before ل and ر', () {
      expect(_rules('لَآيَاتٍ لِقَوْمٍ').first.$1, TajweedRule.idghamNoGhunnah);
    });

    test('ikhfa before the rest', () {
      expect(_rules('عِنْدَهُ').first.$1, TajweedRule.ikhfa);
      expect(_rules('مَنْ ذَا').first.$1, TajweedRule.ikhfa);
      expect(_rules('كُنْتُمْ').first.$1, TajweedRule.ikhfa);
    });

    test('izhar mutlaq: نْ before و or ي inside one word is not idgham', () {
      // The four words دنيا، بنيان، صنوان، قنوان. Every rule table forgets
      // them, and getting them wrong is a plain mistake in the reading.
      for (final word in [
        'الدُّنْيَا',
        'بُنْيَانٌ',
        'صِنْوَانٌ',
        'قِنْوَانٌ',
      ]) {
        final kinds = _kinds(word);
        expect(
          kinds.contains(TajweedRule.idghamGhunnah),
          isFalse,
          reason: word,
        );
      }
    });

    test('a doubled noon is ghunnah, not one of the four', () {
      expect(_rules('إِنَّ').first.$1, TajweedRule.ghunnah);
      expect(_rules('ثُمَّ').first.$1, TajweedRule.ghunnah);
    });
  });

  group('Tanween behaves exactly as a silent noon', () {
    test('the silent alif written after fathatan is not the next letter', () {
      // أَزْوَاجًا لِتَسْكُنُوا — the alif is written and not said, so the
      // ruling is tanween-then-lam. Reading the alif as the next letter makes
      // this ikhfa, which is wrong.
      final rules = _rules('أَزْوَاجًا لِتَسْكُنُوا');
      expect(rules.first.$1, TajweedRule.idghamNoGhunnah);
    });

    test('and the same for a following ya', () {
      final rules = _rules('خَيْرًا يَرَهُ');
      expect(rules.first.$1, TajweedRule.idghamGhunnah);
    });

    test('tanween at the very end of a verse has nothing to act on', () {
      final rules = _rules('أَحَدٌ');
      expect(rules.where((r) => r.$1 == TajweedRule.ikhfa), isEmpty);
    });
  });

  group('The rulings of a silent meem', () {
    test('ikhfa shafawi before a ba', () {
      expect(
        _kinds('أَنْبِئْهُمْ بِأَسْمَائِهِمْ'),
        contains(TajweedRule.ikhfaShafawi),
      );
    });

    test('idgham shafawi before another meem', () {
      expect(_rules('لَكُمْ مِنْ').first.$1, TajweedRule.idghamShafawi);
    });

    test('izhar shafawi is left plain', () {
      expect(_kinds('عَلَيْهِمْ غَيْرِ'), isEmpty);
      expect(_kinds('خَلْفَهُمْ وَلَا'), isEmpty);
    });
  });

  group('The madds whose length the writing fixes', () {
    test('muttasil: a long vowel then hamza in one word', () {
      expect(_kinds('شَاءَ'), contains(TajweedRule.maddMuttasil));
      expect(_kinds('بِأَسْمَائِهِمْ'), contains(TajweedRule.maddMuttasil));
    });

    test('munfasil: the hamza opens the next word', () {
      expect(_kinds('لَا إِلَـٰهَ'), contains(TajweedRule.maddMunfasil));
      expect(_kinds('إِنِّي أَعْلَمُ'), contains(TajweedRule.maddMunfasil));
      expect(_kinds('يَا آدَمُ'), contains(TajweedRule.maddMunfasil));
    });

    test('a silent alif does not hide the hamza behind it', () {
      // لِتَسْكُنُوا إِلَيْهَا — the madd letter is the waw; the alif after it
      // is written and not said.
      expect(
        _kinds('لِتَسْكُنُوا إِلَيْهَا'),
        contains(TajweedRule.maddMunfasil),
      );
    });

    test('lazim: a long vowel then a shadda', () {
      expect(_kinds('الضَّالِّينَ'), contains(TajweedRule.maddLazim));
    });

    test('a word opening with hamzat wasl is never a madd', () {
      // The bug this exists for: صِرَاطَ الَّذِينَ looks like an alif after a
      // fatha, so every ال in the Mushaf came out as a six-count madd.
      expect(
        _kinds('صِرَاطَ الَّذِينَ'),
        isNot(contains(TajweedRule.maddLazim)),
      );
      // And behind a joined conjunction, which is the harder case: the
      // tokenizer sees one word, so the same-word check alone does not save it.
      expect(_kinds('وَالْأَرْضَ'), isNot(contains(TajweedRule.maddLazim)));
      expect(
        _kinds('وَالْأَرْضِ وَأَعْلَمُ'),
        isNot(contains(TajweedRule.maddLazim)),
      );
    });

    test('the natural two-count madd is left plain', () {
      // Colouring it would put a colour on most of the page and mean nothing.
      expect(_kinds('يُحِيطُونَ'), isEmpty);
      expect(_kinds('قَالُوا'), isEmpty);
    });
  });

  group('Qalqalah', () {
    test('sughra: a written sukoon on one of قطب جد', () {
      expect(_rules('تُبْدُونَ').first.$1, TajweedRule.qalqalah);
      expect(_kinds('يَقْطَعُونَ'), contains(TajweedRule.qalqalah));
    });

    test('kubra: the last letter of a verse, where one may stop', () {
      expect(
        _verseKinds('قُلْ هُوَ اللَّهُ أَحَدٌ'),
        contains(TajweedRule.qalqalah),
      );
      expect(_verseKinds('اللَّهُ الصَّمَدُ'), contains(TajweedRule.qalqalah));
    });

    test('and not in the middle of one, where nobody stopped', () {
      // الْمَغْضُوبِ ends in a ba, but it sits mid-verse in al-Fatihah. A
      // fragment's own end is not a pause.
      expect(_kinds('الْمَغْضُوبِ'), isEmpty);
    });

    test('a letter outside قطب جد is never qalqalah', () {
      expect(_verseKinds('يَعْلَمُ'), isEmpty);
    });
  });

  group('The lam that is written and not said', () {
    test('a sun letter silences it', () {
      expect(_kinds('فِي السَّمَاوَاتِ'), contains(TajweedRule.silent));
      expect(_kinds('اللَّهُ'), contains(TajweedRule.silent));
      expect(_kinds('وَلَا الضَّالِّينَ'), contains(TajweedRule.silent));
    });

    test('a moon letter does not', () {
      expect(_kinds('الْحَمْدُ'), isNot(contains(TajweedRule.silent)));
      expect(_kinds('الْقَيُّومُ'), isNot(contains(TajweedRule.silent)));
    });

    test('behind a joined prefix it is still found', () {
      expect(_kinds('وَالسَّمَاءِ'), contains(TajweedRule.silent));
    });

    test('a doubled lam that is part of the word is not the article', () {
      // الَّذِينَ is a relative pronoun whose own lam is doubled and
      // pronounced. There is no silent letter in it, and marking one would
      // tell the reader to drop a sound that is really there.
      expect(_kinds('الَّذِينَ'), isNot(contains(TajweedRule.silent)));
      expect(_kinds('ذَا الَّذِي'), isNot(contains(TajweedRule.silent)));
    });
  });

  group('The spans themselves', () {
    test('never overlap, so no letter carries two colours', () {
      for (var surah = 1; surah <= 114; surah += 7) {
        final verses = QuranLocalService.versesOfSurah(surah);
        for (final verse in verses) {
          final spans = Tajweed.analyse(verse.text);
          for (var i = 1; i < spans.length; i++) {
            expect(
              spans[i].start,
              greaterThanOrEqualTo(spans[i - 1].end),
              reason: '${verse.key}: ${spans[i - 1]} then ${spans[i]}',
            );
          }
        }
      }
    });

    test('stay inside the text they describe', () {
      for (var surah = 100; surah <= 114; surah++) {
        for (final verse in QuranLocalService.versesOfSurah(surah)) {
          for (final span in Tajweed.analyse(verse.text)) {
            expect(span.start, greaterThanOrEqualTo(0));
            expect(span.end, lessThanOrEqualTo(verse.text.length));
            expect(span.isEmpty, isFalse, reason: '${verse.key} $span');
          }
        }
      }
    });

    test('empty and blank text answer rather than throwing', () {
      expect(Tajweed.analyse(''), isEmpty);
      expect(Tajweed.analyse('   '), isEmpty);
      expect(Tajweed.analyse('123'), isEmpty);
    });

    test('the whole Mushaf is analysed without an exception', () {
      // The engine touches every verse the moment someone turns colouring on,
      // so a single verse it chokes on is a crash in the reader.
      for (var surah = 1; surah <= 114; surah++) {
        for (final verse in QuranLocalService.versesOfSurah(surah)) {
          expect(
            () => Tajweed.analyse(verse.text),
            returnsNormally,
            reason: verse.key,
          );
        }
      }
    });
  });

  group('The colour key', () {
    test('every rule has a colour on both grounds', () {
      for (final rule in TajweedRule.values) {
        expect(TajweedPalette.onLight.of(rule), isNotNull);
        expect(TajweedPalette.onDark.of(rule), isNotNull);
      }
    });

    test('the key lists every rule exactly once', () {
      expect(TajweedPalette.keyOrder.toSet(), TajweedRule.values.toSet());
      expect(TajweedPalette.keyOrder.length, TajweedRule.values.length);
    });

    test('no two rules share a colour on the same ground', () {
      for (final palette in [TajweedPalette.onLight, TajweedPalette.onDark]) {
        final colours = {
          for (final rule in TajweedRule.values) palette.of(rule),
        };
        expect(colours.length, TajweedRule.values.length);
      }
    });
  });
}
