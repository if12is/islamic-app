import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/audio_download_service.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The regression: sourceFor() reached for path_provider before anything
  // else, and path_provider has no web implementation. Every play attempt in a
  // browser threw MissingPluginException before a single byte was requested,
  // and the message blamed the user's connection.
  group('Streaming when nothing can be stored', () {
    test('falls back to streaming rather than throwing', () async {
      final service = AudioDownloadService();
      final source = await service.sourceFor('ar.alafasy', 1);

      expect(source, startsWith('https://'));
      expect(source, endsWith('/001.mp3'));
    });

    test('a missing local file never blocks playback', () async {
      final service = AudioDownloadService();
      final local = await service.localPathIfAvailable('ar.alafasy', 114);

      expect(local, isNull, reason: 'nothing downloaded, so stream instead');
    });

    test('listing downloads is empty, not an error', () async {
      expect(await AudioDownloadService().listDownloads(), isEmpty);
    });

    test('storage support tracks the platform, not a guess', () {
      // The queue and the download button both gate on this. On the web it
      // must be false, or a hundred downloads are queued that each fail
      // instantly — which on screen is indistinguishable from working.
      expect(AudioDownloadService.isSupported, !kIsWeb);
    });
  });

  group('The streaming address', () {
    test('is https and names the surah', () {
      final url = QuranLocalService.audioUrlForSurah(
        18,
        reciterCode: 'ar.husary',
      );
      expect(url, startsWith('https://'));
      expect(url, endsWith('/018.mp3'));
    });
  });
}
