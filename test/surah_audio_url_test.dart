import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:islamic_app/features/quran/presentation/providers/quran_audio_provider.dart';

void main() {
  // The bug: whole-surah audio was requested from the islamic.network CDN,
  // which serves only ar.alafasy at surah level and returns 403 for every
  // other edition. The default voice played; changing voice threw
  // PlayerException. Verified against the live hosts before this was written.
  group('Whole-surah audio', () {
    test('every reciter offered in the app has a host', () {
      for (final reciter in QuranReciter.all) {
        expect(
          QuranReciter.hasSurahAudio(reciter.code),
          isTrue,
          reason:
              '${reciter.code} is offered in the picker but has no surah host, '
              'so choosing it would fail on every surah',
        );
      }
    });

    test('no reciter is left pointing at the CDN that refuses them', () {
      for (final reciter in QuranReciter.all) {
        final url = QuranLocalService.audioUrlForSurah(
          1,
          reciterCode: reciter.code,
        );
        expect(
          url,
          isNot(contains('audio-surah')),
          reason: '${reciter.code} still uses the 403 path',
        );
      }
    });

    test('surah numbers are padded to three digits', () {
      expect(
        QuranLocalService.audioUrlForSurah(1, reciterCode: 'ar.husary'),
        endsWith('/001.mp3'),
      );
      expect(
        QuranLocalService.audioUrlForSurah(18, reciterCode: 'ar.husary'),
        endsWith('/018.mp3'),
      );
      expect(
        QuranLocalService.audioUrlForSurah(114, reciterCode: 'ar.husary'),
        endsWith('/114.mp3'),
      );
    });

    test('every host is https and on the allowlisted domain', () {
      for (final host in QuranLocalService.surahAudioHosts.values) {
        expect(host, startsWith('https://'));
        expect(
          host,
          contains('mp3quran.net'),
          reason: 'anything else needs adding to network_security_config.xml',
        );
      }
    });

    test('an unknown voice still produces a URL to try', () {
      final url = QuranLocalService.audioUrlForSurah(
        1,
        reciterCode: 'ar.someone.new',
      );
      expect(url, startsWith('https://'));
    });
  });

  group('Verse audio is untouched', () {
    test('still comes from the CDN, which carries every edition', () {
      final url = QuranLocalService.audioUrlForVerse(
        1,
        1,
        reciterCode: 'ar.husary',
      );
      expect(url, contains('cdn.islamic.network'));
    });
  });
}
