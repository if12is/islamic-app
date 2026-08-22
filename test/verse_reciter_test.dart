import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/presentation/providers/quran_audio_provider.dart';

void main() {
  test('catalogue reciter ids are not used for verse-by-verse audio', () {
    expect(QuranReciter.hasVerseAudio('ar.alafasy'), isTrue);
    expect(QuranReciter.hasVerseAudio('mp3quran:92:92'), isFalse);
    expect(QuranReciter.verseAudioCode('mp3quran:92:92'), 'ar.alafasy');
    expect(QuranReciter.verseAudioCode('ar.husary'), 'ar.husary');
  });
}
