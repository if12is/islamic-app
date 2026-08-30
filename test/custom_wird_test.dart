import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/home/data/custom_wird_store.dart';
import 'package:islamic_app/features/home/domain/custom_wird.dart';
import 'package:shared_preferences/shared_preferences.dart';

CustomWirdItem _item(
  WirdKind kind,
  String reference, {
  String title = 'x',
  int target = 1,
}) => CustomWirdItem(
  id: CustomWirdItem.idFor(kind, reference),
  kind: kind,
  title: title,
  target: target,
  reference: reference,
);

void main() {
  group('What a line points at', () {
    test('the id carries the kind and the reference', () {
      expect(CustomWirdItem.idFor(WirdKind.surah, '18'), 'surah:18');
      expect(CustomWirdItem.idFor(WirdKind.azkar, 'morning'), 'azkar:morning');
    });

    test('surah 18 and juz 18 are different lines', () {
      // A bare reference would collide, and adding al-Kahf would silently
      // replace the eighteenth juz.
      expect(
        CustomWirdItem.idFor(WirdKind.surah, '18'),
        isNot(CustomWirdItem.idFor(WirdKind.juz, '18')),
      );
    });
  });

  group('Adding and removing', () {
    test('adding the same thing twice updates rather than duplicating', () {
      // Tapping "add" again is a slip, not an intention to read al-Kahf twice.
      var items = <CustomWirdItem>[];
      items = CustomWirdStore.withItem(items, _item(WirdKind.surah, '18'));
      items = CustomWirdStore.withItem(
        items,
        _item(WirdKind.surah, '18', title: 'الكهف', target: 1),
      );

      expect(items, hasLength(1));
      expect(items.single.title, 'الكهف');
    });

    test('two different things both stay', () {
      var items = <CustomWirdItem>[];
      items = CustomWirdStore.withItem(items, _item(WirdKind.surah, '18'));
      items = CustomWirdStore.withItem(items, _item(WirdKind.surah, '36'));
      expect(items, hasLength(2));
    });

    test('removing takes only the one named', () {
      final items = [
        _item(WirdKind.surah, '18'),
        _item(WirdKind.surah, '36'),
      ];
      final left = CustomWirdStore.withoutId(items, 'surah:18');
      expect(left, hasLength(1));
      expect(left.single.reference, '36');
    });

    test('reordering moves a line without losing one', () {
      final items = [
        _item(WirdKind.surah, '1'),
        _item(WirdKind.surah, '2'),
        _item(WirdKind.surah, '3'),
      ];
      final moved = CustomWirdStore.reordered(items, 0, 2);
      expect(moved.map((i) => i.reference), ['2', '3', '1']);
      expect(moved, hasLength(3));
    });

    test('an out-of-range move changes nothing', () {
      final items = [_item(WirdKind.surah, '1')];
      expect(CustomWirdStore.reordered(items, 0, 9), items);
      expect(CustomWirdStore.reordered(items, -1, 0), items);
    });
  });

  group('Counting a day', () {
    final wird = CustomWird(
      items: [
        _item(WirdKind.surah, '18', target: 1),
        _item(WirdKind.tasbih, 'subhanallah', target: 33),
      ],
      doneToday: const {'surah:18': 1, 'tasbih:subhanallah': 11},
    );

    test('a read line is done or not', () {
      expect(wird.isComplete(wird.items.first), isTrue);
    });

    test('a counted line is done only at its target', () {
      expect(wird.isComplete(wird.items.last), isFalse);
      expect(wird.doneFor('tasbih:subhanallah'), 11);
    });

    test('progress counts a part-done line for its part', () {
      // One line finished and one a third done is two thirds of the way, not
      // half — a wird that only counted whole lines would sit at 50% for
      // twenty-two repetitions.
      expect(wird.progress, closeTo((1 + 11 / 33) / 2, 0.001));
    });

    test('an empty wird is not divided by zero', () {
      expect(const CustomWird().progress, 0);
      expect(const CustomWird().isEmpty, isTrue);
    });

    test('it knows what is already in it', () {
      expect(wird.contains(WirdKind.surah, '18'), isTrue);
      expect(wird.contains(WirdKind.surah, '36'), isFalse);
      expect(wird.contains(WirdKind.juz, '18'), isFalse);
    });
  });

  group('Reading back what was stored', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a wird survives a round trip', () async {
      final prefs = await SharedPreferences.getInstance();
      final items = [
        _item(WirdKind.surah, '18', title: 'سورة الكهف'),
        _item(WirdKind.tasbih, 'x', title: 'سبحان الله', target: 33),
      ];
      await CustomWirdStore.writeItems(prefs, items);

      final read = CustomWirdStore.read(prefs);
      expect(read.items, hasLength(2));
      expect(read.items.first.title, 'سورة الكهف');
      expect(read.items.last.target, 33);
      expect(read.items.last.kind, WirdKind.tasbih);
    });

    test('yesterday\'s counts do not become today\'s', () async {
      // The whole point of storing the day beside the counts: a wird that
      // opened already ticked would be telling the reader they had done
      // something they had not.
      final prefs = await SharedPreferences.getInstance();
      await CustomWirdStore.writeProgress(
        prefs,
        {'surah:18': 1},
        now: DateTime(2026, 8, 26),
      );

      final today = CustomWirdStore.read(prefs, now: DateTime(2026, 8, 27));
      expect(today.doneToday, isEmpty);

      final sameDay = CustomWirdStore.read(prefs, now: DateTime(2026, 8, 26));
      expect(sameDay.doneFor('surah:18'), 1);
    });

    test('a corrupt store reads as empty rather than throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CustomWirdStore.itemsKey, 'not json at all');
      await prefs.setString(CustomWirdStore.progressKey, '{{{');

      final read = CustomWirdStore.read(prefs);
      expect(read.items, isEmpty);
      expect(read.doneToday, isEmpty);
    });

    test('one unreadable line does not take the rest with it', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CustomWirdStore.itemsKey,
        jsonEncode([
          {'id': 'surah:18', 'kind': 'surah', 'title': 'الكهف', 'target': 1},
          {'kind': 'surah'},
          {'id': 'surah:36', 'kind': 'surah', 'title': 'يس', 'target': 1},
        ]),
      );

      expect(CustomWirdStore.read(prefs).items, hasLength(2));
    });

    test('an impossible target is brought back into range', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CustomWirdStore.itemsKey,
        jsonEncode([
          {'id': 'a', 'kind': 'tasbih', 'title': 'x', 'target': 0},
          {'id': 'b', 'kind': 'tasbih', 'title': 'y', 'target': 999999},
        ]),
      );

      final items = CustomWirdStore.read(prefs).items;
      // A target of zero can never be completed and would sit at 0/0 forever.
      expect(items.first.target, 1);
      expect(items.last.target, 1000);
    });

    test('the day key is the local day, padded', () {
      expect(CustomWirdStore.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(CustomWirdStore.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
