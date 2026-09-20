import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/quran/data/services/reciter_catalogue.dart';
import 'package:islamic_app/features/quran/data/services/verse_reciters.dart';
import 'package:islamic_app/features/quran/domain/entities/riwaya.dart';
import 'package:islamic_app/features/quran/presentation/widgets/recitation_picker_sheet.dart';

const _allSurahs = {1, 2, 3};

final _hafs = ReciterVoice(
  id: 'hafs-full',
  nameAr: 'حفص',
  styleAr: 'مرتَّل',
  server: 'https://example.mp3quran.net/h/',
  surahs: _allSurahs,
  riwayaId: Riwaya.hafsId,
);

final _hafsPartial = ReciterVoice(
  id: 'hafs-partial',
  nameAr: 'حفص ناقص',
  styleAr: 'مجوَّد',
  server: 'https://example.mp3quran.net/hp/',
  surahs: const {1},
  riwayaId: Riwaya.hafsId,
);

final _warsh = ReciterVoice(
  id: 'warsh-full',
  nameAr: 'ورش',
  styleAr: 'رواية ورش',
  server: 'https://example.mp3quran.net/w/',
  surahs: _allSurahs,
  riwayaId: Riwaya.warshId,
);

final _qalun = ReciterVoice(
  id: 'qalun-full',
  nameAr: 'قالون',
  styleAr: 'رواية قالون',
  server: 'https://example.mp3quran.net/q/',
  surahs: _allSurahs,
  riwayaId: 5,
);

void main() {
  final voices = [_qalun, _warsh, _hafs, _hafsPartial];

  group('Hiding what cannot play', () {
    test('a Warsh mushaf is never offered a Hafs recording', () {
      final listed = RecitationOptions.surahVoices(
        voices: voices,
        edition: MushafEdition.warsh,
        surahNumber: 2,
      );

      expect(listed.map((v) => v.id), ['warsh-full']);
      expect(listed.any((v) => v.riwayaId == Riwaya.hafsId), isFalse);
    });

    test('a Hafs mushaf is never offered a Warsh recording', () {
      final listed = RecitationOptions.surahVoices(
        voices: voices,
        edition: MushafEdition.hafs,
        surahNumber: 2,
      );

      expect(listed.map((v) => v.id), ['hafs-full']);
      expect(listed.any((v) => v.isWarsh), isFalse);
    });

    test('a partial recording is hidden for a surah it does not have', () {
      // Offering it would 404; hiding it is the honest answer.
      final listed = RecitationOptions.surahVoices(
        voices: voices,
        edition: MushafEdition.hafs,
        surahNumber: 2,
      );

      expect(listed.map((v) => v.id), isNot(contains('hafs-partial')));
    });

    test('a partial recording is listed for a surah it does have', () {
      final listed = RecitationOptions.surahVoices(
        voices: voices,
        edition: MushafEdition.hafs,
        surahNumber: 1,
      );

      expect(listed.map((v) => v.id), contains('hafs-partial'));
    });

    test('the saved Hafs id is not replaced by a Warsh row', () {
      final listed = RecitationOptions.surahVoices(
        voices: voices,
        edition: MushafEdition.warsh,
        surahNumber: 1,
      );

      expect(listed.any((v) => v.id == 'hafs-full'), isFalse);
      expect(listed, isNotEmpty);
    });
  });

  group('Verse voices follow the mushaf', () {
    test('Warsh verse audio is only the Warsh recordings', () {
      final listed = RecitationOptions.verseVoices(MushafEdition.warsh);

      expect(listed, isNotEmpty);
      expect(listed.every((r) => r.isWarsh), isTrue);
      expect(listed.map((r) => r.id), isNot(contains(VerseReciters.defaultId)));
    });

    test('Hafs verse audio never includes Warsh', () {
      final listed = RecitationOptions.verseVoices(MushafEdition.hafs);

      expect(listed.every((r) => !r.isWarsh), isTrue);
      expect(listed, isNotEmpty);
    });

    test('find returns null for a whole-surah id instead of a substitute', () {
      expect(VerseReciters.find('mp3quran:92:92'), isNull);
      expect(VerseReciters.find('hafs-full'), isNull);
    });
  });

  group('Riwayah tabs', () {
    test('Hafs is first, Warsh second, then the provider order', () {
      final tabs = RecitationOptions.tabsFor(
        riwayaIds: const {5, Riwaya.warshId, Riwaya.hafsId},
        known: Riwaya.bundled,
      );

      expect(tabs.map((r) => r.id), [Riwaya.hafsId, Riwaya.warshId, 5]);
    });

    test('a riwayah with no recording in this mode is not a tab', () {
      final tabs = RecitationOptions.tabsFor(
        riwayaIds: const {Riwaya.warshId},
        known: Riwaya.bundled,
      );

      expect(tabs.map((r) => r.id), [Riwaya.warshId]);
      expect(tabs.any((r) => r.id == Riwaya.hafsId), isFalse);
    });

    test('the all-tab sentinel leaves the list intact', () {
      final listed = RecitationOptions.inRiwaya(
        voices,
        RecitationOptions.allRiwayatId,
        (voice) => voice.riwayaId,
      );
      expect(listed, voices);
    });

    test('a riwayah tab hides every other reading', () {
      final listed = RecitationOptions.inRiwaya(
        voices,
        Riwaya.warshId,
        (voice) => voice.riwayaId,
      );
      expect(listed.map((v) => v.id), ['warsh-full']);
    });
  });
}
