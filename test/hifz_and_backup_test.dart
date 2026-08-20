import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/core/services/backup_service.dart';
import 'package:islamic_app/core/services/hijri_service.dart';
import 'package:islamic_app/features/quran/domain/entities/hifz_item.dart';

void main() {
  group('HifzItem scheduling', () {
    final today = DateTime(2026, 8, 20);

    HifzItem fresh() =>
        HifzItem.fresh(surahNumber: 78, fromAyah: 1, toAyah: 5, now: today);

    test('a new passage is due the day it is added', () {
      final item = fresh();
      expect(item.isDue(today), isTrue);
      expect(item.box, 0);
      expect(item.key, '78:1-5');
      expect(item.verseCount, 5);
    });

    test('good moves one box, easy skips one', () {
      final good = fresh().review(HifzGrade.good, now: today);
      final easy = fresh().review(HifzGrade.easy, now: today);

      expect(good.box, 1);
      expect(easy.box, 2);
      expect(good.dueDate, DateTime(2026, 8, 20 + HifzItem.intervals[1]));
      expect(easy.dueDate, DateTime(2026, 8, 20 + HifzItem.intervals[2]));
    });

    test('a lapse sends it back to the start', () {
      var item = fresh();
      for (var i = 0; i < 4; i++) {
        item = item.review(HifzGrade.good, now: today);
      }
      expect(item.box, 4);

      final lapsed = item.review(HifzGrade.again, now: today);
      expect(lapsed.box, 0);
      expect(lapsed.lapses, 1);
      expect(lapsed.dueDate, DateTime(2026, 8, 21));
    });

    test('intervals never run past the last box', () {
      var item = fresh();
      for (var i = 0; i < 20; i++) {
        item = item.review(HifzGrade.easy, now: today);
      }
      expect(item.box, HifzItem.intervals.length - 1);
      expect(item.strength, 1);
      expect(item.reviews, 20);
    });

    test('survives a round trip through storage', () {
      final item = fresh().review(HifzGrade.good, now: today);
      final restored = HifzItem.fromJson(item.toJson());

      expect(restored.key, item.key);
      expect(restored.box, item.box);
      expect(restored.dueDate, item.dueDate);
      expect(restored.reviews, item.reviews);
    });
  });

  group('Laylat al-Qadr and the last ten', () {
    test('marks every night of the last ten, odd ones apart', () {
      expect(HijriService.isLastTenOfRamadan(9, 20), isFalse);
      expect(HijriService.isLastTenOfRamadan(9, 21), isTrue);
      expect(HijriService.isOddNightOfLastTen(9, 21), isTrue);
      expect(HijriService.isOddNightOfLastTen(9, 22), isFalse);
      expect(HijriService.isOddNightOfLastTen(9, 27), isTrue);
    });

    test('the 27th is flagged as expected, not as certain', () {
      final keys = HijriService.eventsOn(9, 27).map((event) => event.key);

      expect(keys, contains('event_laylat_qadr_expected'));
      expect(keys, contains('event_odd_night'));
      expect(keys, isNot(contains('event_laylat_qadr')));
    });

    test('every last-ten night carries a marker', () {
      for (var day = 21; day <= 29; day++) {
        final keys = HijriService.eventsOn(9, day).map((event) => event.key);
        expect(
          keys.any(
            (key) => key == 'event_odd_night' || key == 'event_last_ten',
          ),
          isTrue,
          reason: 'night $day has no marker',
        );
      }
    });
  });

  group('Backup format', () {
    test('rejects a file that is not a backup', () async {
      expect(
        () => BackupService.restoreFromBytes(
          Uint8List.fromList(utf8.encode('{"hello":"world"}')),
        ),
        throwsA(isA<BackupException>()),
      );

      expect(
        () => BackupService.restoreFromBytes(
          Uint8List.fromList(utf8.encode('not json at all')),
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('refuses a backup from a newer app version', () async {
      final payload = jsonEncode({
        'version': BackupService.formatVersion + 1,
        'boxes': <String, dynamic>{},
      });

      await expectLater(
        BackupService.restoreFromBytes(
          Uint8List.fromList(utf8.encode(payload)),
        ),
        throwsA(
          isA<BackupException>().having(
            (error) => error.isWrongVersion,
            'isWrongVersion',
            isTrue,
          ),
        ),
      );
    });
  });
}
