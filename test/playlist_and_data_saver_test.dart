import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:islamic_app/core/services/data_saver.dart';
import 'package:islamic_app/core/services/wird_habit_store.dart';
import 'package:islamic_app/features/quran/data/playlist_store.dart';
import 'package:islamic_app/features/quran/data/services/quran_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Listening lists', () {
    late Directory hiveDir;
    late PlaylistStore store;

    setUp(() async {
      hiveDir = await Directory.systemTemp.createTemp('playlist_test');
      Hive.init(hiveDir.path);
      store = PlaylistStore();
    });

    tearDown(() async {
      await Hive.close();
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }
    });

    test('a list survives being written and read back', () async {
      await store.save(
        Playlist(id: 'pl_1', name: 'قبل النوم', surahs: const [67, 32, 112]),
      );

      final read = await store.find('pl_1');
      expect(read!.name, 'قبل النوم');
      expect(read.surahs, [67, 32, 112]);
      expect(read.isDailyWird, isFalse);
    });

    test('the same surah can appear twice on purpose', () async {
      // Repeating al-Mulk at the end of a list is a normal thing to want.
      await store.save(
        const Playlist(id: 'pl_1', name: 'x', surahs: [67, 36, 67]),
      );
      expect((await store.find('pl_1'))!.surahs, [67, 36, 67]);
    });

    test('a surah number that is not one is dropped, not stored', () async {
      final restored = Playlist.fromMap({
        'id': 'pl_1',
        'name': 'x',
        'surahs': [1, 0, 115, 114, 'nine'],
      });
      expect(restored!.surahs, [1, 114]);
    });

    test('only one list can be the daily wird', () async {
      await store.save(
        const Playlist(id: 'a', name: 'A', surahs: [1], isDailyWird: true),
      );
      await store.save(
        const Playlist(id: 'b', name: 'B', surahs: [2], isDailyWird: true),
      );

      // Two cards both claiming to be today's is the bug this prevents.
      final daily = (await store.all()).where((p) => p.isDailyWird).toList();
      expect(daily.length, 1);
      expect(daily.single.id, 'b');
    });

    test('the daily wird sorts first', () async {
      await store.save(const Playlist(id: 'a', name: 'A', surahs: [1]));
      await store.save(
        const Playlist(id: 'z', name: 'Z', surahs: [2], isDailyWird: true),
      );
      expect((await store.all()).first.id, 'z');
    });

    test('finishing it today is recorded, and only for today', () async {
      await store.save(const Playlist(id: 'a', name: 'A', surahs: [1]));
      await store.markPlayed('a', when: DateTime(2026, 8, 24));

      final playlist = (await store.find('a'))!;
      expect(playlist.doneOn(DateTime(2026, 8, 24)), isTrue);
      expect(playlist.doneOn(DateTime(2026, 8, 25)), isFalse);
    });

    test('a broken entry is skipped rather than crashing the list', () async {
      expect(Playlist.fromMap({'name': 'no id'}), isNull);
    });

    test('ids minted in the same session do not collide', () {
      final first = PlaylistStore.mintId(DateTime(2026, 8, 24, 10, 0, 0));
      final second = PlaylistStore.mintId(DateTime(2026, 8, 24, 10, 0, 1));
      expect(first, isNot(second));
    });
  });

  group('Data saver', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DataSaver.resetForTest();
    });

    test('off by default, and the audio is full quality', () {
      expect(DataSaver.isEnabled, isFalse);
      expect(DataSaver.audioBitrate, DataSaver.normalBitrate);
      expect(DataSaver.allowsBackgroundRefresh, isTrue);
    });

    test('on, verse audio comes from the smaller recording', () async {
      await DataSaver.setEnabled(true);

      // The per-ayah host keeps each bitrate in its own directory, so saving
      // data means a different folder rather than a smaller number in the URL.
      final saving = QuranLocalService.audioUrlForVerse(2, 255);
      final full = QuranLocalService.audioUrlForVerse(2, 255, small: false);

      expect(saving, contains('Alafasy_64kbps'));
      expect(full, contains('Alafasy_128kbps'));
      expect(saving, isNot(full));
    });

    test('a voice with only one recording is unaffected', () async {
      await DataSaver.setEnabled(true);
      // Ghamadi is published at one bitrate; asking for the small version has
      // to give the one that exists, not a folder that 404s.
      final url = QuranLocalService.audioUrlForVerse(
        2,
        255,
        reciterCode: 'ghamadi',
      );
      expect(url, contains('Ghamadi_40kbps'));
    });

    test('it survives a restart', () async {
      await DataSaver.setEnabled(true);
      await DataSaver.setWarnMegabytes(50);

      DataSaver.resetForTest();
      await DataSaver.load();

      expect(DataSaver.isEnabled, isTrue);
      expect(DataSaver.warnMegabytes, 50);
    });

    test(
      'a download only asks when the size is both known and large',
      () async {
        await DataSaver.setEnabled(true);
        await DataSaver.setWarnMegabytes(20);

        expect(DataSaver.shouldConfirm(30 * 1024 * 1024), isTrue);
        expect(DataSaver.shouldConfirm(5 * 1024 * 1024), isFalse);
        // -1 is what a chunked response reports. Asking about an unknown size
        // would mean a dialog on nearly every download.
        expect(DataSaver.shouldConfirm(-1), isFalse);
        expect(DataSaver.shouldConfirm(0), isFalse);
      },
    );

    test('with the saver off nothing is ever gated', () async {
      await DataSaver.setEnabled(false);
      expect(DataSaver.shouldConfirm(500 * 1024 * 1024), isFalse);
      expect(DataSaver.shouldConfirmBatch(114), isFalse);
    });

    test('a whole-Mushaf download asks, a couple of surahs does not', () async {
      await DataSaver.setEnabled(true);
      await DataSaver.setWarnMegabytes(20);

      expect(DataSaver.shouldConfirmBatch(114), isTrue);
      expect(DataSaver.shouldConfirmBatch(1), isFalse);
      // Roughly a gigabyte for the whole Mushaf, which is the right order of
      // magnitude to warn on even though no server states a length up front.
      expect(DataSaver.estimateBatchBytes(114), greaterThan(900 * 1024 * 1024));
    });
  });

  group('Learning when someone reads', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    List<int> countsWith(Map<int, int> hours) {
      final counts = List<int>.filled(24, 0);
      hours.forEach((hour, value) => counts[hour] = value);
      return counts;
    }

    test('too little evidence moves nothing', () {
      expect(WirdHabitStore.usualHour(countsWith({6: 3})), isNull);
      expect(WirdHabitStore.suggestedTime(countsWith({6: 3})), isNull);
      expect(WirdHabitStore.usualHour(List<int>.filled(24, 0)), isNull);
    });

    test('the busiest hour wins, not the average', () {
      // Someone who reads after fajr and again before sleep: averaging gives
      // midday, the one hour they never read in.
      final counts = countsWith({5: 20, 22: 12});
      expect(WirdHabitStore.usualHour(counts), 5);
    });

    test('the reminder lands just before the usual hour', () {
      final at = WirdHabitStore.suggestedTime(countsWith({20: 9}))!;
      expect(at.hour, 19);
      expect(at.minute, 50);
    });

    test('an hour just after midnight does not wrap to a negative time', () {
      final at = WirdHabitStore.suggestedTime(countsWith({0: 9}))!;
      expect(at.hour, 23);
      expect(at.minute, 50);
    });

    test('one long sitting counts once per hour, not once per page', () async {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime(2026, 8, 24, 21, 5);

      for (var i = 0; i < 30; i++) {
        await WirdHabitStore.noteSession(prefs, when: at);
      }
      expect(WirdHabitStore.readCounts(prefs)[21], 1);

      await WirdHabitStore.noteSession(
        prefs,
        when: at.add(const Duration(hours: 1)),
      );
      expect(WirdHabitStore.readCounts(prefs)[22], 1);
    });

    test('counts decay so an old habit does not hold forever', () {
      final counts = countsWith({5: 400, 22: 100});
      final decayed = WirdHabitStore.decay(counts);
      expect(decayed[5], 200);
      expect(decayed[22], 50);
      // Below the threshold, nothing is touched.
      expect(WirdHabitStore.decay(countsWith({5: 10}))[5], 10);
    });

    test('a corrupt stored value reads as no evidence, not as a crash', () {
      expect(WirdHabitStore.decode('nonsense'), List<int>.filled(24, 0));
      expect(WirdHabitStore.decode(null), List<int>.filled(24, 0));
      expect(WirdHabitStore.decode('1,2')[0], 1);
      expect(WirdHabitStore.decode('1,2').length, 24);
    });
  });
}
