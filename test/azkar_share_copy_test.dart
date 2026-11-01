import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/domain/azkar_share_copy.dart';

void main() {
  test('the shared card is a short established set', () {
    for (final period in AzkarSharePeriod.values) {
      final lines = AzkarShareCopy.lines(period);
      expect(lines.length, inInclusiveRange(5, 7), reason: period.name);
      expect(lines.where((line) => line.count == 3), hasLength(3));
      expect(lines.where((line) => line.count == 4), hasLength(1));
      expect(lines.first.text.length, greaterThan(80));
      expect(lines.any((line) => line.text.contains('فَاغْفِرْ')), isTrue);
      final card = lines.map((line) => line.text).join('\n');
      expect(card, isNot(contains('@')));
      expect(card, isNot(contains('zad.almuslim')));
    }

    expect(AzkarShareCopy.title(AzkarSharePeriod.morning), 'أذكار الصباح');
    expect(AzkarShareCopy.title(AzkarSharePeriod.evening), 'أذكار المساء');
    expect(
      AzkarShareCopy.lines(
        AzkarSharePeriod.morning,
      ).any((line) => line.text.contains('أَصْبَحْتُ')),
      isTrue,
    );
    expect(
      AzkarShareCopy.lines(
        AzkarSharePeriod.evening,
      ).any((line) => line.text.contains('أَمْسَيْتُ')),
      isTrue,
    );
  });

  test('only the morning and evening categories open the card', () {
    expect(
      AzkarShareCopy.fromCategory(id: 'morning', nameAr: 'أذكار الصباح'),
      AzkarSharePeriod.morning,
    );
    expect(
      AzkarShareCopy.fromCategory(id: 'custom', nameAr: 'أذكار المساء'),
      AzkarSharePeriod.evening,
    );
    expect(
      AzkarShareCopy.fromCategory(id: 'sleep', nameAr: 'أذكار النوم'),
      isNull,
    );
  });
}
