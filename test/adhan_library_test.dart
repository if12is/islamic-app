import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/models/adhan_sound.dart';
import 'package:islamic_app/core/services/adhan_library.dart';
import 'package:islamic_app/core/services/secure_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('The adhan library', () {
    test('every voice has its own id, which an installed sound is kept by', () {
      final ids = AdhanLibrary.voices.map((voice) => voice.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final voice in AdhanLibrary.voices) {
        expect(AdhanLibrary.byId(voice.id), same(voice));
      }
      expect(AdhanLibrary.byId('nobody'), isNull);
    });

    test('every voice is named in both languages and placed', () {
      for (final voice in AdhanLibrary.voices) {
        expect(voice.nameAr.trim(), isNotEmpty, reason: voice.id);
        expect(voice.nameEn.trim(), isNotEmpty, reason: voice.id);
        expect(voice.placeAr.trim(), isNotEmpty, reason: voice.id);
        expect(voice.placeEn.trim(), isNotEmpty, reason: voice.id);
        expect(voice.name('ar'), voice.nameAr);
        expect(voice.name('en'), voice.nameEn);
      }
    });

    test('every address is one the guarded client will fetch', () {
      // A voice on a host the client refuses would look, on screen, exactly
      // like a download that failed for want of a connection.
      for (final voice in AdhanLibrary.voices) {
        final uri = Uri.parse(voice.url);
        expect(uri.scheme, 'https', reason: voice.id);
        expect(
          SecureHttpClient.isAllowedHost(uri.host),
          isTrue,
          reason: '${voice.id}: ${uri.host}',
        );
        expect(uri.path.toLowerCase(), endsWith('.mp3'), reason: voice.id);
        expect(voice.url, isNot(contains(' ')), reason: voice.id);
      }
    });

    test('the redirect to a storage node is allowed, and nothing else is', () {
      expect(SecureHttpClient.isAllowedHost('ia801004.us.archive.org'), isTrue);
      expect(SecureHttpClient.isAllowedHost('dn720003.ca.archive.org'), isTrue);
      expect(SecureHttpClient.isAllowedHost('ia800.eu.archive.org'), isFalse);
      expect(
        SecureHttpClient.isAllowedHost('evil.us.archive.org.example'),
        isFalse,
      );
      expect(SecureHttpClient.isAllowedHost('notarchive.org'), isFalse);
    });

    test('reaches every region, and has a Fajr adhan for the Haramain', () {
      final regions = AdhanLibrary.voices.map((voice) => voice.region).toSet();
      expect(regions, containsAll(AdhanRegion.values));
      expect(
        AdhanLibrary.voices.where(
          (voice) => voice.fajr && voice.region == AdhanRegion.haramain,
        ),
        isNotEmpty,
      );
      expect(AdhanLibrary.voices.where((voice) => voice.rare), isNotEmpty);
    });

    test('nothing in it is large enough to surprise a data allowance', () {
      for (final voice in AdhanLibrary.voices) {
        expect(voice.bytes, greaterThan(100 * 1024), reason: voice.id);
        expect(voice.bytes, lessThan(6 * 1024 * 1024), reason: voice.id);
      }
    });
  });

  group('An installed voice', () {
    setUp(() {
      AdhanLibrary.resetForTest();
    });

    test('is remembered across launches and recognised by its sound', () async {
      SharedPreferences.setMockInitialValues({
        'adhan_library_v1:qatami': 'content://media/external/audio/media/42',
      });
      await AdhanLibrary.load();

      final qatami = AdhanLibrary.byId('qatami')!;
      expect(AdhanLibrary.isInstalled(qatami), isTrue);
      expect(AdhanLibrary.isInstalled(AdhanLibrary.byId('alafasy')!), isFalse);

      final selection = await AdhanLibrary.install(qatami);
      expect(selection.isCustom, isTrue);
      expect(selection.uri, 'content://media/external/audio/media/42');
      expect(AdhanLibrary.voiceFor(selection), same(qatami));
      expect(
        AdhanLibrary.voiceFor(
          const AdhanSoundSelection(
            id: AdhanSoundSelection.customId,
            uri: 'content://somewhere/else',
          ),
        ),
        isNull,
      );
    });
  });
}
