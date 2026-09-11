import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/data/azkar_progress_store.dart';
import 'package:islamic_app/features/azkar/data/models/azkar_models.dart';
import 'package:islamic_app/features/azkar/data/tasbeeh_link.dart';
import 'package:islamic_app/features/azkar/data/tasbeeh_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The wird's tasbeeh chapter, straight from the bundled Hisn.
AzkarCategory _wirdTasbeeh() {
  final data =
      jsonDecode(File('assets/data/azkar.json').readAsStringSync())
          as Map<String, dynamic>;
  final raw = (data['categories'] as List).cast<Map>().firstWhere(
    (category) => category['id'] == TasbeehLink.wirdCategoryId,
  );
  return AzkarCategory(
    id: raw['id'] as String,
    nameAr: raw['nameAr'] as String,
    nameEn: raw['nameEn'] as String? ?? '',
    azkar: [
      for (final item in (raw['azkar'] as List).cast<Map>())
        ZekrItem(
          id: (item['id'] as num).toInt(),
          textAr: item['textAr'] as String,
          textEn: item['textEn'] as String? ?? '',
          targetCount: (item['count'] as num).toInt(),
        ),
    ],
  );
}

void main() {
  final category = _wirdTasbeeh();
  final now = DateTime(2026, 9, 11, 7);

  group('The misbaha and the wird count as one', () {
    test('the phrases both hold are matched on their words', () {
      // Vowelled in the Hisn, bare on the beads: still the same dhikr.
      expect(TasbeehLink.zekrForPhrase(0, category)?.textAr, 'سُبْحَانَ اللَّهِ');
      expect(TasbeehLink.zekrForPhrase(1, category)?.textAr, 'الْحَمْدُ لِلَّهِ');
      expect(TasbeehLink.zekrForPhrase(3, category)?.textAr, 'اللَّهُ أَكْبَرُ');
    });

    test('a longer dhikr is not mistaken for a shorter one', () {
      // "أستغفر الله وأتوب إليه" is not "استغفر الله", and the full tahlil is
      // not "لا إله إلا الله".
      expect(TasbeehLink.zekrForPhrase(2, category), isNull);
      expect(TasbeehLink.zekrForPhrase(4, category), isNull);
      expect(TasbeehLink.zekrForPhrase(5, category), isNull);
    });

    test('the wird has seven lines, so its summary counts seven', () {
      // It read "0/6" with all seven finished: it was counting the beads.
      expect(category.azkar, hasLength(7));
    });

    test('a bead on سبحان الله counts in the wird, up to its target', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final zekr = TasbeehLink.zekrForPhrase(0, category)!;

      for (var i = 0; i < zekr.targetCount + 5; i++) {
        await TasbeehLink.onMisbahaCount(prefs, 0, category, now: now);
      }

      final counts = AzkarProgressStore.countsToday(
        prefs,
        category.id,
        now: now,
      );
      expect(counts[zekr.id], zekr.targetCount);
      final progress = await AzkarProgressStore.progressFor(category, now: now);
      expect(progress.completedCount, 1);
      expect(progress.totalCount, 7);
    });

    test('two quick taps are two counts, not one', () async {
      // The session was written and awaited before the counts, so a second
      // tap in between read the old counts and one of the two was lost.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final zekr = TasbeehLink.zekrForPhrase(0, category)!;

      await Future.wait([
        TasbeehLink.onMisbahaCount(prefs, 0, category, now: now),
        TasbeehLink.onMisbahaCount(prefs, 0, category, now: now),
        TasbeehLink.onMisbahaCount(prefs, 0, category, now: now),
      ]);

      expect(
        AzkarProgressStore.countsToday(prefs, category.id, now: now)[zekr.id],
        3,
      );
    });

    test('a phrase the wird does not hold changes nothing there', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await TasbeehLink.onMisbahaCount(prefs, 5, category, now: now);
      expect(
        AzkarProgressStore.countsToday(prefs, category.id, now: now),
        isEmpty,
      );
    });

    test('a count in the wird moves the beads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final zekr = TasbeehLink.zekrForPhrase(1, category)!;

      await TasbeehLink.onWirdCount(prefs, category.id, zekr, now: now);
      await TasbeehLink.onWirdCount(prefs, category.id, zekr, now: now);

      expect(TasbeehStore.roundCount(prefs, 1, now: now), 2);
    });

    test('other chapters leave the beads alone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final zekr = TasbeehLink.zekrForPhrase(0, category)!;

      await TasbeehLink.onWirdCount(prefs, 'after_prayer', zekr, now: now);
      expect(TasbeehStore.roundCount(prefs, 0, now: now), 0);
    });
  });
}
