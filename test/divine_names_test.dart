import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app/features/azkar/domain/divine_names.dart';
import 'package:islamic_app/features/azkar/domain/salawat_forms.dart';

void main() {
  group('The ninety-nine names', () {
    test('there are exactly ninety-nine', () {
      expect(DivineNames.all, hasLength(99));
    });

    test('numbered 1 to 99 with no gaps', () {
      for (var i = 0; i < DivineNames.all.length; i++) {
        expect(DivineNames.all[i].number, i + 1);
      }
      expect(DivineNames.byNumber(1).arabic, contains('رَّحْمَن'));
      expect(DivineNames.byNumber(99).transliteration, 'As-Saboor');
    });

    test('every name carries a meaning and a transliteration', () {
      for (final name in DivineNames.all) {
        expect(name.arabic.trim(), isNotEmpty, reason: '${name.number}');
        expect(name.meaningAr.trim(), isNotEmpty, reason: '${name.number}');
        expect(
          name.transliteration.trim(),
          isNotEmpty,
          reason: '${name.number}',
        );
      }
    });

    test('no name is listed twice', () {
      final seen = DivineNames.all.map((name) => name.arabic).toSet();
      expect(seen.length, 99);
    });

    test('the source of the count and of the listing are both stated', () {
      // The count is agreed upon; the enumeration is a narrator's. Presenting
      // the second with the authority of the first would teach something false.
      expect(DivineNames.hadithSourceAr, contains('متفق عليه'));
      expect(DivineNames.listingNoteAr, contains('الترمذي'));
    });
  });

  group('Searching the names', () {
    test('finds a name typed without its article or diacritics', () {
      final results = DivineNames.search('رحمن');
      expect(results.map((n) => n.number), contains(1));
    });

    test('finds by meaning', () {
      expect(DivineNames.search('يجيب دعاء'), isNotEmpty);
    });

    test('finds by transliteration', () {
      expect(DivineNames.search('Qayyoom').single.number, 63);
    });

    test('an empty query lists them all', () {
      expect(DivineNames.search('   '), hasLength(99));
    });

    test('nonsense finds nothing rather than everything', () {
      expect(DivineNames.search('zzzqqq'), isEmpty);
    });
  });

  group('Wordings of the salawat', () {
    test('every one names where it comes from', () {
      for (final form in SalawatForms.all) {
        expect(form.textAr.trim(), isNotEmpty, reason: form.id);
        expect(form.sourceAr.trim(), isNotEmpty, reason: form.id);
      }
    });

    test('the wording taught to the companions is the default', () {
      expect(SalawatForms.all.first.id, 'ibrahimiyyah');
      expect(SalawatForms.byId('nonsense').id, 'ibrahimiyyah');
    });

    test('the virtue quoted is the one in Muslim', () {
      expect(SalawatForms.virtueSourceAr, contains('مسلم'));
      expect(SalawatForms.virtueAr, contains('عَشْرًا'));
    });
  });
}
