import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:islamic_app/core/services/backup_service.dart';
import 'package:islamic_app/features/azkar/data/tasbeeh_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _bytes(Map<String, dynamic> payload) =>
    Uint8List.fromList(utf8.encode(jsonEncode(payload)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The backup reads the Hive boxes too, so they need somewhere real to live.
    hiveDir = await Directory.systemTemp.createTemp('backup_test');
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('What the export carries', () {
    // The regression this exists for: the tasbeeh keys were not in the backup
    // at all, so a lifetime count someone had spent years building was the one
    // thing in the app that could not be exported.
    test('includes every tasbeeh counter, per phrase', () async {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < 40; i++) {
        await TasbeehStore.increment(prefs, phraseIndex: 0);
      }
      for (var i = 0; i < 7; i++) {
        await TasbeehStore.increment(prefs, phraseIndex: 3);
      }
      await TasbeehStore.setMode(prefs, TasbeehMode.endless);

      final payload = await BackupService.buildPayload();
      final settings = payload['settings'] as Map<String, dynamic>;

      expect(settings['tasbeeh_endless_total'], 47);
      expect(settings['tasbeeh_phrase_total_0'], 40);
      expect(settings['tasbeeh_phrase_total_3'], 7);
      expect(settings['tasbeeh_mode'], TasbeehMode.endless.name);
    });

    test('includes the round counts the daily wird reads', () async {
      final prefs = await SharedPreferences.getInstance();
      await TasbeehStore.incrementRound(prefs, 2);

      final settings =
          (await BackupService.buildPayload())['settings']
              as Map<String, dynamic>;
      expect(settings['tasbeeh_rounds_2'], 1);
      expect(settings.containsKey('tasbeeh_rounds_date'), isTrue);
    });

    test('carries the newer stores too', () async {
      // Every store added after the backup was written needs a prefix here, or
      // it silently stops being exported — which is how the tasbeeh total came
      // to be missing in the first place.
      SharedPreferences.setMockInitialValues({
        'salawat_total': 4000,
        'prayer_log_2026-08-24': 'fajr:mosque',
        'zakat_cash': 1500.0,
      });

      final settings =
          (await BackupService.buildPayload())['settings']
              as Map<String, dynamic>;

      expect(settings['salawat_total'], 4000);
      expect(settings['prayer_log_2026-08-24'], 'fajr:mosque');
      expect(settings['zakat_cash'], 1500.0);
    });

    test('leaves unrelated keys out', () async {
      SharedPreferences.setMockInitialValues({
        'some_cache_blob': 'x',
        'theme_mode': 'dark',
      });

      final settings =
          (await BackupService.buildPayload())['settings']
              as Map<String, dynamic>;
      expect(settings.containsKey('some_cache_blob'), isFalse);
      expect(settings['theme_mode'], 'dark');
    });
  });

  group('A backup taken now, restored later', () {
    test('brings the counts back exactly', () async {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < 4321; i++) {
        await TasbeehStore.increment(prefs, phraseIndex: 1);
      }
      final payload = await BackupService.buildPayload();

      // A fresh install.
      SharedPreferences.setMockInitialValues({});
      final restored = await BackupService.restoreFromBytes(_bytes(payload));
      final after = await SharedPreferences.getInstance();

      expect(TasbeehStore.total(after), 4321);
      expect(TasbeehStore.totalFor(after, 1), 4321);
      expect(restored.tasbeehTotal, 4321);
      expect(restored.settingsRestored, isTrue);
    });
  });

  group('An old backup, written before counts were split per phrase', () {
    test(
      'does not lose the total, and does not show zero on the beads',
      () async {
        final legacy = {
          'version': 1,
          'createdAt': '2026-01-01T00:00:00.000',
          'settings': {
            'tasbeeh_endless_total': 9000,
            'tasbeeh_endless_phrase': 2,
            'theme_mode': 'dark',
          },
          'boxes': <String, dynamic>{},
        };

        final summary = await BackupService.restoreFromBytes(_bytes(legacy));
        final prefs = await SharedPreferences.getInstance();

        expect(TasbeehStore.total(prefs), 9000, reason: 'the sum survives');
        expect(
          TasbeehStore.totalFor(prefs, 2),
          9000,
          reason: 'and it lands on the phrase that was open, not nowhere',
        );
        expect(summary.tasbeehTotal, 9000);
      },
    );

    test('never overwrites counts that are already split', () async {
      final prefs = await SharedPreferences.getInstance();
      await TasbeehStore.increment(prefs, phraseIndex: 0);

      await BackupService.restoreFromBytes(
        _bytes({
          'version': 1,
          'settings': {'tasbeeh_endless_total': 500},
          'boxes': <String, dynamic>{},
        }),
      );

      expect(TasbeehStore.totalFor(prefs, 0), 1);
      expect(TasbeehStore.totalFor(prefs, 2), 0);
    });

    test('a v1 file with no tasbeeh at all restores cleanly', () async {
      final summary = await BackupService.restoreFromBytes(
        _bytes({
          'version': 1,
          'settings': {'theme_mode': 'light'},
          'boxes': <String, dynamic>{},
        }),
      );
      expect(summary.tasbeehTotal, 0);
      expect(summary.settingsRestored, isTrue);
    });
  });

  group('Refusing what it cannot read', () {
    test('a file from a newer build is refused, not half-applied', () async {
      expect(
        () => BackupService.restoreFromBytes(
          _bytes({
            'version': BackupService.formatVersion + 1,
            'boxes': <String, dynamic>{},
          }),
        ),
        throwsA(
          isA<BackupException>().having((e) => e.isWrongVersion, 'newer', true),
        ),
      );
    });

    test('something that is not a backup is refused', () async {
      expect(
        () => BackupService.restoreFromBytes(
          Uint8List.fromList(utf8.encode('{"hello":1}')),
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
