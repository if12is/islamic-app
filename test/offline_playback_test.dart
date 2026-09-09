import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/audio_download_service.dart';
import 'package:islamic_app/features/quran/presentation/providers/downloads_provider.dart';
import 'package:islamic_app/features/quran/presentation/providers/reader_settings_provider.dart';

DownloadedSurah _saved(String reciter, int surah) =>
    DownloadedSurah(reciterCode: reciter, surahNumber: surah, bytes: 1000);

void main() {
  group('What can be played with no connection', () {
    const state = DownloadsState(
      downloads: [
        DownloadedSurah(
          reciterCode: 'ar.alafasy',
          surahNumber: 18,
          bytes: 1000,
        ),
        DownloadedSurah(reciterCode: 'ar.husary', surahNumber: 36, bytes: 1000),
      ],
    );

    test('a surah saved in any voice counts as playable', () {
      // The question the surah list asks is "will this start", not "will this
      // start in the voice the app happens to be set to".
      expect(state.hasAnyVoice(18), isTrue);
      expect(state.hasAnyVoice(36), isTrue);
      expect(state.hasAnyVoice(2), isFalse);
    });

    test('the chosen voice wins when it is the one on disk', () {
      expect(state.offlineVoiceFor(18, preferred: 'ar.alafasy'), 'ar.alafasy');
    });

    test('another downloaded voice stands in when the chosen one is not', () {
      // This is the bug it exists for: al-Kahf saved under Al-Afasy, the app
      // set to Husary, no signal — and "try again" on top of a playable file.
      expect(state.offlineVoiceFor(18, preferred: 'ar.husary'), 'ar.alafasy');
      expect(state.offlineVoiceFor(36, preferred: 'ar.alafasy'), 'ar.husary');
    });

    test('a surah nobody has downloaded has no offline voice', () {
      expect(state.offlineVoiceFor(2, preferred: 'ar.alafasy'), isNull);
    });

    test('an empty library answers without throwing', () {
      const empty = DownloadsState();
      expect(empty.hasAnyVoice(1), isFalse);
      expect(empty.offlineVoiceFor(1, preferred: 'ar.alafasy'), isNull);
    });

    test('the same surah in two voices still prefers the chosen one', () {
      final both = DownloadsState(
        downloads: [_saved('ar.husary', 55), _saved('ar.alafasy', 55)],
      );
      expect(both.offlineVoiceFor(55, preferred: 'ar.alafasy'), 'ar.alafasy');
      expect(both.offlineVoiceFor(55, preferred: 'ar.husary'), 'ar.husary');
    });
  });

  group('Choosing a reciter before anything plays', () {
    test('a fresh install has not chosen one', () {
      // reciterCode alone cannot answer this: it holds a default, so "Al-Afasy
      // because nobody asked" and "Al-Afasy because I chose him" look the same.
      const settings = ReaderSettings();
      expect(settings.reciterChosen, isFalse);
      expect(settings.reciterCode, isNotEmpty);
    });

    test('picking one records that it was picked', () {
      const before = ReaderSettings();
      final after = before.copyWith(
        reciterCode: 'ar.husary',
        reciterChosen: true,
      );
      expect(after.reciterChosen, isTrue);
      expect(after.reciterCode, 'ar.husary');
    });

    test('the flag survives being written and read back', () {
      final restored = ReaderSettings.fromJson(
        const ReaderSettings(
          reciterCode: 'ar.husary',
          reciterChosen: true,
        ).toJson(),
      );
      expect(restored.reciterChosen, isTrue);
      expect(restored.reciterCode, 'ar.husary');
    });

    test('someone upgrading with a stored voice is left alone', () {
      // Their habit is settled. Opening a picker on it would be the app
      // asking a question it already has the answer to.
      final restored = ReaderSettings.fromJson({'reciterCode': 'ar.husary'});
      expect(restored.reciterChosen, isTrue);
    });

    test('a payload with no reciter at all still asks', () {
      final restored = ReaderSettings.fromJson({'fontSize': 30});
      expect(restored.reciterChosen, isFalse);
    });
  });
}
