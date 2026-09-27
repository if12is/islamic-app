import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_english_translation.dart';

void main() {
  test('reads Saheeh International ayahs out of an alquran.cloud surah', () {
    final verses = QuranEnglishTranslation.parse({
      'data': {
        'ayahs': [
          {'numberInSurah': 1, 'text': ' In the name of Allah '},
          {'numberInSurah': 2, 'text': 'All praise is due to Allah.'},
          {'numberInSurah': 3, 'text': '   '},
        ],
      },
    });

    expect(verses[1], 'In the name of Allah');
    expect(verses[2], 'All praise is due to Allah.');
    expect(verses.containsKey(3), isFalse);
  });

  test('an unexpected payload is an empty surah, not a crash', () {
    expect(QuranEnglishTranslation.parse(null), isEmpty);
    expect(QuranEnglishTranslation.parse({'data': 'no'}), isEmpty);
  });
}
